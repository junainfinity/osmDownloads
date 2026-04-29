import Foundation

struct GitHubResolver: SourceResolver {
    let session: URLSession
    let token: String?

    init(session: URLSession = .shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        switch kind {
        case let .github(org, repo, branch, subpath, originalURL):
            let resolvedBranch: String
            if branch.isEmpty {
                resolvedBranch = try await defaultBranch(owner: org, repo: repo)
            } else {
                resolvedBranch = branch
            }
            return try await resolveTree(
                owner: org,
                repo: repo,
                branch: resolvedBranch,
                subpath: subpath,
                originalURL: originalURL
            )
        case let .githubFile(org, repo, branch, path, originalURL):
            return try await resolveSingleFile(
                owner: org,
                repo: repo,
                branch: branch,
                path: path,
                originalURL: originalURL
            )
        default:
            throw ResolverError.wrongKind
        }
    }

    // MARK: - Repo metadata

    private func defaultBranch(owner: String, repo: String) async throws -> String {
        let url = apiURL("/repos/\(Self.encode(owner))/\(Self.encode(repo))")
        let (data, _) = try await fetchJSON(url)
        return try JSONDecoder().decode(GHRepo.self, from: data).defaultBranch
    }

    // MARK: - Tree

    private func resolveTree(
        owner: String,
        repo: String,
        branch: String,
        subpath: String,
        originalURL: URL
    ) async throws -> ResolvedManifest {
        let url = apiURL("/repos/\(Self.encode(owner))/\(Self.encode(repo))/git/trees/\(Self.encode(branch))?recursive=1")
        let (data, _) = try await fetchJSON(url)
        let tree = try JSONDecoder().decode(GHTree.self, from: data)
        if tree.truncated {
            throw ResolverError.repoTooLarge
        }

        let prefix = subpath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var files = tree.tree
            .filter { $0.type == "blob" }
            .filter { prefix.isEmpty || $0.path == prefix || $0.path.hasPrefix(prefix + "/") }
            .map { entry in
                RemoteFile(
                    name: entry.path,
                    downloadURL: Self.rawURL(owner: owner, repo: repo, branch: branch, path: entry.path),
                    size: entry.size
                )
            }

        files = try await annotateLFSPointers(files)

        let titleSuffix = prefix.isEmpty ? "" : " — \(prefix)"
        return ResolvedManifest(
            title: "\(owner)/\(repo)\(titleSuffix)",
            source: .github,
            sourceURL: originalURL,
            files: files
        )
    }

    // MARK: - Single file

    private func resolveSingleFile(
        owner: String,
        repo: String,
        branch: String,
        path: String,
        originalURL: URL
    ) async throws -> ResolvedManifest {
        let downloadURL = Self.rawURL(owner: owner, repo: repo, branch: branch, path: path)
        let filename = (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent
        let size = await headSize(downloadURL)
        let file = try await annotateLFSPointer(
            RemoteFile(name: filename, downloadURL: downloadURL, size: size)
        )

        return ResolvedManifest(
            title: "\(owner)/\(repo) — \(filename)",
            source: .github,
            sourceURL: originalURL,
            files: [file]
        )
    }

    // MARK: - HTTP

    private func fetchJSON(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ResolverError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return (data, http)
        case 401, 403:
            if http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                throw ResolverError.rateLimited(resetAt: Self.rateLimitResetDate(http))
            }
            throw ResolverError.unauthorized
        case 404:
            throw ResolverError.server(404, "Repository, branch, or path not found.")
        case 429:
            throw ResolverError.rateLimited(resetAt: Self.rateLimitResetDate(http))
        default:
            throw ResolverError.server(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    private func headSize(_ url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await session.data(for: request)
            let length = (response as? HTTPURLResponse)?.expectedContentLength ?? 0
            return length > 0 ? length : nil
        } catch {
            return nil
        }
    }

    // MARK: - LFS pointer detection

    private func annotateLFSPointers(_ files: [RemoteFile]) async throws -> [RemoteFile] {
        var annotated: [RemoteFile] = []
        annotated.reserveCapacity(files.count)
        for file in files {
            annotated.append(try await annotateLFSPointer(file))
        }
        return annotated
    }

    private func annotateLFSPointer(_ file: RemoteFile) async throws -> RemoteFile {
        guard let size = file.size, size > 0, size <= 1024 else { return file }

        var request = URLRequest(url: file.downloadURL)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return file
            }
            guard let pointer = Self.parseLFSPointer(data) else { return file }
            return RemoteFile(
                name: file.name,
                downloadURL: file.downloadURL,
                size: pointer.size,
                sha256: pointer.oid,
                isLFS: true
            )
        } catch {
            return file
        }
    }

    private static func parseLFSPointer(_ data: Data) -> (oid: String, size: Int64)? {
        guard let text = String(data: data, encoding: .utf8),
              text.hasPrefix("version https://git-lfs.github.com/spec/v1") else {
            return nil
        }

        var oid: String?
        var size: Int64?
        for line in text.split(separator: "\n") {
            if line.hasPrefix("oid sha256:") {
                oid = String(line.dropFirst("oid sha256:".count))
            } else if line.hasPrefix("size ") {
                size = Int64(line.dropFirst("size ".count))
            }
        }
        guard let oid, let size else { return nil }
        return (oid, size)
    }

    // MARK: - URLs and helpers

    private func apiURL(_ pathAndQuery: String) -> URL {
        URL(string: "https://api.github.com\(pathAndQuery)")!
    }

    private static func rawURL(owner: String, repo: String, branch: String, path: String) -> URL {
        let encodedPath = path
            .split(separator: "/")
            .map { encode(String($0)) }
            .joined(separator: "/")
        return URL(string: "https://raw.githubusercontent.com/\(encode(owner))/\(encode(repo))/\(encode(branch))/\(encodedPath)")!
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    private static func rateLimitResetDate(_ response: HTTPURLResponse) -> Date? {
        response.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init)
            .map { Date(timeIntervalSince1970: $0) }
    }
}

private struct GHRepo: Decodable {
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case defaultBranch = "default_branch"
    }
}

private struct GHTree: Decodable {
    let tree: [GHTreeEntry]
    let truncated: Bool
}

private struct GHTreeEntry: Decodable {
    let path: String
    let type: String
    let size: Int64?
}
