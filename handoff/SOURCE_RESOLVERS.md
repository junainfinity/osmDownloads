# SOURCE_RESOLVERS — osmDownloads

A `SourceResolver` takes a classified URL and returns a `ResolvedManifest`. Three concrete implementations: Hugging Face, GitHub, Generic.

```swift
protocol SourceResolver {
    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest
}
```

## Hugging Face

### Endpoints

| Need | Endpoint | Notes |
|---|---|---|
| Repo file tree | `GET https://huggingface.co/api/{repoType}/{org}/{repo}/tree/{branch}` | `repoType` is `models`, `datasets`, or `spaces`. Recursive via `?recursive=true`. |
| Repo info (sibling list, often faster) | `GET https://huggingface.co/api/{repoType}/{org}/{repo}` | Returns `siblings: [{rfilename, size, lfs?: {sha256, size}}]` |
| File download | `https://huggingface.co/{org}/{repo}/resolve/{branch}/{path}` | Direct, follows redirects to LFS CDN |

For models, `repoType` is `models`. The `/api/models/...` endpoint is canonical.

### Auth

Add a bearer token for gated repos and rate-limit headroom:

```swift
var request = URLRequest(url: apiURL)
if let token = settings.huggingFaceToken {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

`401` means gated/private. `403` with body `{"error": "Access to model X is restricted..."}` means the user needs to accept the gating terms on the website first — don't try to bypass.

### Response shape (relevant fields only)

```json
{
  "id": "meta-llama/Llama-3.1-8B-Instruct",
  "siblings": [
    { "rfilename": "config.json" },
    { "rfilename": "model-00001-of-00004.safetensors" }
  ]
}
```

The `siblings` array doesn't include sizes — use the tree endpoint for that:

```json
[
  {
    "type": "file",
    "path": "model-00001-of-00004.safetensors",
    "size": 4976698672,
    "lfs": { "oid": "sha256:abc...", "size": 4976698672, "pointerSize": 134 }
  }
]
```

### Resolver implementation sketch

```swift
struct HuggingFaceResolver: SourceResolver {
    let session: URLSession
    let token: String?

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        guard case let .huggingFace(repoType, org, repo, branch, _) = kind else {
            throw ResolverError.wrongKind
        }
        let treeURL = URL(string:
            "https://huggingface.co/api/\(repoType.apiPath)/\(org)/\(repo)/tree/\(branch)?recursive=true")!

        var request = URLRequest(url: treeURL)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await session.data(for: request)
        try Self.checkResponse(response, data: data)

        let entries = try JSONDecoder().decode([HFTreeEntry].self, from: data)

        let files = entries
            .filter { $0.type == "file" }
            .map { entry -> RemoteFile in
                let rawURL = URL(string:
                    "https://huggingface.co/\(org)/\(repo)/resolve/\(branch)/\(entry.path)")!
                return RemoteFile(
                    name: entry.path,
                    downloadURL: rawURL,
                    size: entry.size,
                    sha256: entry.lfs?.oid.replacingOccurrences(of: "sha256:", with: ""),
                    isLFS: entry.lfs != nil
                )
            }

        return ResolvedManifest(
            title: "\(org)/\(repo)",
            source: .huggingFace,
            sourceURL: kind.originalURL,
            files: files
        )
    }
}

private struct HFTreeEntry: Decodable {
    let type: String          // "file" or "directory"
    let path: String
    let size: Int64?
    let lfs: HFLFS?
}
private struct HFLFS: Decodable {
    let oid: String           // "sha256:..."
    let size: Int64
}
```

### Pagination

`/tree/{branch}` paginates at 1000 entries by default. Check the `Link` response header:

```
Link: <https://huggingface.co/api/models/.../tree/main?recursive=true&cursor=eyJ...>; rel="next"
```

Loop until no `next`. Most repos fit in one page.

## GitHub

### Endpoints

| Need | Endpoint | Notes |
|---|---|---|
| Repo metadata | `GET https://api.github.com/repos/{owner}/{repo}` | Get `default_branch` if user pasted bare repo URL. |
| Tree (recursive) | `GET https://api.github.com/repos/{owner}/{repo}/git/trees/{sha}?recursive=1` | `{sha}` = branch name or commit SHA. |
| Single file content | `GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}` | Returns base64 for files under 1 MB; otherwise use raw URL. |
| Direct file download | `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` | No API — public repos only. Private repos use the contents endpoint with auth. |
| Releases | `GET https://api.github.com/repos/{owner}/{repo}/releases` | Optional V2. |

