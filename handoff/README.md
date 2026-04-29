# osmDownloads — Native Swift Handoff

> Engineering handoff package for the osmDownloads native macOS app.
> The visual prototype lives at `../osmDownloads.html` — open it as the source of truth for layout, motion, and copy.

## What's in this package

| File | Purpose |
|---|---|
| `SPEC.md` | Product spec: features, user stories, URL classification, edge cases |
| `ARCHITECTURE.md` | App layers, module boundaries, data flow |
| `Models.swift` | Concrete Swift types — `Job`, `FileItem`, `Status`, `Source` |
| `DOWNLOAD_ENGINE.md` | URLSession setup, range requests, pause/resume, concurrency limits |
| `SOURCE_RESOLVERS.md` | Hugging Face + GitHub API endpoints, response shapes, parsers |
| `PERSISTENCE.md` | SwiftData schema, on-disk layout, in-flight resume across launches |
| `UI_MAPPING.md` | Prototype → SwiftUI view inventory with file references |

## Target

- **Platform:** macOS 14+ (Sonoma) — uses SwiftData, async URLSession, SwiftUI shell
- **Language:** Swift 5.9+, SwiftUI
- **Distribution:** Direct download + Sparkle for updates (not Mac App Store — needs unrestricted disk write + reveal-in-Finder)
- **Sandbox:** Off (or with user-selected destination folder bookmark)

## Recommended milestones

1. **M1 — Single-file downloads.** Shipped.
2. **M2 — Hugging Face resolver.** Shipped.
3. **M3 — GitHub resolver.** Shipped.
4. **M4 — Pause/resume + concurrency.** Shipped.
5. **M5 — History & persistence.** Shipped.
6. **M6 — Settings + auth.** Shipped.
7. **M7 — Polish.** Shipped.

## Local setup

```sh
# Create project
mkdir osmDownloads && cd osmDownloads
# Open Xcode → New Project → macOS → App → SwiftUI → SwiftData
# Bundle ID: app.osm.downloads
# Then drop in Models.swift and follow ARCHITECTURE.md
```

## Visual reference

Open `../osmDownloads.html` in the prototype runner. Toggle the **Tweaks** panel for accent color, density, and theme variants the user has approved. Logos are in `../assets/logo-light.png` and `../assets/logo-dark.png` — drop both into `Assets.xcassets` as a single image set with light/dark variants.
