import XCTest
@testable import osmDownloads

final class GitHubResolverTests: XCTestCase {

    func testRepoRootUsesDefaultBranchAndResolvesTree() async throws {
        var sawRepoMetadata = false
        var sawTree = false
        MockURLProtocol.responder = { request in
            if request.url?.path == "/repos/openai/codex" {
                sawRepoMetadata = true
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
                let body = #"{"default_branch":"trunk"}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: "HTTP/1.1", headerFields: [:])!, body)
            }
            if request.url?.path == "/repos/openai/codex/git/trees/trunk" {
                sawTree = true
                XCTAssertEqual(request.url?.query, "recursive=1")
                let body = """
                {
                  "tree": [
                    { "path": "README.md", "type": "blob", "size": 123 },
                    { "path": "Sources/App.swift", "type": "blob", "size": 456 },
                    { "path": "Sources", "type": "tree" }
                  ],
                  "truncated": false
                }
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: "HTTP/1.1", headerFields: [:])!, body)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404,
                                    httpVersion: "HTTP/1.1", headerFields: [:])!, Data())
        }

        let resolver = GitHubResolver(session: MockURLProtocol.session())
        let manifest = try await resolver.resolve(.github(
            org: "openai", repo: "codex", branch: "", subpath: "",
            originalURL: URL(string: "https://github.com/openai/codex")!
        ))

        XCTAssertTrue(sawRepoMetadata)
        XCTAssertTrue(sawTree)
        XCTAssertEqual(manifest.title, "openai/codex")
        XCTAssertEqual(manifest.source, .github)
        XCTAssertEqual(manifest.files.map(\.name).sorted(), ["README.md", "Sources/App.swift"])
        XCTAssertEqual(
            manifest.files.first { $0.name == "Sources/App.swift" }?.downloadURL.absoluteString,
            "https://raw.githubusercontent.com/openai/codex/trunk/Sources/App.swift"
        )
    }

    func testTreeSubpathFiltersFiles() async throws {
        MockURLProtocol.responder = { request in
            let body = """
            {
              "tree": [
                { "path": "README.md", "type": "blob", "size": 100 },
                { "path": "app/main.swift", "type": "blob", "size": 200 },
                { "path": "app/Assets/logo.png", "type": "blob", "size": 300 }
              ],
              "truncated": false
            }
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: "HTTP/1.1", headerFields: [:])!, body)
        }

        let resolver = GitHubResolver(session: MockURLProtocol.session())
        let manifest = try await resolver.resolve(.github(
            org: "owner", repo: "repo", branch: "main", subpath: "app",
            originalURL: URL(string: "https://github.com/owner/repo/tree/main/app")!
        ))

        XCTAssertEqual(manifest.title, "owner/repo — app")
        XCTAssertEqual(manifest.files.map(\.name).sorted(), ["app/Assets/logo.png", "app/main.swift"])
    }

    func testBlobResolvesSingleRawFile() async throws {
        MockURLProtocol.responder = { request in
            if request.httpMethod == "HEAD" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                               httpVersion: "HTTP/1.1",
                                               headerFields: ["Content-Length": "777"])!
                return (response, Data())
            }
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=0-1023")
            let response = HTTPURLResponse(url: request.url!, statusCode: 206,
                                           httpVersion: "HTTP/1.1", headerFields: [:])!
            return (response, "plain file prefix".data(using: .utf8)!)
        }

        let resolver = GitHubResolver(session: MockURLProtocol.session())
        let manifest = try await resolver.resolve(.githubFile(
            org: "owner", repo: "repo", branch: "main", path: "docs/guide.md",
            originalURL: URL(string: "https://github.com/owner/repo/blob/main/docs/guide.md")!
        ))

        XCTAssertEqual(manifest.title, "owner/repo — guide.md")
        XCTAssertEqual(manifest.files.count, 1)
        XCTAssertEqual(manifest.files[0].name, "guide.md")
        XCTAssertEqual(manifest.files[0].size, 777)
        XCTAssertEqual(
            manifest.files[0].downloadURL.absoluteString,
            "https://raw.githubusercontent.com/owner/repo/main/docs/guide.md"
        )
    }

    func testRateLimitThrows() async {
        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["X-RateLimit-Remaining": "0"])!
            return (response, Data())
        }
        let resolver = GitHubResolver(session: MockURLProtocol.session())

        do {
            _ = try await resolver.resolve(.github(
                org: "o", repo: "r", branch: "main", subpath: "",
                originalURL: URL(string: "https://github.com/o/r")!
            ))
            XCTFail("Expected rate limit error")
        } catch let err as ResolverError {
            if case .rateLimited = err { return }
            XCTFail("Expected .rateLimited, got \(err)")
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }

    func testTruncatedTreeThrowsRepoTooLarge() async {
        MockURLProtocol.responder = { request in
            let body = #"{"tree":[],"truncated":true}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: "HTTP/1.1", headerFields: [:])!, body)
        }
        let resolver = GitHubResolver(session: MockURLProtocol.session())

        do {
            _ = try await resolver.resolve(.github(
                org: "o", repo: "huge", branch: "main", subpath: "",
                originalURL: URL(string: "https://github.com/o/huge")!
            ))
            XCTFail("Expected repo too large error")
        } catch let err as ResolverError {
            if case .repoTooLarge = err { return }
            XCTFail("Expected .repoTooLarge, got \(err)")
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }

    func testLFSPointerIsDetectedForSmallBlob() async throws {
        var sawTree = false
        MockURLProtocol.responder = { request in
            if request.url?.host == "api.github.com" {
                sawTree = true
                let body = """
                {
                  "tree": [
                    { "path": "large.bin", "type": "blob", "size": 130 }
                  ],
                  "truncated": false
                }
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: "HTTP/1.1", headerFields: [:])!, body)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=0-1023")
            let body = """
            version https://git-lfs.github.com/spec/v1
            oid sha256:abcdef
            size 987654321
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 206,
                                    httpVersion: "HTTP/1.1", headerFields: [:])!, body)
        }

        let resolver = GitHubResolver(session: MockURLProtocol.session())
        let manifest = try await resolver.resolve(.github(
            org: "o", repo: "r", branch: "main", subpath: "",
            originalURL: URL(string: "https://github.com/o/r")!
        ))

        XCTAssertTrue(sawTree)
        XCTAssertEqual(manifest.files[0].isLFS, true)
        XCTAssertEqual(manifest.files[0].sha256, "abcdef")
        XCTAssertEqual(manifest.files[0].size, 987654321)
    }
}
