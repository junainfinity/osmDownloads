import Foundation
import Observation
import SwiftData

// MARK: - Enums

enum Source: String, Codable, CaseIterable, Sendable {
    case huggingFace
    case github
    case generic
}

enum JobStatus: String, Codable, Sendable {
    case queued
    case resolving
    case downloading
    case paused
    case completed
    case failed
    case canceled
}

enum FileStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case canceled
}

enum FileGroup: String, Codable, CaseIterable, Sendable {
    case weights
    case config
    case tokenizer
    case docs
    case code
    case asset
    case other

    static func infer(from filename: String) -> FileGroup {
        let lower = filename.lowercased()
        let ext = (lower as NSString).pathExtension
        if ["safetensors", "bin", "gguf", "pt", "ckpt", "pth", "onnx"].contains(ext) {
            return .weights
        }
        if lower.contains("tokenizer") || lower.contains("vocab") || lower.contains("merges") || lower.contains("special_tokens") {
            return .tokenizer
        }
        if ["json", "yaml", "yml", "toml"].contains(ext) {
            return .config
        }
        if ext == "md" || lower.hasPrefix("readme") || lower.hasPrefix("license") {
            return .docs
        }
        if ["py", "swift", "rs", "ts", "js", "go", "java", "kt"].contains(ext) {
            return .code
        }
        if ["png", "jpg", "jpeg", "gif", "webp", "svg"].contains(ext) {
            return .asset
        }
        return .other
    }

    /// Lower = shown first in the picker. Weights are what users actually want.
    var sortOrder: Int {
        switch self {
        case .weights:   return 0
        case .config:    return 1
        case .tokenizer: return 2
        case .code:      return 3
        case .docs:      return 4
        case .asset:     return 5
        case .other:     return 6
        }
    }
}

// MARK: - SwiftData @Model types

@Model
final class Job {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceRaw: String
    var sourceURL: URL
    var destinationFolder: URL
    var statusRaw: String

    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var lastError: String?

    @Relationship(deleteRule: .cascade, inverse: \FileItem.job)
    var files: [FileItem] = []

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .generic }
        set { sourceRaw = newValue.rawValue }
    }

    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    var totalBytes: Int64 {
        files.reduce(0) { $0 + ($1.expectedSize ?? 0) }
    }

    var bytesDownloaded: Int64 {
        files.reduce(0) { $0 + $1.bytesDownloaded }
    }

    var progress: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    var completedFileCount: Int {
        files.filter { $0.status == .completed }.count
    }

    init(
        id: UUID = UUID(),
        title: String,
        source: Source,
        sourceURL: URL,
        destinationFolder: URL,
        status: JobStatus = .queued
    ) {
        self.id = id
        self.title = title
        self.sourceRaw = source.rawValue
        self.sourceURL = sourceURL
        self.destinationFolder = destinationFolder
        self.statusRaw = status.rawValue
        self.createdAt = Date()
    }
}

@Model
final class FileItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var remoteURL: URL
    var localURL: URL
    var groupRaw: String
    var statusRaw: String

    var expectedSize: Int64?
    var bytesDownloaded: Int64 = 0
    var sha256: String?

    var hasResumeData: Bool = false

    var startedAt: Date?
    var completedAt: Date?
    var lastError: String?

    @Relationship var job: Job?

    var group: FileGroup {
        get { FileGroup(rawValue: groupRaw) ?? .other }
        set { groupRaw = newValue.rawValue }
    }

    var status: FileStatus {
        get { FileStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    var progress: Double? {
        guard let total = expectedSize, total > 0 else { return nil }
        return Double(bytesDownloaded) / Double(total)
    }

    init(
        id: UUID = UUID(),
        name: String,
        remoteURL: URL,
        localURL: URL,
        group: FileGroup,
        expectedSize: Int64?,
        sha256: String? = nil
    ) {
        self.id = id
        self.name = name
        self.remoteURL = remoteURL
        self.localURL = localURL
        self.groupRaw = group.rawValue
        self.statusRaw = FileStatus.queued.rawValue
        self.expectedSize = expectedSize
        self.sha256 = sha256
    }
}

// MARK: - Live progress

@Observable
final class LiveProgressStore: @unchecked Sendable {
    private(set) var files: [UUID: FileLiveProgress] = [:]
    private(set) var jobs: [UUID: JobLiveProgress] = [:]

    func update(fileID: UUID, bytesDownloaded: Int64, instantaneousBPS: Double) {
        var existing = files[fileID] ?? FileLiveProgress()
        existing.bytesDownloaded = bytesDownloaded
        existing.bytesPerSecond = ema(existing.bytesPerSecond, instantaneousBPS, alpha: 0.3)
        files[fileID] = existing
    }

    func updateJob(jobID: UUID, summary: JobLiveProgress) {
        jobs[jobID] = summary
    }

    func clear(fileID: UUID) { files[fileID] = nil }
    func clear(jobID: UUID)  { jobs[jobID] = nil }

    private func ema(_ prev: Double, _ next: Double, alpha: Double) -> Double {
        prev == 0 ? next : (alpha * next + (1 - alpha) * prev)
    }
}

struct FileLiveProgress: Sendable {
    var bytesDownloaded: Int64 = 0
    var bytesPerSecond: Double = 0
}

struct JobLiveProgress: Sendable {
    var bytesDownloaded: Int64 = 0
    var bytesPerSecond: Double = 0
    var etaSeconds: Double?
}

// MARK: - Transient request types

struct DownloadRequest: Sendable {
    let manifest: ResolvedManifest
    let selectedFileIDs: Set<UUID>
    let destinationFolder: URL
}

struct ResolvedManifest: Sendable {
    let title: String
    let source: Source
    let sourceURL: URL
    let files: [RemoteFile]
}

struct RemoteFile: Identifiable, Sendable {
    let id: UUID
    let name: String
    let downloadURL: URL
    let size: Int64?
    let group: FileGroup
    let sha256: String?
    let isLFS: Bool

    init(name: String, downloadURL: URL, size: Int64?, sha256: String? = nil, isLFS: Bool = false) {
        self.id = UUID()
        self.name = name
        self.downloadURL = downloadURL
        self.size = size
        self.group = FileGroup.infer(from: name)
        self.sha256 = sha256
        self.isLFS = isLFS
    }
}

// MARK: - Engine events

enum DownloadEvent: Sendable {
    case bytesReceived(fileID: UUID, delta: Int64, total: Int64?)
    case fileStarted(fileID: UUID, expectedSize: Int64?)
    case fileCompleted(fileID: UUID, localURL: URL)
    case filePaused(fileID: UUID, hasResumeData: Bool)
    case fileFailed(fileID: UUID, error: DownloadError)
}

enum DownloadError: Error, LocalizedError, Sendable {
    case network(URLError)
    case server(statusCode: Int, body: String?)
    case rangeNotSupported
    case diskFull
    case checksumMismatch(expected: String, got: String)
    case unauthorized
    case rateLimited(resetAt: Date?)
    case canceled
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .server(let code, _): return "Server returned \(code)"
        case .rangeNotSupported: return "Server doesn't support resuming"
        case .diskFull: return "Not enough disk space"
        case .checksumMismatch: return "Downloaded file is corrupt"
        case .unauthorized: return "Authentication required"
        case .rateLimited: return "Rate limit hit — try again later"
        case .canceled: return "Canceled"
        case .invalidResponse: return "Invalid response from server"
        }
    }
}
