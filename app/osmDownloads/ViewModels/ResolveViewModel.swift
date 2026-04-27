import Foundation
import Observation

enum ResolveState: Sendable {
    case idle
    case classifying
    case classified(ClassifiedURL)
    case resolving(ClassifiedURL)
    case ready(ResolvedManifest)
    case error(String)
}

@Observable
@MainActor
final class ResolveViewModel {
    var urlString: String = "" {
        didSet { onURLChange() }
    }
    var state: ResolveState = .idle
    var selectedFileIDs: Set<UUID> = []

    private var resolveTask: Task<Void, Never>?
    private let cache = ResolverCache()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var canDownload: Bool {
        if case .ready = state, !selectedFileIDs.isEmpty { return true }
        return false
    }

    var resolvedManifest: ResolvedManifest? {
        if case .ready(let m) = state { return m }
        return nil
    }

    var classifiedKind: ClassifiedURL? {
        switch state {
        case .classified(let k), .resolving(let k): return k
        default: return nil
        }
    }

    func reset() {
        urlString = ""
        state = .idle
        selectedFileIDs = []
        resolveTask?.cancel()
        resolveTask = nil
    }

    func selectAll() {
        if let m = resolvedManifest {
            selectedFileIDs = Set(m.files.map(\.id))
        }
    }

    func selectNone() {
        selectedFileIDs = []
    }

    func toggle(_ id: UUID) {
        if selectedFileIDs.contains(id) {
            selectedFileIDs.remove(id)
        } else {
            selectedFileIDs.insert(id)
        }
    }

    private func onURLChange() {
        resolveTask?.cancel()
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            selectedFileIDs = []
            return
        }
        let kind = URLClassifier.classify(trimmed)
        state = .classified(kind)

        // Auto-resolve generic URLs and HF/GH URLs (HF/GH are stubs in M1).
        resolveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))   // debounce
            guard !Task.isCancelled else { return }
            await self?.resolveIfNeeded(kind)
        }
    }

    private func resolveIfNeeded(_ kind: ClassifiedURL) async {
        switch kind {
        case .invalid(let reason):
            state = .error(reason)
            return
        case .generic(let url):
            await runResolver(GenericResolver(session: session), kind: kind, cacheKey: url)
        case .huggingFace, .huggingFaceFile:
            let cacheKey = kind.originalURL ?? URL(string: "huggingface:\(UUID().uuidString)")!
            let token = KeychainService.get(.huggingFace)
            await runResolver(HuggingFaceResolver(session: session, token: token),
                              kind: kind, cacheKey: cacheKey)
        case .github, .githubFile:
            state = .error("GitHub is coming in M3")
        }
    }

    private func runResolver(_ resolver: SourceResolver, kind: ClassifiedURL, cacheKey: URL) async {
        if let cached = await cache.get(cacheKey) {
            state = .ready(cached)
            selectedFileIDs = Set(cached.files.map(\.id))
            return
        }
        state = .resolving(kind)
        do {
            let manifest = try await resolver.resolve(kind)
            guard !Task.isCancelled else { return }
            if manifest.files.isEmpty {
                state = .error("No downloadable files found.")
                selectedFileIDs = []
                return
            }
            await cache.set(cacheKey, manifest)
            state = .ready(manifest)
            selectedFileIDs = Set(manifest.files.map(\.id))
        } catch let resolverErr as ResolverError {
            state = .error(friendlyMessage(resolverErr))
        } catch {
            state = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func friendlyMessage(_ err: ResolverError) -> String {
        switch err {
        case .unauthorized:
            return "This repo is gated or private — add your Hugging Face token in Settings."
        case .rateLimited:
            return "Rate limit hit — try again later, or add a token in Settings for higher limits."
        case .repoTooLarge:
            return "Repository is too large to enumerate — use git clone instead."
        case .server(let code, let body):
            return body ?? "Server returned \(code)"
        case .invalidResponse:
            return "Invalid response from server."
        case .wrongKind:
            return "Resolver received a URL it can't handle."
        }
    }
}
