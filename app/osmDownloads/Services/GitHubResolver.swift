import Foundation

// TODO: M3 — full implementation per handoff/SOURCE_RESOLVERS.md.
struct GitHubResolver: SourceResolver {
    let session: URLSession
    let token: String?

    init(session: URLSession = .shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        throw ResolverError.wrongKind
    }
}
