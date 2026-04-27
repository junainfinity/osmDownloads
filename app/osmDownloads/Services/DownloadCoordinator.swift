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

    // MARK: - Public API

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
        for file in job.files where file.status == .downloading || file.status == .queued {
            engine.pause(fileID: file.id)
        }
    }

    func resumeJob(_ job: Job) {
        for file in job.files where file.status == .paused || file.status == .failed {
            startFile(file, in: job)
        }
        recomputeJobStatus(job)
    }

    func cancelJob(_ job: Job) {
        for file in job.files {
            engine.cancel(fileID: file.id)
            liveProgress.clear(fileID: file.id)
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
        for file in job.files where file.status == .failed {
            file.status = .queued
            file.bytesDownloaded = 0
            file.lastError = nil
            ResumeStore.delete(for: file.id)
        }
        startJob(job)
    }

    // MARK: - Internals

    private func startJob(_ job: Job) {
        job.status = .downloading
        if job.startedAt == nil { job.startedAt = .now }
        for file in job.files where file.status == .queued || file.status == .paused {
            startFile(file, in: job)
        }
        try? context.save()
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
            if let job = file.job { recomputeJobStatus(job) }

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
            if let job = file.job { recomputeJobStatus(job) }

        case .fileFailed(let id, let error):
            guard let file = findFile(id) else { return }
            file.status = (error.errorDescription == "Canceled") ? .canceled : .failed
            file.lastError = error.errorDescription
            liveProgress.clear(fileID: id)
            fileEstimators[id] = nil
            try? context.save()
            if let job = file.job { recomputeJobStatus(job) }
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
        if statuses.allSatisfy({ $0 == .completed }) {
            job.status = .completed
            job.completedAt = .now
        } else if statuses.contains(.downloading) {
            job.status = .downloading
        } else if statuses.allSatisfy({ $0 == .paused || $0 == .completed }) && statuses.contains(.paused) {
            job.status = .paused
        } else if statuses.allSatisfy({ $0 == .failed || $0 == .completed || $0 == .canceled })
                  && statuses.contains(.failed) {
            job.status = .failed
            job.completedAt = .now
        } else if statuses.allSatisfy({ $0 == .canceled }) {
            job.status = .canceled
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
