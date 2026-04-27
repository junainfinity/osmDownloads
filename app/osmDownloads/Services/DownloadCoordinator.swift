import Foundation
import SwiftData

/// Owns the engine, job lifecycle, and writes job/file state to SwiftData.
/// Lives on the main actor so SwiftData ModelContext access stays single-threaded
/// and SwiftUI re-renders react immediately.
@MainActor
final class DownloadCoordinator {
    private let engine: DownloadEngine
    private let context: ModelContext
    let liveProgress: LiveProgressStore

    private var fileEstimators: [UUID: SpeedEstimator] = [:]
    private var fileToJob: [UUID: UUID] = [:]
    private var processingTask: Task<Void, Never>?

    init(context: ModelContext, engine: DownloadEngine = DownloadEngine()) {
        self.engine = engine
        self.context = context
        self.liveProgress = LiveProgressStore()
        startProcessingEvents()
    }

    deinit {
        processingTask?.cancel()
    }

    // MARK: - Public API (job-level)

    @discardableResult
    func enqueue(_ manifest: ResolvedManifest, selectedFileIDs: Set<UUID>, destination: URL) -> Job {
        let folderName = FileSystemService.slugify(manifest.title)
        let jobFolder = destination.appendingPathComponent(folderName, conformingTo: .directory)
        try? FileManager.default.createDirectory(at: jobFolder, withIntermediateDirectories: true)

        let job = Job(
            title: manifest.title,
            source: manifest.source,
            sourceURL: manifest.sourceURL,
            destinationFolder: jobFolder,
            status: .queued
        )
        context.insert(job)

        let selectedFiles = manifest.files.filter { selectedFileIDs.contains($0.id) }
        for remote in selectedFiles {
            let localURL = Self.computeLocalURL(folder: jobFolder, name: remote.name)
            let item = FileItem(
                id: remote.id,
                name: remote.name,
                remoteURL: remote.downloadURL,
                localURL: localURL,
                group: remote.group,
                expectedSize: remote.size,
                sha256: remote.sha256
            )
            item.job = job
            context.insert(item)
            fileToJob[item.id] = job.id
        }
        try? context.save()

        startJob(job)
        return job
    }

    func pauseJob(_ job: Job) {
        for file in job.files where file.status == .downloading {
            engine.pause(fileID: file.id)
        }
        for file in job.files where file.status == .queued {
            // Queued files have no task to cancel; demote to paused directly.
            file.status = .paused
            file.hasResumeData = false
        }
        try? context.save()
    }

    func resumeJob(_ job: Job) {
        let limit = currentLimit
        let alreadyActive = job.files.filter { $0.status == .downloading }.count
        var slotsLeft = max(0, limit - alreadyActive)

        for file in job.files where file.status == .paused || file.status == .failed {
            if slotsLeft > 0 {
                startFile(file, in: job)
                slotsLeft -= 1
            } else {
                file.status = .queued
                file.lastError = nil
            }
        }
        try? context.save()
        recomputeJobStatus(job)
    }

    func cancelJob(_ job: Job) {
        for file in job.files {
            engine.cancel(fileID: file.id)
            liveProgress.clear(fileID: file.id)
            fileEstimators[file.id] = nil
            if file.status == .queued || file.status == .paused {
                file.status = .canceled
            }
        }
        job.status = .canceled
        try? context.save()
    }

    func removeJob(_ job: Job) {
        cancelJob(job)
        context.delete(job)
        try? context.save()
    }

    func retryJob(_ job: Job) {
        for file in job.files where file.status == .failed || file.status == .canceled {
            file.status = .queued
            file.bytesDownloaded = 0
            file.lastError = nil
            ResumeStore.delete(for: file.id)
        }
        startJob(job)
    }

    // MARK: - Public API (per-file)

    func pauseFile(_ file: FileItem) {
        switch file.status {
        case .downloading:
            engine.pause(fileID: file.id)
        case .queued:
            file.status = .paused
            file.hasResumeData = false
            try? context.save()
            if let job = file.job { recomputeJobStatus(job) }
        default:
            break
        }
    }

    func resumeFile(_ file: FileItem) {
        guard let job = file.job else { return }
        switch file.status {
        case .paused, .failed, .canceled, .queued:
            startFile(file, in: job)
            try? context.save()
            recomputeJobStatus(job)
        default:
            break
        }
    }

    func cancelFile(_ file: FileItem) {
        engine.cancel(fileID: file.id)
        liveProgress.clear(fileID: file.id)
        fileEstimators[file.id] = nil
        if file.status == .queued || file.status == .paused {
            file.status = .canceled
        }
        try? context.save()
        if let job = file.job {
            kickNextQueuedFile(in: job)
            recomputeJobStatus(job)
        }
    }

    // MARK: - Internals

