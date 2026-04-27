# SPEC — osmDownloads

A macOS download manager that recognizes Hugging Face and GitHub URLs and gives you per-file control. Falls back gracefully to plain URL downloads.

## Primary user stories

1. **Paste a Hugging Face model URL** → app fetches the file tree, shows every file with size + group tag (weights / config / tokenizer), user picks subset, hits Download. App downloads each file with per-file progress + aggregate progress.
2. **Paste a GitHub repo URL** → same flow, fetches tree from GitHub API, downloads via raw URLs.
3. **Paste any other URL** → app treats it as a single file, downloads with progress.
4. **Pause and resume** any active job (and any individual file within it).
5. **See history** of finished/failed/canceled jobs. Reveal in Finder. Retry failed. Clear in bulk.
6. **Run multiple jobs concurrently** with a configurable max — anything over the cap waits in the Queue view.

## URL classification

Run in this order; first match wins. Implement in `URLClassifier.swift`.

### Hugging Face

```regex
^https?://huggingface\.co/([^/]+)/([^/]+?)(?:/tree/([^/]+)(?:/(.*))?)?/?$
```

- `org` = capture 1, `repo` = capture 2
- `branch` = capture 3, default `"main"`
- `subpath` = capture 4, default `""`
- Also accept `/blob/{branch}/{path}` and `/resolve/{branch}/{path}` for single files.
- Rejects: `/datasets/...` and `/spaces/...` go through the same pattern but `repoType` differs — `datasets` and `spaces` are valid HF resolver paths, treat them as a `repoType` enum on the request. Drop `/spaces/` for V1 (they are git repos but downloading the running app is rarely what users want — show "Spaces aren't supported yet" message).

### GitHub

```regex
^https?://github\.com/([^/]+)/([^/]+?)(?:/tree/([^/]+)(?:/(.*))?)?/?$
```

- Repo root → fetch full tree
- `/tree/{branch}/{path}` → fetch subtree at path
- `/blob/{branch}/{path}` → single file, download via `raw.githubusercontent.com/{org}/{repo}/{branch}/{path}`
- `/releases/download/...` → treat as single-file unsupported path

### Unsupported / generic

Anything else with a valid `URL(string:)` and `http`/`https` scheme. Show as "Unsupported source — single file download" with a HEAD probe to get filename + size before committing.

### Invalid

Empty, whitespace, non-URL strings, or non-http schemes. Show inline "Invalid URL" pill, disable Download button.

## Multi-file picker rules

Shown after a HF or GitHub URL resolves.

- **Default selection:** all files for HF (users typically want the whole model). For GitHub repos with > 50 files, default to none and surface a "Select all 1,247 files (84 MB)" hint.
- **Group tags:** infer from filename for HF — `*.safetensors`/`*.bin`/`*.gguf` → "weights", `tokenizer*` → "tokenizer", `*.json` → "config", `README*`/`*.md` → "docs". For GitHub: by top-level folder.
- **Sort:** group, then size desc, then name.
- **Search:** filter by substring, case-insensitive. Cmd+F focuses.
- **Live total:** sum of selected file sizes, formatted with `ByteCountFormatter` (`.file` style).

## Active downloads

- **Overall progress strip** at top: active count, aggregate speed (sum of in-flight per-file speeds, EMA-smoothed over 5 s), aggregate ETA (remaining bytes / aggregate speed), aggregate bar (sum done / sum total across active jobs).
- **Per-job card:** source icon (HF / GitHub / globe), title, file ratio (e.g. "9/12 files"), bytes done / total, current speed, ETA, status pill, action row (pause/resume, stop, ⋯ menu, expand).
- **Expand** to reveal per-file rows: 16-px progress bar, filename (truncated middle), bytes done / total, status icon. The prototype shows this — match the layout exactly.
- **⋯ menu:** Reveal in Finder, Copy source URL, Stop & remove (destructive).
- **Bulk:** Pause all, Resume all, Clear all (only stops & removes; doesn't touch files on disk).

## History

- Shows completed, failed, canceled jobs. Persists across launches.
- Segmented filter: All / Completed / Failed.
- Per-row: same source icon, title, finished-at timestamp (relative — "2 h ago"), final size, final status pill.
- Per-row actions: Reveal in Finder (disabled if files were deleted from disk — check existence on hover), Retry (failed only), Delete row.
- Bulk: Clear completed, Clear failed, Clear all.
- Search by title / URL.

## Settings (sheet, ⌘,)

| Section | Setting | Default |
|---|---|---|
| General | Default destination | `~/Downloads/osmDownloads` |
| General | Max concurrent jobs | 3 |
| General | Max concurrent files per job | 4 |
| General | Theme | System |
| Network | Connection timeout | 30 s |
| Network | Retry attempts on failure | 3 |
| Network | Retry backoff | exponential, 2 s base |
| Auth | Hugging Face token | (empty) — for gated repos |
| Auth | GitHub token | (empty) — for higher rate limits |
| Storage | Resume incomplete on launch | on |
| Storage | Auto-clear history older than | Never / 30 d / 90 d |

## Edge cases — explicit list

- **HF gated repo without token:** API returns 401. Show "This model is gated — add your Hugging Face token in Settings" with a link.
- **GitHub rate limit:** 60 req/h unauthenticated. Detect via `X-RateLimit-Remaining: 0`, show "GitHub rate limit hit — add a token in Settings".
- **Disk full:** abort job, mark failed with reason. Don't delete partial file (user might free space and retry).
- **Network drops mid-download:** retry with resume data up to N times, then mark paused with "Network unavailable" subtitle. Auto-resume when reachability returns.
- **Server doesn't support range requests:** detect via Accept-Ranges header on first response. If absent, pause becomes "stop & restart from 0" — warn the user before they pause.
- **File already exists at destination:** prompt: Overwrite / Rename / Skip. Remember choice for the rest of the job ("Apply to all").
- **App quit with downloads in flight:** snapshot resume data to disk, restore on launch (see PERSISTENCE.md).
- **HF repo with very large file (> 50 GB):** still proceed but warn on resolve.
- **URL with anchor / query:** strip for classification, preserve for raw download.
- **Symlinks in HF / GitHub trees:** follow once, error if circular.
- **LFS pointer files in GitHub trees:** detect via Git LFS pointer text format. Resolve to actual blob via `media.githubusercontent.com` if the repo has LFS enabled, otherwise download the pointer text and warn.

## Non-goals (V1)

- BitTorrent / magnet links
- Browser integration / right-click "Download with osmDownloads"
- Bandwidth throttling
- Scheduled downloads
- iCloud sync of history across devices
