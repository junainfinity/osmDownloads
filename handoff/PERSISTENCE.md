# PERSISTENCE — osmDownloads

## SwiftData container

Set up once at app launch:

```swift
@main
struct osmDownloadsApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Job.self, FileItem.self,
                configurations: ModelConfiguration(
                    "osmDownloads",
                    schema: Schema([Job.self, FileItem.self]),
                    url: AppPaths.storeURL,
                    cloudKitDatabase: .none      // never sync to iCloud
                )
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { AppShell() }
            .modelContainer(container)
    }
}

enum AppPaths {
    static var supportDir: URL {
        try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("osmDownloads", conformingTo: .directory)
    }
    static var storeURL: URL { supportDir.appendingPathComponent("store.sqlite") }
    static var resumeDir: URL {
        let url = supportDir.appendingPathComponent("resume", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var logsDir: URL {
        let url = supportDir.appendingPathComponent("logs", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

## Schema versions

- **v1** (initial): `Job` + `FileItem` as in `Models.swift`.
- Plan ahead: when adding fields, use `VersionedSchema` + `SchemaMigrationPlan`. SwiftData supports lightweight migrations for additive changes.

## Resume data on disk

```swift
enum ResumeStore {
    static func url(for fileID: UUID) -> URL {
        AppPaths.resumeDir.appendingPathComponent("\(fileID.uuidString).resumedata")
    }
    static func write(_ data: Data, for fileID: UUID) throws {
        try data.write(to: url(for: fileID), options: .atomic)
    }
    static func read(for fileID: UUID) -> Data? {
        try? Data(contentsOf: url(for: fileID))
    }
    static func delete(for fileID: UUID) {
        try? FileManager.default.removeItem(at: url(for: fileID))
    }
    static func cleanup(validIDs: Set<UUID>) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: AppPaths.resumeDir,
                                                        includingPropertiesForKeys: nil) else { return }
        for url in entries {
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            if let id, !validIDs.contains(id) { try? fm.removeItem(at: url) }
        }
    }
}
```

Run `cleanup` on launch to drop orphaned resume blobs (file deleted but blob lingered).

## Launch sequence

```
applicationDidFinishLaunching
  ├─ Build ModelContainer
  ├─ Build URLSession (background config)
  ├─ session.getAllTasks → re-attach to FileItems by taskDescription
  ├─ ResumeStore.cleanup(validIDs:)
  ├─ For each Job where status == .downloading or .paused:
  │    ├─ If file has live URLSessionTask → already re-attached, do nothing
  │    ├─ Else if ResumeStore has blob → enqueue via resume(fileID:)
  │    └─ Else → mark FileItem .paused, leave for user
  └─ Coordinator.start() (begins draining queue)
```

## Quit sequence

```
applicationShouldTerminate
  ├─ Coordinator.suspendAll()
  │    ├─ For each in-flight task:
  │    │    └─ task.cancel(byProducingResumeData:) → write to ResumeStore
  │    └─ wait until all callbacks fire, max 5 s
  ├─ Save SwiftData context
  └─ return .terminateNow
```

If the user force-quits or the OS kills the app, the background URLSession keeps tasks running and the OS persists their state. Next launch's `getAllTasks` re-attaches.

## What we DON'T persist

- `LiveProgressStore` — purely in-memory, recomputed from delegate callbacks.
- Speed/ETA — recomputed.
- Search query, scroll position, expanded job IDs — `@SceneStorage` is fine for these.

## Settings

Use `@AppStorage` for primitives (paths, ints, bools) — backed by `UserDefaults`. Use `Keychain` for tokens.

```swift
@AppStorage("destinationFolderBookmark") var destinationBookmark: Data?
@AppStorage("maxConcurrentJobs") var maxConcurrentJobs: Int = 3
@AppStorage("maxConcurrentFilesPerJob") var maxConcurrentFilesPerJob: Int = 4
@AppStorage("retryCount") var retryCount: Int = 3
@AppStorage("retryBackoffSeconds") var retryBackoff: Double = 2.0
@AppStorage("autoClearHistoryDays") var autoClearHistoryDays: Int = 0   // 0 = never
@AppStorage("themePreference") var themePreference: String = "system"   // system|light|dark
```

### Why bookmark for the destination folder?

If the app is sandboxed (or a future TestFlight build is), the user-picked folder requires a security-scoped bookmark to access across launches:

```swift
let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                     includingResourceValuesForKeys: nil,
                                     relativeTo: nil)
// later:
var stale = false
let url = try URL(resolvingBookmarkData: bookmark,
                  options: .withSecurityScope,
                  relativeTo: nil,
                  bookmarkDataIsStale: &stale)
_ = url.startAccessingSecurityScopedResource()
defer { url.stopAccessingSecurityScopedResource() }
```

Even if V1 ships unsandboxed, write the bookmark code now — switching later is painful.

### Tokens (Keychain)

```swift
enum KeychainService {
    static func set(_ value: String, account: String) throws { /* SecItemAdd / Update */ }
    static func get(_ account: String) -> String? { /* SecItemCopyMatching */ }
    static func delete(_ account: String) { /* SecItemDelete */ }
}

// accounts:
//   "huggingface.token"
//   "github.token"
```

## Auto-clear history

If `autoClearHistoryDays > 0`, run on launch and once per day:

```swift
let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
let descriptor = FetchDescriptor<Job>(
    predicate: #Predicate { $0.completedAt != nil && $0.completedAt! < cutoff }
)
let stale = try context.fetch(descriptor)
for job in stale { context.delete(job) }
try context.save()
```

This deletes the `Job` rows but **does not touch the downloaded files on disk** — that's the user's content.
