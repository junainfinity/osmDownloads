import SwiftUI

struct NewDownloadBar: View {
    @Bindable var resolveVM: ResolveViewModel
    @Environment(JobsViewModel.self) private var jobs
    @Environment(SettingsStore.self) private var settings
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sourcePill
                ZStack(alignment: .leading) {
                    if resolveVM.urlString.isEmpty {
                        Text("Paste a Hugging Face, GitHub, or any download URL")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text3)
                    }
                    TextField("", text: $resolveVM.urlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .focused($urlFocused)
                        .onSubmit { startIfReady() }
                }
                if case .resolving = resolveVM.state {
                    ProgressView().controlSize(.small)
                } else if case .classifying = resolveVM.state {
                    ProgressView().controlSize(.small)
                }

                if resolveVM.urlString.isEmpty {
                    Text("⌘V")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.surface3)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button("Download") {
                    startIfReady()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!resolveVM.canDownload)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(urlFocused ? Theme.borderStrong : Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

            if let manifest = resolveVM.resolvedManifest {
                ResolvedSheet(
                    manifest: manifest,
                    selected: $resolveVM.selectedFileIDs,
                    destinationRoot: effectiveDestination,
                    onChooseDestination: {
                        resolveVM.chooseDestination(suggesting: settings.destinationFolderURL)
                    },
                    onStart: { startIfReady() },
                    onSelectAll: { resolveVM.selectAll() },
                    onSelectNone: { resolveVM.selectNone() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if case .error(let reason) = resolveVM.state {
                HStack(spacing: 8) {
                    Icon(icon: .warn, size: 13, color: Theme.danger)
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.danger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))
            }
        }
        .animation(.easeOut(duration: Theme.popIn), value: resolveVM.resolvedManifest?.title)
    }

    @ViewBuilder
    private var sourcePill: some View {
        if let kind = resolveVM.classifiedKind {
            switch kind {
            case .huggingFace, .huggingFaceFile:
                pill(label: "Hugging Face", source: .huggingFace)
            case .github, .githubFile:
                pill(label: "GitHub", source: .github)
            case .generic:
                pill(label: "Direct URL", source: .generic)
            case .invalid:
                EmptyView()
            }
        } else if case .ready(let m) = resolveVM.state {
            pill(label: sourceName(m.source), source: m.source)
        }
    }

    private func pill(label: String, source: Source) -> some View {
        HStack(spacing: 5) {
            SourceIcon(source: source, size: 12)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source == .huggingFace ? Theme.accentSoft : Theme.surface3)
        .clipShape(Capsule())
    }

    private func sourceName(_ s: Source) -> String {
        switch s {
        case .huggingFace: return "Hugging Face"
        case .github:      return "GitHub"
        case .generic:     return "Direct URL"
        }
    }

    private var effectiveDestination: URL {
        resolveVM.destinationOverride ?? settings.destinationFolderURL
    }

    private func startIfReady() {
        guard let manifest = resolveVM.resolvedManifest, !resolveVM.selectedFileIDs.isEmpty else { return }
        jobs.enqueue(
            manifest: manifest,
            selectedFileIDs: resolveVM.selectedFileIDs,
            destination: effectiveDestination
        )
        resolveVM.reset()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.accent)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13))
            .foregroundStyle(Theme.text2)
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 4 : 6)
            .background(configuration.isPressed ? Theme.surface3 : Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous))
    }
}

/// Icon-only button with proper press feedback (background fill + scale).
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 30
    var radius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(configuration.isPressed ? Theme.surface3 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
