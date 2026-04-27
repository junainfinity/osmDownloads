import Foundation

enum HFRepoType: String, Sendable {
    case models, datasets, spaces

    var apiPath: String {
        switch self {
        case .models: return "models"
        case .datasets: return "datasets"
        case .spaces: return "spaces"
        }
    }
}

enum ClassifiedURL: Sendable {
    case huggingFace(repoType: HFRepoType, org: String, repo: String, branch: String, subpath: String, originalURL: URL)
    case huggingFaceFile(repoType: HFRepoType, org: String, repo: String, branch: String, path: String, originalURL: URL)
    case github(org: String, repo: String, branch: String, subpath: String, originalURL: URL)
    case githubFile(org: String, repo: String, branch: String, path: String, originalURL: URL)
    case generic(URL)
    case invalid(reason: String)

    var originalURL: URL? {
        switch self {
        case .huggingFace(_, _, _, _, _, let u),
             .huggingFaceFile(_, _, _, _, _, let u),
             .github(_, _, _, _, let u),
             .githubFile(_, _, _, _, let u),
             .generic(let u):
            return u
        case .invalid:
            return nil
        }
    }
}

enum URLClassifier {
    static func classify(_ raw: String) -> ClassifiedURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid(reason: "Empty URL") }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased() else {
            return .invalid(reason: "Not a valid http(s) URL")
        }

        // Strip query/fragment for classification; preserve original URL for the download.
        var classifyURL = url
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        if let cleaned = components?.url { classifyURL = cleaned }

        if host == "huggingface.co" {
            return classifyHuggingFace(classifyURL, original: url) ?? .invalid(reason: "Unrecognized Hugging Face URL")
        }
        if host == "github.com" {
            return classifyGitHub(classifyURL, original: url) ?? .invalid(reason: "Unrecognized GitHub URL")
        }
        return .generic(url)
    }

    // MARK: - Hugging Face

    /// Pattern (with optional /datasets/ or /spaces/ prefix):
    /// /[type/]org/repo[/tree/branch[/subpath]]
    /// /[type/]org/repo/blob/branch/path
    /// /[type/]org/repo/resolve/branch/path
    private static func classifyHuggingFace(_ url: URL, original: URL) -> ClassifiedURL? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard !parts.isEmpty else { return nil }

        var idx = 0
        var repoType: HFRepoType = .models

        if let first = parts.first, let parsed = HFRepoType(rawValue: first) {
            repoType = parsed
            idx = 1
        }

        // Need at least org and repo after optional type.
        guard parts.count >= idx + 2 else { return nil }
        let org = parts[idx]
        let repo = parts[idx + 1]
        let rest = Array(parts.suffix(from: idx + 2))

        if rest.isEmpty {
            return .huggingFace(repoType: repoType, org: org, repo: repo,
                                branch: "main", subpath: "", originalURL: original)
        }

        switch rest.first {
        case "tree":
            // tree/{branch}/{subpath...}
            guard rest.count >= 2 else { return nil }
            let branch = rest[1]
            let subpath = rest.count > 2 ? rest.suffix(from: 2).joined(separator: "/") : ""
            return .huggingFace(repoType: repoType, org: org, repo: repo,
                                branch: branch, subpath: subpath, originalURL: original)
        case "blob", "resolve":
            // blob/{branch}/{path...}
            guard rest.count >= 3 else { return nil }
            let branch = rest[1]
            let path = rest.suffix(from: 2).joined(separator: "/")
            return .huggingFaceFile(repoType: repoType, org: org, repo: repo,
                                    branch: branch, path: path, originalURL: original)
        default:
            return nil
        }
    }

    // MARK: - GitHub

    /// /org/repo[/tree/branch[/subpath]]
    /// /org/repo/blob/branch/path
    /// /org/repo/releases/download/... -> not currently handled, falls through.
    private static func classifyGitHub(_ url: URL, original: URL) -> ClassifiedURL? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        let org = parts[0]
        let repo = parts[1]
        let rest = Array(parts.suffix(from: 2))

        if rest.isEmpty {
            return .github(org: org, repo: repo, branch: "", subpath: "", originalURL: original)
        }

        switch rest.first {
        case "tree":
            guard rest.count >= 2 else { return nil }
            let branch = rest[1]
            let subpath = rest.count > 2 ? rest.suffix(from: 2).joined(separator: "/") : ""
            return .github(org: org, repo: repo, branch: branch, subpath: subpath, originalURL: original)
        case "blob":
            guard rest.count >= 3 else { return nil }
            let branch = rest[1]
            let path = rest.suffix(from: 2).joined(separator: "/")
            return .githubFile(org: org, repo: repo, branch: branch, path: path, originalURL: original)
        default:
            // /releases/download/... and other paths — treat as generic for V1.
            return .generic(original)
        }
    }
}
