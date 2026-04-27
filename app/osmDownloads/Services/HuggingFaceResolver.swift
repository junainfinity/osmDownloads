import Foundation

struct HuggingFaceResolver: SourceResolver {
    let session: URLSession
    let token: String?

    init(session: URLSession = .shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        switch kind {
        case let .huggingFace(repoType, org, repo, branch, subpath, originalURL):
            return try await resolveTree(
                repoType: repoType, org: org, repo: repo,
                branch: branch.isEmpty ? "main" : branch,
                subpath: subpath, originalURL: originalURL
            )
        case let .huggingFaceFile(repoType, org, repo, branch, path, originalURL):
            return try await resolveSingleFile(
                repoType: repoType, org: org, repo: repo,
                branch: branch.isEmpty ? "main" : branch,
                path: path, originalURL: originalURL
            )
        default:
            throw ResolverError.wrongKind
        }
    }

    // MARK: - Tree

    private func resolveTree(
        repoType: HFRepoType,
        org: String, repo: String,
        branch: String, subpath: String,
        originalURL: URL
    ) async throws -> ResolvedManifest {
        guard repoType != .spaces else {
            throw ResolverError.server(501, "Hugging Face Spaces aren't supported yet.")
        }

        let baseAPI = "https://huggingface.co/api/\(repoType.apiPath)/\(org)/\(repo)/tree/\(Self.encode(branch))?recursive=true"
        guard let firstURL = URL(string: baseAPI) else { throw ResolverError.invalidResponse }

        var entries: [HFTreeEntry] = []
        var nextURL: URL? = firstURL
        while let url = nextURL {
            let (data, response) = try await fetch(url)
            let page = try JSONDecoder().decode([HFTreeEntry].self, from: data)
            entries.append(contentsOf: page)
            nextURL = (response as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Link") }
                .flatMap(Self.parseNextLink)
        }

        let prefix = subpath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let files: [RemoteFile] = entries
            .filter { $0.type == "file" }
            .filter { prefix.isEmpty || $0.path == prefix || $0.path.hasPrefix(prefix + "/") }
            .map { entry in
                let downloadURL = Self.resolveURL(org: org, repo: repo, branch: branch, path: entry.path)
                return RemoteFile(
                    name: entry.path,
                    downloadURL: downloadURL,
                    size: entry.size ?? entry.lfs?.size,
                    sha256: entry.lfs?.oid.replacingOccurrences(of: "sha256:", with: ""),
                    isLFS: entry.lfs != nil
                )
            }

        let titleSuffix = prefix.isEmpty ? "" : " — \(prefix)"
        return ResolvedManifest(
            title: "\(org)/\(repo)\(titleSuffix)",
            source: .huggingFace,
            sourceURL: originalURL,
            files: files
        )
    }

    // MARK: - Single file

    private func resolveSingleFile(
        repoType: HFRepoType,
        org: String, repo: String,
        branch: String, path: String,
        originalURL: URL
    ) async throws -> ResolvedManifest {
        let downloadURL = Self.resolveURL(org: org, repo: repo, branch: branch, path: path)
        let filename = (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent

        // HEAD probe to get size; HF redirects LFS to a CDN, so follow redirects.
        var head = URLRequest(url: downloadURL)
        head.httpMethod = "HEAD"
        if let token { head.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let size: Int64? = await {
            do {
                let (_, response) = try await session.data(for: head)
                let len = (response as? HTTPURLResponse)?.expectedContentLength ?? 0
                return len > 0 ? len : nil
            } catch {
                return nil
            }
        }()

        return ResolvedManifest(
            title: "\(org)/\(repo) — \(filename)",
            source: .huggingFace,
            sourceURL: originalURL,
            files: [
                RemoteFile(name: filename, downloadURL: downloadURL, size: size)
            ]
        )
    }

    // MARK: - Helpers

    private func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ResolverError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return (data, response)
        case 401, 403:
            throw ResolverError.unauthorized
        case 429:
            let resetHeader = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap(TimeInterval.init)
                .map { Date(timeIntervalSince1970: $0) }
            throw ResolverError.rateLimited(resetAt: resetHeader)
        case 404:
            throw ResolverError.server(404, "Repository not found, or its branch doesn't exist.")
        default:
            throw ResolverError.server(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    private static func resolveURL(org: String, repo: String, branch: String, path: String) -> URL {
        let encodedBranch = encode(branch)
        let encodedPath = path
            .split(separator: "/")
            .map { encode(String($0)) }
            .joined(separator: "/")
        return URL(string: "https://huggingface.co/\(encode(org))/\(encode(repo))/resolve/\(encodedBranch)/\(encodedPath)")!
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    /// Parses RFC 5988 `Link` headers and returns the URL for `rel="next"` if any.
    static func parseNextLink(_ header: String) -> URL? {
        for raw in header.split(separator: ",") {
            let part = raw.trimmingCharacters(in: .whitespaces)
            guard part.lowercased().contains("rel=\"next\"") || part.lowercased().contains("rel='next'") else { continue }
            guard let lt = part.firstIndex(of: "<"),
                  let gt = part.firstIndex(of: ">"),
                  lt < gt else { continue }
            let urlString = String(part[part.index(after: lt)..<gt])
            return URL(string: urlString)
        }
        return nil
    }
}

// MARK: - HF API decoding

private struct HFTreeEntry: Decodable {
    let type: String      // "file" | "directory"
    let path: String
    let size: Int64?
    let lfs: HFLFS?
}

private struct HFLFS: Decodable {
    let oid: String       // "sha256:..."
    let size: Int64
}
