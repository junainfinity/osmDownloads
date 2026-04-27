import AppKit
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    // Draft state — changes are uncommitted until Save.
    @State private var theme: ThemePreference = .system
    @State private var maxFilesPerJob: Int = 4
    @State private var maxJobs: Int = 3
    @State private var maxMbpsString: String = ""
    @State private var destinationPath: String = ""
    @State private var hfToken: String = ""

    @State private var loaded: Bool = false
    @State private var saveButtonState: SaveButtonState = .save

    enum SaveButtonState { case save, done }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearanceSection
                    downloadsSection
                    huggingFaceSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            footer
        }
        .frame(width: 540, height: 620)
        .background(Theme.surface)
        .onAppear { if !loaded { loadFromStore() } }
        .onChange(of: theme)             { saveButtonState = .save }
        .onChange(of: maxFilesPerJob)    { saveButtonState = .save }
        .onChange(of: maxJobs)           { saveButtonState = .save }
        .onChange(of: maxMbpsString)     { saveButtonState = .save }
        .onChange(of: destinationPath)   { saveButtonState = .save }
        .onChange(of: hfToken)           { saveButtonState = .save }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .overlay(Divider().background(Theme.border), alignment: .bottom)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", action: cancel)
                .buttonStyle(GhostButtonStyle())
                .keyboardShortcut(.cancelAction)

            Button(action: saveOrDismiss) {
                HStack(spacing: 6) {
                    if saveButtonState == .done {
                        Icon(icon: .checkOn, size: 11, color: Theme.accentInk)
                    }
                    Text(saveButtonState == .save ? "Save" : "Done")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Theme.surface2)
        .overlay(Divider().background(Theme.border), alignment: .top)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Appearance")
            HStack(spacing: 0) {
                ForEach(ThemePreference.allCases, id: \.self) { option in
                    let active = theme == option
                    Button { theme = option } label: {
                        HStack(spacing: 7) {
                            themeIcon(for: option, active: active)
                            Text(option.label)
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
    private func themeIcon(for option: ThemePreference, active: Bool) -> some View {
        let color = active ? Theme.text : Theme.text3
        switch option {
        case .system: Icon(icon: .settings, size: 12, color: color)
        case .light:  Icon(icon: .sun, size: 12, color: color)
        case .dark:   Icon(icon: .moon, size: 12, color: color)
        }
    }

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Downloads")

            stepperRow(
                title: "Max simultaneous files per job",
                hint: "Files within a job download in parallel up to this limit. Lower = slower but kinder to your network.",
                value: $maxFilesPerJob,
                range: 1...12
            )

            stepperRow(
                title: "Max simultaneous jobs",
                hint: "How many separate downloads can run at once. Extra jobs wait in the Queue view.",
                value: $maxJobs,
                range: 1...10
            )

            mbpsRow

            destinationRow
        }
    }

    private func stepperRow(
        title: String,
        hint: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                Text("\(value.wrappedValue)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .frame(minWidth: 28, alignment: .trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
            Text(hint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mbpsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text("Max download speed")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                TextField("Unlimited", text: $maxMbpsString)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .frame(width: 70)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text("Mbps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .frame(width: 36, alignment: .leading)
            }
            Text("Best-effort cap. Leave blank for unlimited. Values like 50 or 100 work; URLSession buffers a bit, so the sustained rate may briefly burst above the cap.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var destinationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Default destination folder")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                Text(prettyPath(destinationPath))
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
                    destinationPath = AppPaths.defaultDownloadsRoot.path
                }
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(destinationPath == AppPaths.defaultDownloadsRoot.path)
            }
            Text("Files land in `<destination>/<slug-of-repo-name>/`.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
        }
    }

    private var huggingFaceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hugging Face")
            VStack(alignment: .leading, spacing: 8) {
                Text("Access token (for gated repos and higher rate limits)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text2)

                SecureField("hf_…", text: $hfToken)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                HStack(spacing: 8) {
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

    // MARK: - Helpers

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.08 * 10.5)
            .foregroundStyle(Theme.text3)
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
        panel.directoryURL = URL(fileURLWithPath: destinationPath, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }

    // MARK: - Load / save

    private func loadFromStore() {
        theme            = settings.themePreference
        maxFilesPerJob   = settings.maxConcurrentFilesPerJob
        maxJobs          = settings.maxConcurrentJobs
        maxMbpsString    = settings.maxDownloadMbps > 0 ? Self.formatMbps(settings.maxDownloadMbps) : ""
        destinationPath  = settings.destinationFolderPath
        hfToken          = KeychainService.get(.huggingFace) ?? ""
        loaded           = true
        saveButtonState  = .save
    }

    private func cancel() {
        dismiss()
    }

    private func saveOrDismiss() {
        switch saveButtonState {
        case .save:
            applyDraft()
            saveButtonState = .done
        case .done:
            dismiss()
        }
    }

    private func applyDraft() {
        settings.themePreference          = theme
        settings.maxConcurrentFilesPerJob = maxFilesPerJob
        settings.maxConcurrentJobs        = maxJobs
        settings.maxDownloadMbps          = Self.parseMbps(maxMbpsString)
        settings.destinationFolderPath    = destinationPath

        let trimmedToken = hfToken.trimmingCharacters(in: .whitespaces)
        if trimmedToken.isEmpty {
            KeychainService.delete(.huggingFace)
        } else {
            KeychainService.set(trimmedToken, account: .huggingFace)
        }
    }

    private static func parseMbps(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(trimmed), v > 0 else { return 0 }
        return v
    }

    private static func formatMbps(_ d: Double) -> String {
        if d == d.rounded() { return "\(Int(d))" }
        return String(format: "%.1f", d)
    }
}
