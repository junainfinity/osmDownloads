import AppKit
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @State private var hfToken: String = ""
    @State private var hfTokenLoaded: Bool = false
    @State private var savedFlash: Bool = false
    @State private var saveFlashTask: Task<Void, Never>?

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppearanceSection()
                    DownloadsSection()
                    huggingFaceSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            footer
        }
        .frame(width: 520, height: 560)
        .background(Theme.surface)
        .onAppear {
            if !hfTokenLoaded {
                hfToken = KeychainService.get(.huggingFace) ?? ""
                hfTokenLoaded = true
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Button { dismiss() } label: {
                Icon(icon: .stop, size: 12, color: Theme.text3)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Theme.surface2)
        .overlay(Divider().background(Theme.border), alignment: .top)
    }

    private var huggingFaceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Hugging Face")
            VStack(alignment: .leading, spacing: 8) {
                Text("Access token (for gated repos and higher rate limits)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text2)

                HStack(spacing: 8) {
                    SecureField("hf_…", text: $hfToken)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Button("Save") { saveToken() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(hfToken.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Clear") { clearToken() }
                        .buttonStyle(GhostButtonStyle(compact: true))
                        .disabled(hfToken.isEmpty)
                }

                HStack(spacing: 8) {
                    if savedFlash {
                        HStack(spacing: 5) {
                            Icon(icon: .checkOn, size: 11, color: Theme.success)
                            Text("Saved to Keychain")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.success)
                        }
                    }
                    Spacer()
                    Link("Get a token →",
                         destination: URL(string: "https://huggingface.co/settings/tokens")!)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.info)
                }

                Text("Tokens are stored in macOS Keychain — never on disk in plain text. Required for Pro / gated repos and recommended for everyone to avoid anonymous rate limits.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func saveToken() {
        let trimmed = hfToken.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        KeychainService.set(trimmed, account: .huggingFace)
        flashSaved()
    }

    private func clearToken() {
        KeychainService.delete(.huggingFace)
        hfToken = ""
        flashSaved()
    }

    private func flashSaved() {
        savedFlash = true
        saveFlashTask?.cancel()
        saveFlashTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { savedFlash = false }
        }
    }
}

// MARK: - Subviews (each pulls SettingsStore from the environment)

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.08 * 10.5)
            .foregroundStyle(Theme.text3)
    }
}

private struct AppearanceSection: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Appearance")
            HStack(spacing: 0) {
                ForEach(ThemePreference.allCases, id: \.self) { theme in
                    let active = settings.themePreference == theme
                    Button {
                        settings.themePreference = theme
                    } label: {
                        HStack(spacing: 7) {
                            themeIcon(for: theme, active: active)
                            Text(theme.label)
                                .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? Theme.text : Theme.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(active ? Theme.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(2)
            .background(Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func themeIcon(for theme: ThemePreference, active: Bool) -> some View {
        let color = active ? Theme.text : Theme.text3
        switch theme {
        case .system: Icon(icon: .settings, size: 12, color: color)
        case .light:  Icon(icon: .sun, size: 12, color: color)
        case .dark:   Icon(icon: .moon, size: 12, color: color)
        }
    }
}

private struct DownloadsSection: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Downloads")

            row(
                title: "Max simultaneous files per job",
                hint: "Files within a job download in parallel up to this limit. Lower = slower but kinder to your network."
            ) {
                Stepper(value: $settings.maxConcurrentFilesPerJob, in: 1...12) {
                    Text("\(settings.maxConcurrentFilesPerJob)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(width: 24, alignment: .trailing)
                }
                .labelsHidden()
            }

            row(
                title: "Max simultaneous jobs",
                hint: "How many separate downloads can run at once. Extra jobs wait in the Queue view."
            ) {
                Stepper(value: $settings.maxConcurrentJobs, in: 1...10) {
                    Text("\(settings.maxConcurrentJobs)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(width: 24, alignment: .trailing)
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Default destination folder")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                HStack(spacing: 8) {
                    Text(prettyPath(settings.destinationFolderPath))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Button("Choose…") { chooseDefaultFolder() }
                        .buttonStyle(GhostButtonStyle(compact: true))
                    Button("Reset") {
                        settings.destinationFolderPath = AppPaths.defaultDownloadsRoot.path
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                    .disabled(settings.destinationFolderPath == AppPaths.defaultDownloadsRoot.path)
                }
                Text("Files land in `<destination>/<slug-of-repo-name>/`.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text3)
            }
        }
    }

    private func row<Trailing: View>(
        title: String,
        hint: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                trailing()
            }
            Text(hint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func prettyPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseDefaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose default download destination"
        panel.prompt = "Choose"
        panel.directoryURL = settings.destinationFolderURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.destinationFolderPath = url.path
        }
    }
}
