# DOWNLOAD_ENGINE — osmDownloads

The engine wraps `URLSession` with a background configuration so downloads survive app relaunch. It exposes an `AsyncStream<DownloadEvent>` and is driven by the `DownloadCoordinator`.

## URLSession configuration

```swift
let config = URLSessionConfiguration.background(withIdentifier: "app.osm.downloads.engine")
config.isDiscretionary = false              // user-initiated, run promptly
config.sessionSendsLaunchEvents = true      // wake app on completion if backgrounded
config.allowsCellularAccess = true          // macOS — irrelevant, but explicit
config.httpMaximumConnectionsPerHost = 6
config.timeoutIntervalForRequest = 30
config.timeoutIntervalForResource = 60 * 60 * 24   // a single file may take hours
config.waitsForConnectivity = true
```

`.background` configurations have important constraints:
- Only `downloadTask` and `uploadTask` are allowed — not `dataTask`.
- The session **must** have a delegate (delegate-based callbacks only).
- Tasks are persisted by the OS; killing the app does not cancel them.

## File download — happy path

```swift
let task = session.downloadTask(with: request)
task.taskDescription = fileItem.id.uuidString   // for re-attach after relaunch
task.resume()
```

In the delegate:

```swift
func urlSession(_ session: URLSession,
                downloadTask: URLSessionDownloadTask,
                didWriteData bytesWritten: Int64,
                totalBytesWritten total: Int64,
                totalBytesExpectedToWrite expected: Int64) {
    let id = UUID(uuidString: downloadTask.taskDescription ?? "") ?? .init()
    continuation.yield(.bytesReceived(fileID: id,
                                       delta: bytesWritten,
                                       total: expected > 0 ? expected : nil))
}

func urlSession(_ session: URLSession,
                downloadTask: URLSessionDownloadTask,
                didFinishDownloadingTo location: URL) {
    // location is a temp file owned by URLSession. Move it to its final home
    // SYNCHRONOUSLY in this delegate call — otherwise the temp file is deleted.
    let id = UUID(uuidString: downloadTask.taskDescription ?? "") ?? .init()
    let dest = destinations[id]!     // looked up from in-memory map
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.moveItem(at: location, to: dest)
    continuation.yield(.fileCompleted(fileID: id, localURL: dest))
}
```

## Pause / resume

`URLSessionDownloadTask` supports resume natively when the server sends `Accept-Ranges: bytes`.

```swift
func pause(fileID: UUID) {
    guard let task = tasks[fileID] else { return }
    task.cancel { [weak self] resumeData in
        guard let data = resumeData else {
            // Server didn't support ranges, or we got nothing back. Mark paused
            // but on resume we'll have to start over.
            self?.continuation.yield(.filePaused(fileID: fileID, hasResumeData: false))
            return
        }
        let url = ResumeStore.url(for: fileID)
        try? data.write(to: url, options: .atomic)
        self?.continuation.yield(.filePaused(fileID: fileID, hasResumeData: true))
    }
}

func resume(fileID: UUID, request: URLRequest) {
    let resumeURL = ResumeStore.url(for: fileID)
    let task: URLSessionDownloadTask
    if FileManager.default.fileExists(atPath: resumeURL.path),
       let data = try? Data(contentsOf: resumeURL) {
        task = session.downloadTask(withResumeData: data)
        try? FileManager.default.removeItem(at: resumeURL)
    } else {
        task = session.downloadTask(with: request)
    }
    task.taskDescription = fileID.uuidString
    tasks[fileID] = task
    task.resume()
}
```

### macOS resume-data caveat

There's a long-standing `URLSession` bug on macOS where resume data is sometimes corrupted (mismatched property list keys). Apply the canonical fix on read:

