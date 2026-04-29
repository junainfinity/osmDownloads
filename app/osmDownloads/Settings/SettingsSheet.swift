import AppKit
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    // Draft state — changes are uncommitted until Save.
    @State private var theme: ThemePreference = .system
    @State private var maxFilesPerJob: Int = 4
    @State private var maxJobs: Int = 3
    @State private var retryCount: Int = 3
    @State private var retryBackoff: Double = 2
    @State private var connectionTimeout: Double = 30
    @State private var maxMbpsString: String = ""
    @State private var destinationPath: String = ""
    @State private var autoClearHistoryDays: Int = 0
    @State private var resumeIncompleteOnLaunch: Bool = true
    @State private var hfToken: String = ""
    @State private var githubToken: String = ""

    @State private var loaded: Bool = false
    @State private var saveButtonState: SaveButtonState = .save
    @State private var selectedTab: SettingsTab = .preferences

    enum SaveButtonState { case save, done }
    enum SettingsTab: Hashable { case preferences, about }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
            }
            footer
        }
        .frame(width: 540, height: 620)
        .background(Theme.surface)
        .onAppear { if !loaded { loadFromStore() } }
        .onChange(of: theme)             { saveButtonState = .save }
        .onChange(of: maxFilesPerJob)    { saveButtonState = .save }
        .onChange(of: maxJobs)           { saveButtonState = .save }
        .onChange(of: retryCount)        { saveButtonState = .save }
        .onChange(of: retryBackoff)      { saveButtonState = .save }
        .onChange(of: connectionTimeout) { saveButtonState = .save }
        .onChange(of: maxMbpsString)     { saveButtonState = .save }
        .onChange(of: destinationPath)   { saveButtonState = .save }
        .onChange(of: autoClearHistoryDays) { saveButtonState = .save }
        .onChange(of: resumeIncompleteOnLaunch) { saveButtonState = .save }
        .onChange(of: hfToken)           { saveButtonState = .save }
        .onChange(of: githubToken)       { saveButtonState = .save }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 14) {
            Text(selectedTab == .preferences ? "Settings" : "About")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Picker("", selection: $selectedTab) {
                Text("Preferences").tag(SettingsTab.preferences)
                Text("About").tag(SettingsTab.about)
            }
            .pickerStyle(.segmented)
            .frame(width: 214)
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

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .preferences:
            VStack(alignment: .leading, spacing: 22) {
                appearanceSection
                downloadsSection
                networkSection
                authSection
                storageSection
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        case .about:
            SettingsAboutView()
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
        }
    }

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

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Network")

            stepperRow(
                title: "Retry attempts",
                hint: "Transient network and server failures retry with exponential backoff before the job is marked failed.",
                value: $retryCount,
                range: 0...8
            )

            HStack(spacing: 10) {
                Text("Retry backoff")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                Stepper("\(Self.formatSeconds(retryBackoff))", value: $retryBackoff, in: 1...30, step: 1)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text2)
            }

            HStack(spacing: 10) {
                Text("Connection timeout")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                Stepper("\(Self.formatSeconds(connectionTimeout))", value: $connectionTimeout, in: 10...120, step: 5)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text2)
            }
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

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Auth")
            tokenRow(
                title: "Hugging Face token",
                placeholder: "hf_...",
                text: $hfToken,
                linkTitle: "Get Hugging Face token",
                link: URL(string: "https://huggingface.co/settings/tokens")!
            )
            tokenRow(
                title: "GitHub token",
                placeholder: "github_pat_...",
                text: $githubToken,
                linkTitle: "Create GitHub token",
                link: URL(string: "https://github.com/settings/tokens")!
            )
            Text("Tokens are stored in macOS Keychain and used only for gated/private repos and higher API limits.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tokenRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        linkTitle: String,
        link: URL
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text2)
                Spacer()
                Link(linkTitle, destination: link)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.info)
            }
            SecureField(placeholder, text: text)
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
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Storage")
            Toggle("Resume incomplete downloads on launch", isOn: $resumeIncompleteOnLaunch)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)

            Picker("Auto-clear history older than", selection: $autoClearHistoryDays) {
                Text("Never").tag(0)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.text)

            Text("Auto-clear removes history rows only; downloaded files are never deleted.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
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
        retryCount       = settings.retryCount
        retryBackoff     = settings.retryBackoffSeconds
        connectionTimeout = settings.connectionTimeoutSeconds
        maxMbpsString    = settings.maxDownloadMbps > 0 ? Self.formatMbps(settings.maxDownloadMbps) : ""
        destinationPath  = settings.destinationFolderPath
        autoClearHistoryDays = settings.autoClearHistoryDays
        resumeIncompleteOnLaunch = settings.resumeIncompleteOnLaunch
        hfToken          = KeychainService.get(.huggingFace) ?? ""
        githubToken      = KeychainService.get(.github) ?? ""
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
        settings.retryCount               = retryCount
        settings.retryBackoffSeconds      = retryBackoff
        settings.connectionTimeoutSeconds = connectionTimeout
        settings.maxDownloadMbps          = Self.parseMbps(maxMbpsString)
        settings.destinationFolderPath    = destinationPath
        settings.autoClearHistoryDays     = autoClearHistoryDays
        settings.resumeIncompleteOnLaunch = resumeIncompleteOnLaunch

        let trimmedToken = hfToken.trimmingCharacters(in: .whitespaces)
        if trimmedToken.isEmpty {
            KeychainService.delete(.huggingFace)
        } else {
            KeychainService.set(trimmedToken, account: .huggingFace)
        }
        let trimmedGitHubToken = githubToken.trimmingCharacters(in: .whitespaces)
        if trimmedGitHubToken.isEmpty {
            KeychainService.delete(.github)
        } else {
            KeychainService.set(trimmedGitHubToken, account: .github)
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

    private static func formatSeconds(_ d: Double) -> String {
        "\(Int(d.rounded())) s"
    }
}

private struct SettingsAboutView: View {
    private let websiteURL = URL(string: "https://www.osmapi.com")!
    private let agentURL = URL(string: "https://www.osmapi.com/osmAgent")!
    private let repoURL = URL(string: "https://github.com/junainfinity/osmDownloads")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            values
            osmAgentCallout
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("osmDownloads")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Open source macOS downloader by osmAPI.com")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text3)
                }
            }

            Text("Open source, built for people who move real artifacts.")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("osmDownloads downloads Hugging Face models, GitHub files, and direct URLs into a predictable local workflow. Fork it, inspect it, adapt it for your stack, and send improvements back when they help others.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            buttonRow
        }
        .padding(16)
        .background(Theme.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var values: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Project values")
            valueRow(icon: .code, title: "Readable by design", text: "MIT licensed SwiftUI with practical layers and plain local storage.")
            valueRow(icon: .folderOpen, title: "Local-first", text: "Downloads land on your Mac, tokens stay in Keychain, and history remains yours.")
            valueRow(icon: .download, title: "Artifact aware", text: "Built around model files, repo trees, raw files, and resumable downloads.")
        }
    }

    private var osmAgentCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("From osmAPI.com")
            Text("If this kind of builder-first tooling feels right, try osmAgent from our website. It is made for software work where inspection, edits, tests, and shipping all belong in the same loop.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NSWorkspace.shared.open(agentURL)
            } label: {
                HStack(spacing: 6) {
                    Text("Try osmAgent")
                    Icon(icon: .link, size: 11, color: Theme.accentInk)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(14)
        .background(Theme.accentSoft)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var buttonRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                linkButton("Open project", icon: .link, url: repoURL)
                linkButton("osmAPI.com", icon: .globe, url: websiteURL)
                linkButton("osmAgent", icon: .link, url: agentURL)
            }
            VStack(alignment: .leading, spacing: 8) {
                linkButton("Open project", icon: .link, url: repoURL)
                linkButton("osmAPI.com", icon: .globe, url: websiteURL)
                linkButton("osmAgent", icon: .link, url: agentURL)
            }
        }
    }

    private func valueRow(icon: AppIcon, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon(icon: icon, size: 14, color: Theme.text2)
                .frame(width: 24, height: 24)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linkButton(_ title: String, icon: AppIcon, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Icon(icon: icon, size: 11, color: Theme.text2)
            }
        }
        .buttonStyle(GhostButtonStyle(compact: true))
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.08 * 10.5)
            .foregroundStyle(Theme.text3)
    }
}
