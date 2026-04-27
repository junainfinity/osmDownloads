# UI_MAPPING — Prototype → SwiftUI

The prototype (`../osmDownloads.html`) is the visual contract. This file maps each prototype region to the SwiftUI view that owns it. Build views in this order; each unlocks a milestone.

## View hierarchy

```
AppShell                                       (NavigationSplitView)
├── Sidebar                                    (sidebar column)
│   ├── BrandHeader                            (logo + wordmark)
│   ├── NavList                                (Active / History / Queue)
│   ├── SourceBreakdown                        (HF / GitHub / Other counts)
│   └── DiskMeter                              (footer)
└── MainPane                                   (detail column)
    ├── Titlebar                               (toolbar)
    │   ├── ViewTitle
    │   ├── ThemeToggle
    │   └── SettingsButton
    └── ContentRouter                          (switches on selected view)
        ├── ActiveView
        │   ├── NewDownloadBar
        │   │   └── ResolvedSheet              (shown when manifest resolves)
        │   ├── OverallProgressStrip
        │   ├── ListToolbar                    (Pause all / Resume all / Clear all)
        │   └── ScrollView
        │       └── ForEach: JobCard
        │           ├── JobHeaderRow
        │           ├── ProgressBarRow
        │           └── FileList                (when expanded)
        │               └── ForEach: FileRow
        ├── HistoryView
        │   ├── HistoryToolbar                  (segmented filter + bulk clear)
        │   ├── SearchField
        │   └── ScrollView
        │       └── ForEach: HistoryRow
        ├── QueueView
        └── SettingsSheet
```

## File-by-file inventory

| File | Type | Owns | Reads from |
|---|---|---|---|
| `App/osmDownloadsApp.swift` | App entry | ModelContainer setup | — |
| `App/AppShell.swift` | Root view | NavigationSplitView | AppViewModel |
| `App/AppViewModel.swift` | @Observable | view selection, theme, search | SettingsStore |
| `Sidebar/Sidebar.swift` | View | sidebar column | JobsViewModel |
| `Sidebar/BrandHeader.swift` | View | logo + name | — |
| `Sidebar/SourceBreakdown.swift` | View | HF/GH/Other counts | JobsViewModel |
| `Sidebar/DiskMeter.swift` | View | free/used disk space | FileSystemService |
| `Active/ActiveView.swift` | View | active+queued jobs list | JobsViewModel, LiveProgressStore |
| `Active/NewDownloadBar.swift` | View | URL input + classify pill | ResolveViewModel |
| `Active/ResolvedSheet.swift` | View | file picker | ResolveViewModel |
| `Active/OverallProgressStrip.swift` | View | aggregate stats | LiveProgressStore |
| `Active/JobCard.swift` | View | one job, collapsed/expanded | Job, LiveProgressStore |
| `Active/FileRow.swift` | View | one file's progress | FileItem, LiveProgressStore |
| `History/HistoryView.swift` | View | finished jobs list | JobsViewModel |
| `History/HistoryRow.swift` | View | one history row | Job |
| `Queue/QueueView.swift` | View | queued-only list | JobsViewModel |
| `Settings/SettingsSheet.swift` | View | settings form | SettingsStore |
| `Common/StatusPill.swift` | View | colored status badge | — |
| `Common/ProgressBar.swift` | View | thin bar w/ accent fill | — |
| `Common/IconView.swift` | View | SF Symbols wrapper | — |
| `Services/URLClassifier.swift` | enum + fn | classify URL → kind | — |
| `Services/SourceResolver.swift` | protocol | — | — |
| `Services/HuggingFaceResolver.swift` | struct | HF API calls | URLSession |
| `Services/GitHubResolver.swift` | struct | GH API calls | URLSession |
| `Services/GenericResolver.swift` | struct | HEAD probe | URLSession |
| `Services/DownloadCoordinator.swift` | actor | job lifecycle | DownloadEngine, SwiftData |
| `Services/DownloadEngine.swift` | actor | URLSessionDownloadTask | URLSession |
| `Services/FileSystemService.swift` | enum | reveal, exists, free space | NSWorkspace, FileManager |
| `Services/SettingsStore.swift` | @Observable | wraps @AppStorage | UserDefaults |
| `Services/KeychainService.swift` | enum | tokens | Security framework |
| `Services/ReachabilityService.swift` | actor | network up/down | NWPathMonitor |

## Mapping prototype design tokens to SwiftUI

