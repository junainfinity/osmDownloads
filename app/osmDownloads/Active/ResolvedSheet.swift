import SwiftUI

struct ResolvedSheet: View {
    let manifest: ResolvedManifest
    @Binding var selected: Set<UUID>
    let destinationRoot: URL
    let onChooseDestination: () -> Void
    let onStart: () -> Void
    let onSelectAll: () -> Void
    let onSelectNone: () -> Void

    @State private var search: String = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Divider().background(Theme.border)
            destinationBar
            Divider().background(Theme.border)
            if manifest.files.count > 6 {
                searchBar
                Divider().background(Theme.border)
            }
            filesList
            Divider().background(Theme.border)
            footer
        }
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Icon(icon: .search, size: 12, color: Theme.text3)
            TextField("Filter files", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text)
                .focused($searchFocused)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Icon(icon: .stop, size: 11, color: Theme.text3)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var sortedFiles: [RemoteFile] {
        manifest.files.sorted { a, b in
            if a.group != b.group { return a.group.sortOrder < b.group.sortOrder }
            let sa = a.size ?? 0, sb = b.size ?? 0
            if sa != sb { return sa > sb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private var visibleFiles: [RemoteFile] {
        let all = sortedFiles
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) }
    }

    private var head: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(manifest.source == .huggingFace ? Theme.accentSoft : Theme.surface3)
                SourceIcon(source: manifest.source, size: 22)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(manifest.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Select all", action: onSelectAll)
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(manifest.files.isEmpty)
            Button("None", action: onSelectNone)
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(selected.isEmpty)
        }
        .padding(12)
    }

    private var subtitle: String {
        let files = manifest.files.count
        let totalBytes: Int64 = manifest.files.reduce(0) { $0 + ($1.size ?? 0) }
        let kindLabel: String
        switch manifest.source {
        case .huggingFace: kindLabel = "huggingface.co"
        case .github:      kindLabel = "github.com"
        case .generic:     kindLabel = manifest.sourceURL.host ?? "Direct URL"
        }
        if totalBytes > 0 {
            return "\(kindLabel) · \(files) file\(files == 1 ? "" : "s") · \(Fmt.bytes(totalBytes))"
        }
        return "\(kindLabel) · \(files) file\(files == 1 ? "" : "s")"
    }

    private var filesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let files = visibleFiles
                if files.isEmpty {
                    Text("No files match \"\(search)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 22)
                } else {
                    ForEach(files) { file in
                        fileRow(file)
                        if file.id != files.last?.id {
                            Divider().background(Theme.border).padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 280)
        .frame(height: fileListHeight)
    }

    private func fileRow(_ file: RemoteFile) -> some View {
        let isSelected = selected.contains(file.id)
        return Button {
            if isSelected { selected.remove(file.id) } else { selected.insert(file.id) }
        } label: {
            HStack(spacing: 10) {
                Icon(icon: isSelected ? .checkOn : .checkOff,
                     size: 14,
                     color: isSelected ? Theme.accentInk : Theme.text3)
                Text(file.name)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 6)
                if let size = file.size {
                    Text(Fmt.bytes(size))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.text3)
                }
                Text(groupLabel(file.group))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.surface2)
                    .clipShape(Capsule())
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func groupLabel(_ g: FileGroup) -> String {
        switch g {
        case .weights:   return "weights"
        case .config:    return "config"
        case .tokenizer: return "tokenizer"
        case .docs:      return "docs"
        case .code:      return "code"
        case .asset:     return "asset"
        case .other:     return ""
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)

            Spacer(minLength: 0)
            Button("Start download", action: onStart)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty)
        }
        .frame(minHeight: 34)
        .padding(12)
    }

    private var destinationBar: some View {
        Button(action: onChooseDestination) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.surface)
                    Icon(icon: .folder, size: 13, color: Theme.text2)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Download to")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.text3)
                    Text(destPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text("Choose folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(10)
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(12)
        .help("Choose a different folder for this download")
    }

    private var summary: String {
        let count = selected.count
        let totalSelected: Int64 = manifest.files
            .filter { selected.contains($0.id) }
            .reduce(0) { $0 + ($1.size ?? 0) }
        let totalLabel = totalSelected > 0 ? " · \(Fmt.bytes(totalSelected))" : ""
        return "\(count) of \(manifest.files.count) selected\(totalLabel)"
    }

    private var destPath: String {
        let folder = FileSystemService.slugify(manifest.title)
        let full = destinationRoot.appendingPathComponent(folder).path
        // Pretty-print: collapse $HOME to ~
        let home = NSHomeDirectory()
        if full.hasPrefix(home) {
            return "~" + full.dropFirst(home.count)
        }
        return full
    }

    private var fileListHeight: CGFloat {
        let visibleRows = min(max(manifest.files.count, 1), 7)
        return CGFloat(visibleRows) * 36
    }
}
