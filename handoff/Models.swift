//
//  Models.swift
//  osmDownloads
//
//  Drop into the project root. Requires macOS 14+ for SwiftData.
//  This is a reference sketch — extend with relationships, validation,
//  and migrations as the schema evolves.
//

import Foundation
import SwiftData

// MARK: - Enums

enum Source: String, Codable, CaseIterable {
    case huggingFace
    case github
    case generic
}

enum JobStatus: String, Codable {
    case queued        // accepted, waiting for a slot
    case resolving     // fetching manifest from API
    case downloading
    case paused
    case completed
    case failed
    case canceled
}

enum FileStatus: String, Codable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case canceled
}

enum FileGroup: String, Codable, CaseIterable {
    case weights       // .safetensors, .bin, .gguf, .pt, .ckpt
    case config        // .json, .yaml
    case tokenizer     // tokenizer*, vocab*, merges*, special_tokens*
    case docs          // README, *.md
    case code          // .py, .swift, etc.
    case asset         // images, etc.
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
}

// MARK: - SwiftData @Model types

@Model
final class Job {
    @Attribute(.unique) var id: UUID
    var title: String                // "meta-llama/Llama-3.1-8B-Instruct"
    var sourceRaw: String            // store enum raw string
    var sourceURL: URL               // user's pasted URL
    var destinationFolder: URL       // where files land
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

    /// Sum of size for all selected files (in bytes). nil-safe.
    var totalBytes: Int64 {
        files.reduce(0) { $0 + ($1.expectedSize ?? 0) }
    }

    /// Sum of bytes downloaded so far across all files.
    var bytesDownloaded: Int64 {
        files.reduce(0) { $0 + $1.bytesDownloaded }
    }

    /// 0...1, or nil if any file has unknown size and we haven't started.
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
    var name: String                 // "model-00001-of-00004.safetensors"
    var remoteURL: URL               // CDN URL for the actual download
    var localURL: URL                // destinationFolder + name (computed at enqueue)
    var groupRaw: String
    var statusRaw: String

    var expectedSize: Int64?         // bytes; nil until first response
    var bytesDownloaded: Int64 = 0
    var sha256: String?              // for HF files where it's known up front

    /// URLSessionDownloadTask resume data, snapshotted on pause.
    /// Stored on disk under Application Support/resume/{id}.resumedata
    /// — this column tracks whether the file exists.
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

// MARK: - Live progress (NOT @Model — kept in memory for tick-rate updates)

/// Owns the current bytes-per-second snapshot per file, and an EMA-smoothed
/// aggregate. Coordinator writes to it; views observe.
@Observable
final class LiveProgressStore {
    /// fileID → snapshot
    private(set) var files: [UUID: FileLiveProgress] = [:]
    /// jobID → snapshot
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

struct FileLiveProgress {
    var bytesDownloaded: Int64 = 0
    var bytesPerSecond: Double = 0
}

struct JobLiveProgress {
    var bytesDownloaded: Int64 = 0
    var bytesPerSecond: Double = 0
    var etaSeconds: Double?
}

// MARK: - Transient request (not persisted)

struct DownloadRequest {
    let manifest: ResolvedManifest
    let selectedFileIDs: Set<UUID>
    let destinationFolder: URL
}

struct ResolvedManifest {
    let title: String
    let source: Source
    let sourceURL: URL
    let files: [RemoteFile]
}

struct RemoteFile: Identifiable {
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

enum DownloadEvent {
    case bytesReceived(fileID: UUID, delta: Int64, total: Int64?)
    case fileStarted(fileID: UUID, expectedSize: Int64?)
    case fileCompleted(fileID: UUID, localURL: URL)
    case filePaused(fileID: UUID, hasResumeData: Bool)
    case fileFailed(fileID: UUID, error: DownloadError)
}

enum DownloadError: Error, LocalizedError {
    case network(URLError)
    case server(statusCode: Int, body: String?)
    case rangeNotSupported
    case diskFull
    case checksumMismatch(expected: String, got: String)
    case unauthorized            // HF gated, GH private
    case rateLimited(resetAt: Date?)
    case canceled

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
        }
    }
}