The prototype's CSS variables map directly to a `Theme` struct + `Color(red:green:blue:)` calls. Drop the asset-catalog approach; we want the same palette across all surfaces.

```swift
enum Theme {
    static let bg          = Color("BG")           // light: #FAF8F4 / dark: #0F0E0C
    static let surface     = Color("Surface")      // #FFFFFF / #1A1815
    static let surface2    = Color("Surface2")
    static let surface3    = Color("Surface3")
    static let border      = Color("Border")
    static let borderStrong = Color("BorderStrong")
    static let text        = Color("Text")
    static let text2       = Color("Text2")
    static let text3       = Color("Text3")
    static let accent      = Color(red: 1.0, green: 0.867, blue: 0.333)   // #FFDD55
    static let accentInk   = Color("AccentInk")
    static let success     = Color("Success")
    static let danger      = Color("Danger")
}
```

Add each color to `Assets.xcassets` as a Color Set with `Any Appearance` and `Dark Appearance` variants — values are already in the prototype's `styles.css`.

## Copy strings

Lift these verbatim from the prototype — designer-approved:

- URL bar placeholder: `"Paste a Hugging Face, GitHub, or any download URL"`
- Empty active state: `"No active downloads"` / `"Paste a URL above to get started"`
- Empty history: `"Nothing here yet"` / `"Completed and failed downloads will appear here"`
- Pause all / Resume all / Clear all
- Reveal in Finder / Copy source URL / Stop and remove
- Clear all / Clear completed / Clear failed
- Status pill labels: `"Downloading"`, `"Queued"`, `"Paused"`, `"Completed"`, `"Failed"`
- Unsupported banner: `"Unsupported source"` / `"We'll download this URL as a single file. We won't be able to detect or split additional files in the response."`

## SF Symbols equivalents

| Prototype icon | SF Symbol |
|---|---|
| download arrow | `arrow.down.to.line` |
| pause | `pause.fill` |
| resume / play | `play.fill` |
| stop / X | `xmark` |
| more / kebab | `ellipsis` |
| reveal | `folder` (or `arrow.up.forward.app` for "show in Finder") |
| HF source | custom asset (HF logo) |
| GitHub source | `chevron.left.slash.chevron.right` (or custom GH glyph) |
| globe / generic | `globe` |
| clock / history | `clock` |
| inbox / queue | `tray` |
| settings | `gearshape` |
| theme light | `sun.max` |
| theme dark | `moon` |
| search | `magnifyingglass` |
| check (selected file) | `checkmark.square.fill` (selected) / `square` (unselected) |

Bundle the Hugging Face glyph as a vector PDF in the asset catalog. The yellow nucleus + warm strokes from the osmDownloads logo can be rendered as an SVG-derived PDF too — give Designer the PDF export request.

## Animations

Match the prototype's motion:

| Element | Prototype | SwiftUI |
|---|---|---|
| Resolved sheet enter | 250 ms ease-out, slide+fade | `.transition(.move(edge: .top).combined(with: .opacity))` with `.animation(.easeOut(duration: 0.25))` |
| Status pill pulse | 1.4 s loop on `.downloading` | `.opacity()` + `.animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true))` |
| Progress bar fill | smooth, no overshoot | `.animation(.linear(duration: 0.3), value: progress)` |
| Job card expand | slide down | `.transition(.asymmetric(insertion: .push(from: .top), removal: .opacity))` |
| Toast | bottom-center, 2 s, dismiss on tap | overlay + `.task { try? await Task.sleep(for: .seconds(2)); dismiss() }` |

Set the global motion timing via a constant — easy to tune once.

## Density

The prototype's `density` tweak (compact / comfortable) maps to row padding:

```swift
enum Density: String, CaseIterable {
    case compact, comfortable
    var rowPaddingV: CGFloat { self == .compact ? 6 : 10 }
    var cardPaddingV: CGFloat { self == .compact ? 8 : 12 }
}
```

Read from `SettingsStore.density`, apply via `.padding(.vertical, density.rowPaddingV)`.

## Accessibility

- Every interactive element gets `.accessibilityLabel` matching its visible label OR — for icon-only buttons — a descriptive label (`"Pause download"`).
- Status pills get `.accessibilityValue` = the status text.
- Progress bars use the native `ProgressView(value:total:)` so VoiceOver announces percentages.
- Cmd+L focuses the URL bar; Cmd+F focuses search; Esc dismisses sheets — wire via `.keyboardShortcut`.
- Honor `Reduce Motion` — disable the status pulse and toast slide.