    private var currentLimit: Int {
        max(1, SettingsStore.shared.maxConcurrentFilesPerJob)
    }

    private func startJob(_ job: Job) {
        if job.startedAt == nil { job.startedAt = .now }
        let limit = currentLimit
        var started = 0
        for file in job.files where file.status == .queued || file.status == .paused {
            if started < limit {
                startFile(file, in: job)
                started += 1
            } else {
                file.status = .queued
                file.lastError = nil
            }
        }
        try? context.save()
        recomputeJobStatus(job)
    }

    private func startFile(_ file: FileItem, in job: Job) {
        file.status = .downloading
        file.startedAt = file.startedAt ?? .now
        file.lastError = nil
        fileToJob[file.id] = job.id
        fileEstimators[file.id] = SpeedEstimator()

        var request = URLRequest(url: file.remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        engine.start(fileID: file.id, request: request, destination: file.localURL)
    }

    /// Promotes the next `.queued` file to `.downloading` if there's a free slot.
    private func kickNextQueuedFile(in job: Job) {
        let active = job.files.filter { $0.status == .downloading }.count
        guard active < currentLimit else { return }
        guard let next = job.files.first(where: { $0.status == .queued }) else { return }
        startFile(next, in: job)
    }

    private func startProcessingEvents() {
        let stream = engine.events
        processingTask = Task { @MainActor [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: DownloadEvent) {
        switch event {
        case .fileStarted(let id, _):
            if let file = findFile(id) {
                file.status = .downloading
                if file.startedAt == nil { file.startedAt = .now }
            }

        case .bytesReceived(let id, let total, let expected):
            guard let file = findFile(id) else { return }
            if let expected, file.expectedSize == nil { file.expectedSize = expected }
            // Engine sends totalBytesWritten in the `delta` slot — bytesDownloaded is the cumulative count.
            let speed = (fileEstimators[id]?.tick(totalBytes: total)) ?? 0
            liveProgress.update(fileID: id, bytesDownloaded: total, instantaneousBPS: speed)

        case .fileCompleted(let id, let localURL):
            guard let file = findFile(id) else { return }
            file.status = .completed
            file.completedAt = .now
            file.localURL = localURL
            file.bytesDownloaded = file.expectedSize ?? file.bytesDownloaded
            liveProgress.clear(fileID: id)
            fileEstimators[id] = nil
            try? context.save()
            if let job = file.job {
                kickNextQueuedFile(in: job)
                recomputeJobStatus(job)
            }

        case .filePaused(let id, let hasResumeData):
            guard let file = findFile(id) else { return }
            file.status = .paused
            file.hasResumeData = hasResumeData
            // Flush live progress to model on pause.
            if let live = liveProgress.files[id] {
                file.bytesDownloaded = live.bytesDownloaded
            }
            liveProgress.clear(fileID: id)
            fileEstimators[id] = nil
            try? context.save()
            if let job = file.job {
                kickNextQueuedFile(in: job)
                recomputeJobStatus(job)
            }

        case .fileFailed(let id, let error):
            guard let file = findFile(id) else { return }
            if case .canceled = error {
                file.status = .canceled
            } else {
                file.status = .failed
            }
            file.lastError = error.errorDescription
            liveProgress.clear(fileID: id)
            fileEstimators[id] = nil
            try? context.save()
            if let job = file.job {
                kickNextQueuedFile(in: job)
                recomputeJobStatus(job)
            }
        }
    }

    private func findFile(_ id: UUID) -> FileItem? {
        let predicate = #Predicate<FileItem> { $0.id == id }
        var descriptor = FetchDescriptor<FileItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func recomputeJobStatus(_ job: Job) {
        let statuses = job.files.map(\.status)
        guard !statuses.isEmpty else { return }

        let hasDownloading = statuses.contains(.downloading)
        let hasQueued      = statuses.contains(.queued)
        let hasPaused      = statuses.contains(.paused)
        let hasFailed      = statuses.contains(.failed)
        let allCompleted   = statuses.allSatisfy { $0 == .completed }
        let allCanceled    = statuses.allSatisfy { $0 == .canceled }

        if allCompleted {
            job.status = .completed
            if job.completedAt == nil { job.completedAt = .now }
        } else if allCanceled {
            job.status = .canceled
        } else if hasDownloading || hasQueued {
            job.status = .downloading
            if job.startedAt == nil { job.startedAt = .now }
        } else if hasPaused {
            job.status = .paused
        } else if hasFailed {
            job.status = .failed
            if job.completedAt == nil { job.completedAt = .now }
        }
        try? context.save()
    }

    private static func computeLocalURL(folder: URL, name: String) -> URL {
        let parts = name.split(separator: "/").map(String.init)
        var url = folder
        for part in parts where !part.isEmpty { url = url.appendingPathComponent(part) }
        return url
    }
}
