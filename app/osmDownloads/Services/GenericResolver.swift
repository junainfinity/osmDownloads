import Foundation

struct GenericResolver: SourceResolver {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        guard case let .generic(url) = kind else { throw ResolverError.wrongKind }

        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"

        let response: HTTPURLResponse
        do {
            let (_, urlResponse) = try await session.data(for: head)
            guard let http = urlResponse as? HTTPURLResponse else {
                throw ResolverError.invalidResponse
            }
            if http.statusCode == 405 {
                response = try await rangeProbe(url: url)
            } else if (200..<400).contains(http.statusCode) {
                response = http
            } else {
                throw ResolverError.server(http.statusCode, nil)
            }
        } catch let err as ResolverError {
            throw err
        } catch {
            // Some servers reject HEAD outright; fall back to a tiny GET.
            response = try await rangeProbe(url: url)
        }

        let filename = Self.filename(from: response, fallback: url.lastPathComponent)
        let size: Int64? = {
            // Prefer Content-Length for HEAD; for the GET-with-range probe, parse Content-Range total.
            if response.expectedContentLength > 0 { return response.expectedContentLength }
            if let cr = response.value(forHTTPHeaderField: "Content-Range"),
               let total = Self.parseContentRangeTotal(cr) {
                return total
            }
            return nil
        }()

        return ResolvedManifest(
            title: filename,
            source: .generic,
            sourceURL: url,
            files: [
                RemoteFile(name: filename, downloadURL: url, size: size)
            ]
        )
    }

    private func rangeProbe(url: URL) async throws -> HTTPURLResponse {
        var probe = URLRequest(url: url)
        probe.httpMethod = "GET"
        probe.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        let (_, urlResponse) = try await session.data(for: probe)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw ResolverError.invalidResponse
        }
        guard (200..<400).contains(http.statusCode) else {
            throw ResolverError.server(http.statusCode, nil)
        }
        return http
    }

    private static func filename(from response: HTTPURLResponse, fallback: String) -> String {
        if let disp = response.value(forHTTPHeaderField: "Content-Disposition"),
           let parsed = parseContentDispositionFilename(disp) {
            return parsed
        }
        let trimmed = fallback.trimmingCharacters(in: CharacterSet(charactersIn: "/?#"))
        return trimmed.isEmpty ? "download" : trimmed
    }

    /// Tiny parser handling `filename=...` (quoted or bare) and RFC 5987
    /// `filename*=UTF-8''percent-encoded`. Not a full grammar, but covers the
    /// common cases we see in the wild.
    private static func parseContentDispositionFilename(_ header: String) -> String? {
        let parts = header.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        // Prefer extended form first.
        for part in parts {
            if part.lowercased().hasPrefix("filename*=") {
                let value = String(part.dropFirst("filename*=".count))
                let segs = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                if segs.count == 3 {
                    let encoded = String(segs[2])
                    if let decoded = encoded.removingPercentEncoding { return decoded }
                }
                return value.removingPercentEncoding
            }
        }
        for part in parts {
            if part.lowercased().hasPrefix("filename=") {
                var value = String(part.dropFirst("filename=".count))
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// `Content-Range: bytes 0-0/12345` → 12345
    private static func parseContentRangeTotal(_ header: String) -> Int64? {
        guard let slash = header.firstIndex(of: "/") else { return nil }
        let total = header[header.index(after: slash)...].trimmingCharacters(in: .whitespaces)
        return Int64(total)
    }
}
