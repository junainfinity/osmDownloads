# osmDownloads — Native Swift Handoff

This folder is the engineering package for porting the **osmDownloads** prototype to a native macOS app. Open the prototype (`../osmDownloads.html`) alongside these docs as the visual source of truth.

## Read in this order

1. **[README.md](./README.md)** — index, target platform, milestones, project setup
2. **[SPEC.md](./SPEC.md)** — product spec, URL classification rules, edge cases, settings
3. **[ARCHITECTURE.md](./ARCHITECTURE.md)** — layers, modules, concurrency model, lifecycle
4. **[Models.swift](./Models.swift)** — drop-in Swift types: `Job`, `FileItem`, statuses, events
5. **[DOWNLOAD_ENGINE.md](./DOWNLOAD_ENGINE.md)** — URLSession, ranges, pause/resume, retries
6. **[SOURCE_RESOLVERS.md](./SOURCE_RESOLVERS.md)** — Hugging Face & GitHub API endpoints + parsers
7. **[PERSISTENCE.md](./PERSISTENCE.md)** — SwiftData schema, on-disk layout, resume across launches
8. **[UI_MAPPING.md](./UI_MAPPING.md)** — prototype → SwiftUI view inventory, design tokens, copy

## At a glance

- **Stack:** Swift 5.9+, SwiftUI, SwiftData, async/await
- **Min OS:** macOS 14 (Sonoma)
- **Networking:** background `URLSession` (survives relaunch)
- **Persistence:** SwiftData for jobs/files, separate disk store for resume blobs
- **Distribution:** direct download + Sparkle (not MAS — needs unrestricted FS)

## Milestones

| # | Scope | Unblocks |
|---|---|---|
| M1 | Single-file (generic) downloads with progress | end-to-end engine |
| M2 | Hugging Face resolver + multi-file picker | flagship use case |
| M3 | GitHub resolver | parity |
| M4 | Pause/resume + concurrency caps | reliability |
| M5 | History + persistence | full app |
| M6 | Settings, tokens, theme | shippable v1.0 |
| M7 | Polish: dock badge, notifications, drag-drop | post-launch |
