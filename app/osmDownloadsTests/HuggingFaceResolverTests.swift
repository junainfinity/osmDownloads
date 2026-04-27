import XCTest
@testable import osmDownloads

final class HuggingFaceResolverTests: XCTestCase {

    func testResolvesTreeIntoManifest() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.host, "huggingface.co")
            XCTAssertTrue(request.url?.path.contains("/api/models/meta-llama/Llama-3-8B/tree/main") == true)
            let body = """
            [
              { "type": "file",      "path": "config.json", "size": 712 },
              { "type": "file",      "path": "model-00001-of-00002.safetensors", "size": 5000000000,
                "lfs": { "oid": "sha256:abc123", "size": 5000000000 } },
              { "type": "directory", "path": "subfolder" },
              { "type": "file",      "path": "tokenizer.json", "size": 480000 }
            ]
            """.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: "HTTP/1.1", headerFields: [:])!
            return (resp, body)
        }
        let resolver = HuggingFaceResolver(session: MockURLProtocol.session())
        let kind = ClassifiedURL.huggingFace(
            repoType: .models, org: "meta-llama", repo: "Llama-3-8B",
            branch: "main", subpath: "",
            originalURL: URL(string: "https://huggingface.co/meta-llama/Llama-3-8B")!
        )
        let manifest = try await resolver.resolve(kind)
        XCTAssertEqual(manifest.title, "meta-llama/Llama-3-8B")
        XCTAssertEqual(manifest.source, .huggingFace)
        XCTAssertEqual(manifest.files.count, 3, "directory entries should be filtered out")

        let weights = manifest.files.first { $0.name.contains("safetensors") }
        XCTAssertNotNil(weights)
        XCTAssertEqual(weights?.size, 5000000000)
        XCTAssertEqual(weights?.sha256, "abc123")
        XCTAssertEqual(weights?.isLFS, true)

        let downloadHost = weights?.downloadURL.host
        XCTAssertEqual(downloadHost, "huggingface.co")
        XCTAssertTrue(weights?.downloadURL.path.contains("/resolve/main/") == true)
    }

    func testGatedRepoThrowsUnauthorized() async {
        MockURLProtocol.responder = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401,
                                       httpVersion: "HTTP/1.1", headerFields: [:])!
            return (resp, Data())
        }
        let resolver = HuggingFaceResolver(session: MockURLProtocol.session())
        let kind = ClassifiedURL.huggingFace(
            repoType: .models, org: "gated", repo: "model", branch: "main", subpath: "",
            originalURL: URL(string: "https://huggingface.co/gated/model")!
        )
        do {
            _ = try await resolver.resolve(kind)
            XCTFail("Expected unauthorized error")
        } catch let err as ResolverError {
            if case .unauthorized = err { return }
            XCTFail("Expected .unauthorized, got \(err)")
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }

    func testRateLimitedThrows() async {
        MockURLProtocol.responder = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 429,
                                       httpVersion: "HTTP/1.1", headerFields: [:])!
            return (resp, Data())
        }
        let resolver = HuggingFaceResolver(session: MockURLProtocol.session())
        let kind = ClassifiedURL.huggingFace(
            repoType: .models, org: "x", repo: "y", branch: "main", subpath: "",
            originalURL: URL(string: "https://huggingface.co/x/y")!
        )
        do {
            _ = try await resolver.resolve(kind)
            XCTFail("Expected rate-limited error")
        } catch let err as ResolverError {
            if case .rateLimited = err { return }
            XCTFail("Expected .rateLimited, got \(err)")
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }

    func testSubpathFiltersFiles() async throws {
        MockURLProtocol.responder = { request in
            let body = """
            [
              { "type": "file", "path": "README.md", "size": 100 },
              { "type": "file", "path": "models/weights.safetensors", "size": 1000 },
              { "type": "file", "path": "models/config.json", "size": 200 },
              { "type": "file", "path": "scripts/run.py", "size": 50 }
            ]
            """.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: "HTTP/1.1", headerFields: [:])!
            return (resp, body)
        }
        let resolver = HuggingFaceResolver(session: MockURLProtocol.session())
        let kind = ClassifiedURL.huggingFace(
            repoType: .models, org: "o", repo: "r", branch: "main", subpath: "models",
            originalURL: URL(string: "https://huggingface.co/o/r/tree/main/models")!
        )
        let manifest = try await resolver.resolve(kind)
        let names = manifest.files.map(\.name).sorted()
        XCTAssertEqual(names, ["models/config.json", "models/weights.safetensors"])
    }

    func testSpacesAreRejected() async {
        let resolver = HuggingFaceResolver(session: MockURLProtocol.session())
        let kind = ClassifiedURL.huggingFace(
            repoType: .spaces, org: "org", repo: "demo", branch: "main", subpath: "",
            originalURL: URL(string: "https://huggingface.co/spaces/org/demo")!
        )
        do {
            _ = try await resolver.resolve(kind)
            XCTFail("Expected spaces to be rejected")
        } catch is ResolverError {
            // expected
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }

    func testParseNextLink() {
        let header = """
        <https://huggingface.co/api/models/foo/bar/tree/main?cursor=abc>; rel="next", \
        <https://huggingface.co/api/models/foo/bar/tree/main>; rel="prev"
        """
        let next = HuggingFaceResolver.parseNextLink(header)
        XCTAssertEqual(next?.absoluteString, "https://huggingface.co/api/models/foo/bar/tree/main?cursor=abc")
    }

    func testParseNextLinkAbsentReturnsNil() {
        let header = "<https://example.com/x>; rel=\"prev\""
        XCTAssertNil(HuggingFaceResolver.parseNextLink(header))
    }
}
