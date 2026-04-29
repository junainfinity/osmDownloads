import AppKit
import CryptoKit
import Foundation
import SwiftData
import UserNotifications

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
    private var retryAttempts: [UUID: Int] = [:]
    private var processingTask: Task<Void, Never>?
    private var reachabilityTask: Task<Void, Never>?

    init(context: ModelContext, engine: DownloadEngine = DownloadEngine()) {
        self.engine = engine
        self.context = context
        self.liveProgress = LiveProgressStore()
        startProcessingEvents()
        startReachabilityMonitor()
        cleanupOldHistory()
        Task { @MainActor [weak self] in
            await self?.restoreLaunchState()
        }
    }

    deinit {
        processingTask?.cancel()
        reachabilityTask?.cancel()
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
        var reservedPaths = Set<String>()
        for remote in selectedFiles {
            let localURL = Self.computeLocalURL(folder: jobFolder, name: remote.name, reservedPaths: reservedPaths)
            reservedPaths.insert(localURL.path)
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

        drainJobQueue()
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
        if !job.files.contains(where: { $0.status == .downloading }) {
            job.status = .paused
        }
        try? context.save()
        updateDockBadge()
        drainJobQueue()
    }

    func resumeJob(_ job: Job) {
        for file in job.files where file.status == .paused || file.status == .failed {
            file.status = .queued
            file.lastError = nil
        }
        if job.status == .paused || job.status == .failed {
            job.status = .queued
            job.completedAt = nil
        }
        try? context.save()
        drainJobQueue()
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
        updateDockBadge()
        drainJobQueue()
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
        job.status = .queued
        job.completedAt = nil
        try? context.save()
        drainJobQueue()
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
            file.status = .queued
            file.lastError = nil
            if job.status == .paused || job.status == .failed || job.status == .canceled {
                job.status = .queued
                job.completedAt = nil
            }
            try? context.save()
            if job.status == .downloading {
                kickNextQueuedFile(in: job)
            } else {
                drainJobQueue()
            }
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
            drainJobQueue()
        }
    }

    // MARK: - Internals

    private var currentLimit: Int {
        max(1, SettingsStore.shared.maxConcurrentFilesPerJob)
    }

    private var currentJobLimit: Int {
        max(1, SettingsStore.shared.maxConcurrentJobs)
    }

    private var activeJobCount: Int {
        fetchJobs().filter { $0.status == .downloading || $0.status == .resolving }.count
    }

    private func startJob(_ job: Job) {
        if job.startedAt == nil { job.startedAt = .now }
        job.status = .downloading
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
        engine.bind(fileID: file.id, destination: file.localURL)

        var request = URLRequest(url: file.remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if job.source == .huggingFace,
           let token = KeychainService.get(.huggingFace)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        engine.start(fileID: file.id, request: request, destination: file.localURL)
    }

    /// Promotes the next `.queued` file to `.downloading` if there's a free slot.
    private func kickNextQueuedFile(in job: Job) {
        let active = job.files.filter { $0.status == .downloading }.count
        guard active < currentLimit else { return }
        guard let next = job.files.first(where: { $0.status == .queued }) else { return }
        startFile(next, in: job)
    }

    private func drainJobQueue() {
        var slotsLeft = max(0, currentJobLimit - activeJobCount)
        guard slotsLeft > 0 else {
            updateDockBadge()
            return
        }

        let queued = fetchJobs()
            .filter { $0.status == .queued }
            .sorted { $0.createdAt < $1.createdAt }

        for job in queued where slotsLeft > 0 {
            startJob(job)
            slotsLeft -= 1
        }
        updateDockBadge()
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
            file.bytesDownloaded = total
            let speed = (fileEstimators[id]?.tick(totalBytes: total)) ?? 0
            liveProgress.update(fileID: id, bytesDownloaded: total, instantaneousBPS: speed)

        case .fileCompleted(let id, let localURL):
            guard let file = findFile(id) else { return }
            file.localURL = localURL
            file.bytesDownloaded = file.expectedSize ?? file.bytesDownloaded
            liveProgress.clear(fileID: id)
            fileEstimators[id] = nil
            retryAttempts[id] = nil
            if let expected = file.sha256, !expected.isEmpty {
                file.lastError = "Verifying checksum"
                try? context.save()
                Task { @MainActor [weak self] in
                    let result = await Self.verifySHA256(at: localURL, expected: expected)
                    guard let self, let file = self.findFile(id) else { return }
                    switch result {
                    case .success:
                        self.markCompleted(file)
                    case .failure(let error):
                        file.status = .failed
                        file.lastError = error.errorDescription
                        try? self.context.save()
                        if let job = file.job {
                            self.kickNextQueuedFile(in: job)
                            self.recomputeJobStatus(job)
                            self.drainJobQueue()
                        }
                    }
                }
            } else {
                markCompleted(file)
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
            } else if scheduleRetryIfNeeded(file: file, error: error) {
                liveProgress.clear(fileID: id)
                fileEstimators[id] = nil
                try? context.save()
                if let job = file.job { recomputeJobStatus(job) }
                return
            } else if shouldAutoPause(error) {
                file.status = .paused
                file.hasResumeData = ResumeStore.read(for: id) != nil
                file.lastError = error.errorDescription
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
                drainJobQueue()
            }
        }
    }

    private func markCompleted(_ file: FileItem) {
        file.status = .completed
        file.completedAt = .now
        file.lastError = nil
        try? context.save()
        if let job = file.job {
            kickNextQueuedFile(in: job)
            recomputeJobStatus(job)
            drainJobQueue()
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

        var newlyCompleted = false
        if allCompleted {
            job.status = .completed
            if job.completedAt == nil {
                job.completedAt = .now
                newlyCompleted = true
            }
        } else if allCanceled {
            job.status = .canceled
        } else if hasDownloading {
            job.status = .downloading
            if job.startedAt == nil { job.startedAt = .now }
        } else if hasQueued {
            job.status = job.startedAt == nil ? .queued : .downloading
        } else if hasPaused {
            job.status = .paused
        } else if hasFailed {
            job.status = .failed
            if job.completedAt == nil { job.completedAt = .now }
        }
        try? context.save()
        if newlyCompleted {
            notifyCompletion(job)
        }
        updateDockBadge()
    }

    private static func computeLocalURL(folder: URL, name: String, reservedPaths: Set<String> = []) -> URL {
        let parts = name.split(separator: "/").map(String.init)
        var url = folder
        for part in parts where !part.isEmpty { url = url.appendingPathComponent(part) }
        return uniqueURL(url, reservedPaths: reservedPaths)
    }

    private static func uniqueURL(_ url: URL, reservedPaths: Set<String>) -> URL {
        guard !reservedPaths.contains(url.path),
              !FileManager.default.fileExists(atPath: url.path) else { return nextAvailableURL(for: url, reservedPaths: reservedPaths) }
        return url
    }

    private static func nextAvailableURL(for url: URL, reservedPaths: Set<String>) -> URL {
        let directory = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        for index in 1..<10_000 {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !reservedPaths.contains(candidate.path),
               !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        let fallbackName = ext.isEmpty ? "\(base)-\(UUID().uuidString)" : "\(base)-\(UUID().uuidString).\(ext)"
        return directory.appendingPathComponent(fallbackName)
    }

    private func fetchJobs() -> [Job] {
        (try? context.fetch(FetchDescriptor<Job>())) ?? []
    }

    private func fetchFiles() -> [FileItem] {
        (try? context.fetch(FetchDescriptor<FileItem>())) ?? []
    }

    private func restoreLaunchState() async {
        await engine.reattachExistingTasks()
        let files = fetchFiles()
        ResumeStore.cleanup(validIDs: Set(files.map(\.id)))

        for file in files {
            if let jobID = file.job?.id {
                fileToJob[file.id] = jobID
            }
            engine.bind(fileID: file.id, destination: file.localURL)
        }

        for job in fetchJobs() {
            switch job.status {
            case .downloading, .resolving:
                restoreActive(job)
            case .queued:
                if !SettingsStore.shared.resumeIncompleteOnLaunch {
                    job.status = .paused
                    for file in job.files where file.status == .queued {
                        file.status = .paused
                    }
                }
            default:
                break
            }
        }
        try? context.save()
        drainJobQueue()
        updateDockBadge()
    }

    private func restoreActive(_ job: Job) {
        var hasLiveTask = false
        for file in job.files {
            switch file.status {
            case .downloading:
                if engine.hasTask(fileID: file.id) {
                    hasLiveTask = true
                    fileEstimators[file.id] = SpeedEstimator()
                } else if SettingsStore.shared.resumeIncompleteOnLaunch,
                          ResumeStore.read(for: file.id) != nil {
                    file.status = .queued
                } else {
                    file.status = .paused
                    file.hasResumeData = ResumeStore.read(for: file.id) != nil
                    file.lastError = "Paused after relaunch"
                }
            case .queued:
                if !SettingsStore.shared.resumeIncompleteOnLaunch {
                    file.status = .paused
                }
            default:
                break
            }
        }
        job.status = hasLiveTask ? .downloading : (SettingsStore.shared.resumeIncompleteOnLaunch ? .queued : .paused)
    }

    private func cleanupOldHistory() {
        let days = SettingsStore.shared.autoClearHistoryDays
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        for job in fetchJobs() {
            if let completed = job.completedAt, completed < cutoff {
                context.delete(job)
            }
        }
        try? context.save()
    }

    private func startReachabilityMonitor() {
        reachabilityTask = Task { @MainActor [weak self] in
            let stream = await ReachabilityService.shared.start()
            for await reachable in stream where reachable {
                self?.resumeNetworkPausedFiles()
            }
        }
    }

    private func resumeNetworkPausedFiles() {
        guard SettingsStore.shared.resumeIncompleteOnLaunch else { return }
        for job in fetchJobs() where job.status == .paused {
            var shouldQueueJob = false
            for file in job.files where file.status == .paused {
                if file.lastError?.localizedCaseInsensitiveContains("Network") == true ||
                    file.lastError?.localizedCaseInsensitiveContains("offline") == true {
                    file.status = .queued
                    file.lastError = nil
                    shouldQueueJob = true
                }
            }
            if shouldQueueJob { job.status = .queued }
        }
        try? context.save()
        drainJobQueue()
    }

    private func shouldAutoPause(_ error: DownloadError) -> Bool {
        if case .network(let urlError) = error {
            return urlError.code == .notConnectedToInternet
        }
        return false
    }

    private func scheduleRetryIfNeeded(file: FileItem, error: DownloadError) -> Bool {
        guard isRetryable(error) else { return false }
        let maxRetries = SettingsStore.shared.retryCount
        guard maxRetries > 0 else { return false }
        let attempt = (retryAttempts[file.id] ?? 0) + 1
        guard attempt <= maxRetries else { return false }
        retryAttempts[file.id] = attempt
        let delay = SettingsStore.shared.retryBackoffSeconds * pow(2, Double(attempt - 1))
        file.status = .paused
        file.lastError = "Retrying in \(Int(delay))s (\(attempt)/\(maxRetries))"
        let fileID = file.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, let file = self.findFile(fileID), file.status == .paused else { return }
            file.status = .queued
            file.lastError = nil
            if let job = file.job, job.status == .paused || job.status == .failed {
                job.status = .queued
            }
            try? self.context.save()
            self.drainJobQueue()
        }
        return true
    }

    private func isRetryable(_ error: DownloadError) -> Bool {
        switch error {
        case .network, .server, .invalidResponse:
            return true
        default:
            return false
        }
    }

    private static func verifySHA256(at url: URL, expected: String) async -> Result<Void, DownloadError> {
        await Task.detached(priority: .utility) {
            do {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                var hasher = SHA256()
                while true {
                    let data = handle.readData(ofLength: 1 << 20)
                    if data.isEmpty { break }
                    hasher.update(data: data)
                }
                let got = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                return got.caseInsensitiveCompare(expected) == .orderedSame
                    ? .success(())
                    : .failure(.checksumMismatch(expected: expected, got: got))
            } catch {
                return .failure(.invalidResponse)
            }
        }.value
    }

    private func updateDockBadge() {
        let count = fetchJobs().filter { $0.status == .downloading || $0.status == .queued }.count
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func notifyCompletion(_ job: Job) {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = "\(job.title) finished with \(job.files.count) file\(job.files.count == 1 ? "" : "s")."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "job-complete-\(job.id.uuidString)",
            content: content,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                center.add(request)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        center.add(request)
                    }
                }
            default:
                break
            }
        }
    }
}