```swift
func sanitizeResumeData(_ data: Data) -> Data? {
    guard var plist = try? PropertyListSerialization
            .propertyList(from: data, options: .mutableContainersAndLeaves, format: nil)
            as? [String: Any] else { return nil }

    // Newer macOS versions expect __NSCFLocalSessionTaskResumeInfoVersion = 2,
    // older bundles ship version 1. Normalize.
    plist["$archiver"] = "NSKeyedArchiver"
    if plist["NSURLSessionResumeInfoVersion"] as? Int != 2 {
        plist["NSURLSessionResumeInfoVersion"] = 2
    }
    // Some snapshots are missing NSURLSessionResumeCurrentRequest — without it
    // resume crashes with `__CFTSDGetSpecific assertion`.
    return try? PropertyListSerialization.data(fromPropertyList: plist,
                                                format: .binary, options: 0)
}
```

If sanitization fails, fall back to fresh download from byte 0.

## Concurrency limiting

The engine itself is unlimited; the **Coordinator** enforces caps via a counted-semaphore actor:

```swift
actor ConcurrencyLimiter {
    private let max: Int
    private var inFlight: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(max: Int) { self.max = max }

    func acquire() async {
        if inFlight < max {
            inFlight += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
        inFlight += 1
    }

    func release() {
        inFlight -= 1
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        }
    }
}
```

Use one instance with `max = Settings.maxConcurrentJobs` at the Coordinator level, and one per Job with `max = Settings.maxConcurrentFilesPerJob`.

## Speed measurement

Don't compute speed from `(bytesWritten / totalBytesWritten)` — it's noisy. Use a fixed-window EMA:

```swift
struct SpeedEstimator {
    private var lastBytes: Int64 = 0
    private var lastTime: Date = .now
    private var ema: Double = 0
    private let alpha = 0.3

    mutating func tick(totalBytes: Int64) -> Double {
        let now = Date.now
        let dt = now.timeIntervalSince(lastTime)
        guard dt > 0.05 else { return ema }
        let dBytes = Double(totalBytes - lastBytes)
        let instant = dBytes / dt
        ema = ema == 0 ? instant : (alpha * instant + (1 - alpha) * ema)
        lastBytes = totalBytes
        lastTime = now
        return ema
    }
}
```

## Re-attaching tasks after relaunch

```swift
session.getAllTasks { [weak self] tasks in
    for task in tasks {
        guard let id = (task.taskDescription).flatMap(UUID.init(uuidString:)) else {
            task.cancel()        // unknown — orphan
            continue
        }
        self?.tasks[id] = task as? URLSessionDownloadTask
        // Coordinator looks up the matching FileItem and re-bridges UI state.
    }
}
```

## Failure handling

| Failure | Engine behavior | Coordinator response |
|---|---|---|
| `URLError.notConnectedToInternet` | yields `.fileFailed(.network)` | mark file paused, retry on Reachability |
| HTTP 401/403 | yields `.fileFailed(.unauthorized)` | mark job failed, surface auth prompt |
| HTTP 429 + `Retry-After` | yields `.fileFailed(.rateLimited)` | retry after header value, max 3x |
| HTTP 5xx | yields `.fileFailed(.server)` | exponential backoff up to N retries |
| `Accept-Ranges: none` and user pauses | yields `.filePaused(false)` | warn, on resume restart from 0 |
| `NSPOSIXErrorDomain` 28 (ENOSPC) | yields `.fileFailed(.diskFull)` | mark job failed; do NOT delete partial |

## Checksum verification

When the resolver provides `sha256` (HF does for LFS files), verify after `fileCompleted`:

```swift
func verifySHA256(at url: URL, expected: String) async throws {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while autoreleasepool(invoking: {
        let chunk = handle.readData(ofLength: 1 << 20)   // 1 MiB
        hasher.update(data: chunk)
        return !chunk.isEmpty
    }) {}
    let got = hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    guard got == expected else {
        throw DownloadError.checksumMismatch(expected: expected, got: got)
    }
}
```

Run on a `Task.detached(priority: .background)` so it doesn't block the engine.
