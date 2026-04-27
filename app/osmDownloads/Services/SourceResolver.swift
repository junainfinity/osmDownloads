import Foundation

protocol SourceResolver: Sendable {
    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest
}

enum ResolverError: Error, LocalizedError {
    case wrongKind
    case invalidResponse
    case unauthorized
    case rateLimited(resetAt: Date?)
    case repoTooLarge
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .wrongKind:        return "Resolver received a URL it can't handle"
        case .invalidResponse:  return "Invalid response from server"
        case .unauthorized:     return "Authentication required"
        case .rateLimited:      return "Rate limit hit"
        case .repoTooLarge:     return "Repository is too large to enumerate"
        case .server(let code, _): return "Server returned \(code)"
        }
    }
}

actor ResolverCache {
    private var entries: [URL: (manifest: ResolvedManifest, expires: Date)] = [:]

    func get(_ url: URL) -> ResolvedManifest? {
        guard let entry = entries[url], entry.expires > .now else { return nil }
        return entry.manifest
    }

    func set(_ url: URL, _ manifest: ResolvedManifest, ttl: TimeInterval = 300) {
        entries[url] = (manifest, .now.addingTimeInterval(ttl))
    }
}