### Auth

Personal access token (classic or fine-grained) bumps rate limit from 60 to 5000/h:

```swift
request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
```

### Tree response

```json
{
  "sha": "abc...",
  "url": "...",
  "tree": [
    { "path": "README.md", "mode": "100644", "type": "blob", "sha": "...", "size": 1234, "url": "..." },
    { "path": "src", "mode": "040000", "type": "tree", "sha": "...", "url": "..." }
  ],
  "truncated": false
}
```

`truncated: true` means the tree exceeds 100,000 entries or 7 MB. Show the user "Repository too large — use `git clone` instead" rather than recursive-walking.

### LFS

GitHub-hosted LFS files appear in the tree with normal `size` but `raw.githubusercontent.com` returns a pointer file (`version https://git-lfs.github.com/spec/v1\noid sha256:...\nsize ...`).

Detect after first 200 bytes; if it matches the pointer format, redirect to `media.githubusercontent.com/media/{owner}/{repo}/{sha}?token=...`. The token comes from the LFS batch API:

```
POST https://github.com/{owner}/{repo}.git/info/lfs/objects/batch
Content-Type: application/vnd.git-lfs+json
Accept: application/vnd.git-lfs+json
Authorization: Bearer {token}
{
  "operation": "download",
  "transfers": ["basic"],
  "objects": [{ "oid": "abc...", "size": 1234 }]
}
```

For V1, **detect LFS pointers and warn the user** rather than implementing the LFS protocol — most users hitting LFS files in osmDownloads should use `git clone` instead.

## Generic / unsupported

For any URL not matching HF or GitHub, do a HEAD request to learn the filename and size:

```swift
struct GenericResolver: SourceResolver {
    let session: URLSession

    func resolve(_ kind: ClassifiedURL) async throws -> ResolvedManifest {
        guard case let .generic(url) = kind else { throw ResolverError.wrongKind }

        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: head)

        guard let http = response as? HTTPURLResponse else {
            throw ResolverError.invalidResponse
        }

        let filename = Self.filename(from: http, fallback: url.lastPathComponent)
        let size = http.expectedContentLength > 0 ? http.expectedContentLength : nil

        return ResolvedManifest(
            title: filename,
            source: .generic,
            sourceURL: url,
            files: [
                RemoteFile(name: filename, downloadURL: url, size: size)
            ]
        )
    }

    /// Prefer Content-Disposition filename, fall back to URL last path component.
    private static func filename(from response: HTTPURLResponse, fallback: String) -> String {
        if let disp = response.value(forHTTPHeaderField: "Content-Disposition"),
           let name = parseContentDispositionFilename(disp) {
            return name
        }
        return fallback.isEmpty ? "download" : fallback
    }
}
```

`parseContentDispositionFilename` should handle `filename=`, `filename*=UTF-8''...` (RFC 5987), and quoted variants. Use a small parser, not a regex.

If the HEAD request fails with `405 Method Not Allowed`, retry with a `GET` + `Range: bytes=0-0` to learn the size from `Content-Range` without downloading.

## Caching

Cache resolved manifests for **5 minutes** keyed by the original URL. A user pasting → backing out of the picker → re-pasting shouldn't double-hit the API.

```swift
actor ResolverCache {
    private var entries: [URL: (manifest: ResolvedManifest, expires: Date)] = [:]

    func get(_ url: URL) -> ResolvedManifest? {
        guard let entry = entries[url], entry.expires > .now else { return nil }
        return entry.manifest
    }
    func set(_ url: URL, _ manifest: ResolvedManifest, ttl: TimeInterval = 300) {
        entries[url] = (manifest, .now.addingTimeInterval(ttl))
    }
}
```
