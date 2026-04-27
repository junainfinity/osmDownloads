# ARCHITECTURE — osmDownloads

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                            │
│   • AppShell    • Sidebar    • ActiveView    • HistoryView  │
│   • NewDownloadBar    • ResolvedSheet    • JobCard          │
└──────────────────────────────────────────────────────────────┘
                          ▲
                          │ @Observable / @Query
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  ViewModels (@Observable)                                   │
│   • AppViewModel  — view routing, search, theme             │
│   • JobsViewModel — wraps DownloadCoordinator + SwiftData   │
│   • ResolveViewModel — drives URL classification + fetch    │
└──────────────────────────────────────────────────────────────┘
                          ▲
                          │ async/await
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Services                                                   │
│   • URLClassifier         — pure function, regex match      │
│   • SourceResolver        — protocol; HF + GH + Generic     │
│   • DownloadCoordinator   — actor; owns engine + queue      │
│   • DownloadEngine        — actor; URLSessionDownloadTask   │
│   • FileSystemService     — reveal, exists, free space      │
│   • SettingsStore         — @AppStorage-backed              │
│   • KeychainService       — HF + GH tokens                  │
└──────────────────────────────────────────────────────────────┘
                          ▲
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Persistence                                                │
│   • SwiftData ModelContainer                                │
│   • Models: Job, FileItem, JobEvent (audit log, optional)   │
│   • Resume data blobs in Application Support/resume/        │
└─────────────────────────────────────────────────────────────┘
```

## Module boundaries — what depends on what

- **Views** → ViewModels only. Never touch services or models directly except by `@Query`.
- **ViewModels** → Services + Models. Hold no UIKit/SwiftUI types.
- **Services** → other Services + Models. No SwiftUI imports anywhere.
- **Models** → Foundation only.

This keeps Views previewable and Services unit-testable without spinning up a SwiftData container.

## Concurrency model

- **`DownloadCoordinator`** is an `actor`. Owns the active job set, the queue, and a reference to the `DownloadEngine`. All mutations to job state go through it.
- **`DownloadEngine`** is an `actor`. Wraps a single `URLSession` (configured `.background` for app-relaunch resume support). Owns the dictionary `[FileItem.ID: URLSessionDownloadTask]`.
- **Per-job concurrency:** within a job, run up to `Settings.maxConcurrentFilesPerJob` file tasks at a time. Use a `TaskGroup` bounded by a `Semaphore`-like counter inside the actor.
- **Cross-job concurrency:** Coordinator runs up to `Settings.maxConcurrentJobs` jobs. Excess jobs are `.queued` until a slot opens.
- **Progress stream:** Engine emits `AsyncStream<DownloadEvent>` events: `.bytesReceived(fileID, delta, total)`, `.fileCompleted(fileID, url)`, `.fileFailed(fileID, error)`. Coordinator consumes the stream, updates Job state, posts to UI via `@Observable`.

## URL → resolved manifest pipeline

```swift
let url = "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct"
let kind = URLClassifier.classify(url)             // .huggingFace(org, repo, branch, subpath)
let resolver: SourceResolver = HuggingFaceResolver()
let manifest = try await resolver.resolve(kind)    // ResolvedManifest with [RemoteFile]
// User picks subset in UI → submitted as DownloadRequest
let job = await coordinator.enqueue(manifest, selecting: ids)
```

`ResolvedManifest` carries everything needed to download without a second API call:

```swift
struct ResolvedManifest {
    let title: String          // e.g. "meta-llama/Llama-3.1-8B-Instruct"
    let source: Source         // .huggingFace, .github, .generic
    let sourceURL: URL         // the original pasted URL
    let files: [RemoteFile]    // every downloadable file
}

struct RemoteFile: Identifiable {
    let id: UUID
    let name: String           // path/within/repo.safetensors
    let downloadURL: URL       // direct CDN URL
    let size: Int64?           // bytes; nil if unknown
    let group: FileGroup       // .weights, .config, .tokenizer, .docs, .other
    let extra: [String: String]  // sha256, lfs flag, etc.
}
```

## State updates → UI

`Job` is a SwiftData `@Model`. SwiftUI views use `@Query` to observe.

But progress updates fire many times per second per file — writing every tick to SwiftData is wasteful. So:

- **Slow-changing fields** (status, error, completedAt) → write directly to the SwiftData `@Model`.
- **Fast-changing fields** (bytesDownloaded, bytesPerSecond) → live in an `@Observable LiveProgressStore` keyed by `Job.id` and `FileItem.id`. Views read from both. On status transitions (paused, completed) the Coordinator flushes the live values to the model.

This keeps the SwiftData write rate to ~1 Hz max, while UI updates at the engine's natural rate.

## Reveal in Finder

```swift
NSWorkspace.shared.activateFileViewerSelecting([url])
```

Pass an array of file URLs — Finder selects them in their parent. For multi-file jobs, pass the parent folder URL alone for a cleaner selection.

## App lifecycle

- **`applicationDidFinishLaunching`** → spin up Coordinator, restore queue from SwiftData, resume any `.downloading` jobs from saved resume data.
- **`applicationShouldTerminate`** → ask Coordinator to suspend all in-flight tasks, write resume data, return `.terminateLater` until done (with a 5 s timeout).
- **Background URLSession** → if the app is killed mid-download, the OS keeps tasks alive and re-attaches on next launch via `URLSessionDelegate.urlSessionDidFinishEvents(forBackgroundURLSession:)`.

## Folder / file structure on disk

```
~/Downloads/osmDownloads/                     ← user-configurable root
  meta-llama_Llama-3.1-8B-Instruct/           ← per-job folder, name slugified
    config.json
    model-00001-of-00004.safetensors
    ...

~/Library/Application Support/osmDownloads/
  store.sqlite                                ← SwiftData
  resume/
    {fileItemID}.resumedata                   ← URLSession resume blobs
  logs/
    osmDownloads.log
```

## Testing strategy

- **Pure functions** (URLClassifier, byte formatters, EMA speed calc) → XCTest, no fixtures.
- **Resolvers** → record fixtures of HF/GH responses to `Tests/Fixtures/`, inject a `URLProtocol` mock that replays them.
- **DownloadEngine** → integration test against a local `swift-nio`-based HTTP server that supports range requests and can be commanded to fail mid-stream.
- **Coordinator** → unit test with a mock engine that emits scripted event sequences.
- **Views** → SwiftUI Previews only; no UI tests in V1.
