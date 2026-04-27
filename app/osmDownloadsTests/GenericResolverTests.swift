import XCTest
@testable import osmDownloads

final class GenericResolverTests: XCTestCase {

    func testHEADWithContentDisposition() async throws {
        let url = URL(string: "https://example.com/foo")!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "HEAD")
            let headers: [String: String] = [
                "Content-Length": "12345",
                "Content-Disposition": "attachment; filename=\"actual_name.bin\""
            ]
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: "HTTP/1.1", headerFields: headers)!
            return (resp, Data())
        }
        let session = MockURLProtocol.session()
        let resolver = GenericResolver(session: session)
        let manifest = try await resolver.resolve(.generic(url))

        XCTAssertEqual(manifest.title, "actual_name.bin")
        XCTAssertEqual(manifest.files.count, 1)
        XCTAssertEqual(manifest.files[0].size, 12345)
    }

    func testFallbackToURLLastPathComponent() async throws {
        let url = URL(string: "https://example.com/path/whatever.tar.gz")!
        MockURLProtocol.responder = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Length": "999"])!
            return (resp, Data())
        }
        let session = MockURLProtocol.session()
        let resolver = GenericResolver(session: session)
        let manifest = try await resolver.resolve(.generic(url))

        XCTAssertEqual(manifest.title, "whatever.tar.gz")
        XCTAssertEqual(manifest.files[0].size, 999)
    }

    func testRangeProbeOn405() async throws {
        let url = URL(string: "https://example.com/blob")!
        var sawHEAD = false
        var sawRangeGET = false
        MockURLProtocol.responder = { request in
            if request.httpMethod == "HEAD" {
                sawHEAD = true
                let resp = HTTPURLResponse(url: request.url!, statusCode: 405,
                                           httpVersion: "HTTP/1.1", headerFields: [:])!
                return (resp, Data())
            }
            if request.httpMethod == "GET", request.value(forHTTPHeaderField: "Range") == "bytes=0-0" {
                sawRangeGET = true
                let resp = HTTPURLResponse(url: request.url!, statusCode: 206,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Range": "bytes 0-0/777"])!
                return (resp, Data([0]))
            }
            return (HTTPURLResponse(), Data())
        }
        let session = MockURLProtocol.session()
        let resolver = GenericResolver(session: session)
        let manifest = try await resolver.resolve(.generic(url))

        XCTAssertTrue(sawHEAD)
        XCTAssertTrue(sawRangeGET)
        XCTAssertEqual(manifest.files[0].size, 777)
    }

    func testWrongKindThrows() async {
        let resolver = GenericResolver(session: MockURLProtocol.session())
        do {
            _ = try await resolver.resolve(.invalid(reason: "x"))
            XCTFail("Expected throw")
        } catch let err as ResolverError {
            switch err {
            case .wrongKind: break
            default: XCTFail("Expected .wrongKind, got \(err)")
            }
        } catch {
            XCTFail("Expected ResolverError, got \(error)")
        }
    }
}

// MARK: - URLProtocol mock

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = MockURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
