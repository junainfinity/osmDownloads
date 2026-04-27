import Foundation

/// Wraps a single `URLSession` and emits per-file events. The Coordinator owns
/// one Engine; views never touch this directly.
///
/// M1 uses `.default` configuration. Switching to `.background(withIdentifier:)`
/// for relaunch-survival is M4 (Pause/resume + concurrency) work.
final class DownloadEngine: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    let events: AsyncStream<DownloadEvent>
    private let continuation: AsyncStream<DownloadEvent>.Continuation

    private let lock = NSLock()
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var destinations: [UUID: URL] = [:]
    /// File IDs the user explicitly stopped (vs. paused). `didCompleteWithError`
    /// uses this to distinguish a stop (emit `.canceled`) from a pause (let the
    /// cancel-with-resume-data completion handler emit `.filePaused`).
    private var stopRequested: Set<UUID> = []
    private var session: URLSession!

    init(configuration: URLSessionConfiguration = .defaultEngine()) {
        var cont: AsyncStream<DownloadEvent>.Continuation!
        self.events = AsyncStream<DownloadEvent>(bufferingPolicy: .unbounded) { cont = $0 }
        self.continuation = cont
        super.init()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "app.osm.downloads.engine.delegate"
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }

    deinit {
        continuation.finish()
        session.invalidateAndCancel()
    }

    // MARK: - Public API

    func start(fileID: UUID, request: URLRequest, destination: URL) {
        lock.lock()
        destinations[fileID] = destination
        let task: URLSessionDownloadTask
        if let resumeData = ResumeStore.read(for: fileID) {
            let usable = ResumeStore.sanitize(resumeData) ?? resumeData
            task = session.downloadTask(withResumeData: usable)
            ResumeStore.delete(for: fileID)
        } else {
            task = session.downloadTask(with: request)
        }
        task.taskDescription = fileID.uuidString
        tasks[fileID] = task
        lock.unlock()
        task.resume()
        continuation.yield(.fileStarted(fileID: fileID, expectedSize: nil))
    }

    func pause(fileID: UUID) {
        lock.lock()
        guard let task = tasks[fileID] else { lock.unlock(); return }
        lock.unlock()

        // Only this completion handler emits `.filePaused`. The corresponding
        // `didCompleteWithError` with NSURLErrorCancelled is a no-op (filtered
        // by the empty `stopRequested` set).
        task.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            self.lock.lock()
            self.tasks[fileID] = nil
            self.lock.unlock()
            if let data {
                try? ResumeStore.write(data, for: fileID)
            }
            self.continuation.yield(.filePaused(fileID: fileID, hasResumeData: data != nil))
        })
    }

    func cancel(fileID: UUID) {
        lock.lock()
        stopRequested.insert(fileID)
        let task = tasks[fileID]
        lock.unlock()
        task?.cancel()
        ResumeStore.delete(for: fileID)
        // Map cleanup happens in didCompleteWithError where we'll see NSURLErrorCancelled.
    }

    /// Walk OS-persisted tasks (for `.background` config) and re-bind by `taskDescription`.
    /// No-op for `.default` config since those tasks die with the app.
    func reattachExistingTasks() async {
        let existing = await withCheckedContinuation { (cc: CheckedContinuation<[URLSessionTask], Never>) in
            session.getAllTasks { cc.resume(returning: $0) }
        }
        lock.withLock {
            for task in existing {
                guard let dt = task as? URLSessionDownloadTask,
                      let id = UUID(uuidString: dt.taskDescription ?? "") else {
                    task.cancel()
                    continue
                }
                tasks[id] = dt
            }
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = UUID(uuidString: downloadTask.taskDescription ?? "") else { return }
        let total: Int64? = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        continuation.yield(.bytesReceived(fileID: id, delta: totalBytesWritten, total: total))
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = UUID(uuidString: downloadTask.taskDescription ?? "") else { return }

        lock.lock()
        let destination = destinations[id]
        lock.unlock()
        guard let destination else {
            continuation.yield(.fileFailed(fileID: id, error: .invalidResponse))
            return
        }

        // The temp file is owned by URLSession and disappears after this delegate
        // returns, so move it synchronously here.
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            continuation.yield(.fileCompleted(fileID: id, localURL: destination))
        } catch let error as NSError {
            if error.code == NSFileWriteOutOfSpaceError {
                continuation.yield(.fileFailed(fileID: id, error: .diskFull))
            } else {
                continuation.yield(.fileFailed(fileID: id, error: .invalidResponse))
            }
        }

        lock.lock()
        tasks[id] = nil
        destinations[id] = nil
        lock.unlock()
        ResumeStore.delete(for: id)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let id = UUID(uuidString: task.taskDescription ?? "") else { return }
        guard let error = error as? NSError else { return }   // success path is handled in didFinishDownloadingTo

        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Distinguish stop (user pressed Stop) from pause (Pause).
            lock.lock()
            let wasStop = stopRequested.contains(id)
            stopRequested.remove(id)
            if wasStop {
                tasks[id] = nil
                destinations[id] = nil
            }
            lock.unlock()
            if wasStop {
                continuation.yield(.fileFailed(fileID: id, error: .canceled))
            }
            // Otherwise it was a pause — the cancel completion handler is authoritative.
            return
        }

        if error.code == NSFileWriteOutOfSpaceError {
            continuation.yield(.fileFailed(fileID: id, error: .diskFull))
        } else if let urlError = error as? URLError {
            continuation.yield(.fileFailed(fileID: id, error: .network(urlError)))
        } else {
            continuation.yield(.fileFailed(fileID: id, error: .invalidResponse))
        }

        lock.lock()
        tasks[id] = nil
        destinations[id] = nil
        lock.unlock()
    }
}

extension URLSessionConfiguration {
    static func defaultEngine() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 60 * 24
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        return config
    }
}

// MARK: - Speed estimator (used by Coordinator)

struct SpeedEstimator {
    private var lastBytes: Int64 = 0
    private var lastTime: Date?
    private var ema: Double = 0
    private let alpha: Double

    init(alpha: Double = 0.3) { self.alpha = alpha }

    /// Returns the smoothed bytes-per-second after observing `totalBytes`. The
    /// first call establishes a baseline and returns 0; subsequent calls return
    /// an EMA-smoothed rate.
    mutating func tick(totalBytes: Int64, now: Date = .now) -> Double {
        guard let last = lastTime else {
            lastBytes = totalBytes
            lastTime = now
            return 0
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0.05 else { return ema }
        let dBytes = max(0, Double(totalBytes - lastBytes))
        let instant = dBytes / dt
        ema = ema == 0 ? instant : (alpha * instant + (1 - alpha) * ema)
        lastBytes = totalBytes
        lastTime = now
        return ema
    }
}
