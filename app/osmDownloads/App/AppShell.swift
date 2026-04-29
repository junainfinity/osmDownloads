import AppKit
import SwiftData
import SwiftUI

struct AppShell: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SettingsStore.self) private var settings
    @State private var sidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                Sidebar()
                    .frame(width: 232)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider().background(Theme.border)
            }

            MainPane(sidebarVisible: $sidebarVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Theme.bg)
        .background(WindowToolbarSuppressor())
        .animation(.easeOut(duration: 0.18), value: sidebarVisible)
    }
}

private struct MainPane: View {
    @Environment(AppViewModel.self) private var appVM
    @Binding var sidebarVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            Titlebar(sidebarVisible: $sidebarVisible)
            Divider().background(Theme.border)
            ContentRouter()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.bg)
        }
    }
}

private struct ContentRouter: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        switch appVM.selectedView {
        case .active:  ActiveView()
        case .history: HistoryView()
        case .queue:   QueueView()
        case .about:   AboutView()
        }
    }
}

private struct AboutView: View {
    private let websiteURL = URL(string: "https://www.osmapi.com")!
    private let agentURL = URL(string: "https://www.osmapi.com/osmAgent")!
    private let repoURL = URL(string: "https://github.com/junainfinity/osmDownloads")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                principles
                osmAgentCallout
                projectLinks
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 80)
        }
        .background(Theme.bg)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("osmDownloads")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Open source macOS downloader by osmAPI.com")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.text3)
                }
            }

            Text("Open source, built for people who move real artifacts.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("osmDownloads is an open-source project by osmAPI.com for downloading Hugging Face models, GitHub files, and direct URLs into a predictable local workflow. Fork it, inspect it, and shape it for your stack.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    actionButton("Try osmAgent", icon: .globe, url: agentURL, primary: true)
                    actionButton("Open project", icon: .link, url: repoURL, primary: false)
                    actionButton("osmAPI.com", icon: .globe, url: websiteURL, primary: false)
                }

                VStack(alignment: .leading, spacing: 8) {
                    actionButton("Try osmAgent", icon: .globe, url: agentURL, primary: true)
                    actionButton("Open project", icon: .link, url: repoURL, primary: false)
                    actionButton("osmAPI.com", icon: .globe, url: websiteURL, primary: false)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Open source principles")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                AboutPrincipleTile(
                    icon: .code,
                    title: "Fork-friendly",
                    text: "MIT licensed, readable SwiftUI, and small enough to understand without ceremony."
                )
                AboutPrincipleTile(
                    icon: .folderOpen,
                    title: "Local-first",
                    text: "Your files land on your Mac. Tokens stay in Keychain. History lives in SwiftData."
                )
                AboutPrincipleTile(
                    icon: .download,
                    title: "Artifact aware",
                    text: "Built around the messy reality of models, repo trees, raw files, and resumable downloads."
                )
            }
        }
    }

    private var osmAgentCallout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                agentText
                Spacer(minLength: 12)
                actionButton("Visit osmAgent", icon: .link, url: agentURL, primary: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                agentText
                actionButton("Visit osmAgent", icon: .link, url: agentURL, primary: true)
            }
        }
        .padding(15)
        .background(Theme.accentSoft)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var projectLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Project")
            Text("Open source by osmAPI.com • MIT licensed • Made for builders who prefer tools they can inspect")
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.text3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var agentText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Like this builder-first approach?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Try osmAgent from osmAPI.com when you want an AI teammate that can inspect, edit, test, and ship software with you.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.08 * 10.5)
            .foregroundStyle(Theme.text3)
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: AppIcon, url: URL, primary: Bool) -> some View {
        if primary {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                    Icon(icon: icon, size: 11, color: Theme.accentInk)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                    Icon(icon: icon, size: 11, color: Theme.text2)
                }
            }
            .buttonStyle(GhostButtonStyle())
        }
    }
}

private struct AboutPrincipleTile: View {
    let icon: AppIcon
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Icon(icon: icon, size: 15, color: Theme.text2)
                .frame(width: 26, height: 26)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))

            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.text)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

private struct Titlebar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Job> { $0.statusRaw == "downloading" }) private var activeJobs: [Job]
    @Binding var sidebarVisible: Bool
    @State private var settingsOpen: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                sidebarVisible.toggle()
            } label: {
                Icon(icon: .sidebar, size: 15, color: Theme.text2)
            }
            .buttonStyle(IconButtonStyle())
            .help(sidebarVisible ? "Hide sidebar" : "Show sidebar")

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
            }
            Spacer(minLength: 0)
            ThemeToggle()
            Button {
                settingsOpen = true
            } label: {
                Icon(icon: .settings, size: 15, color: Theme.text2)
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(height: 48)
        .background(Theme.surface)
        .sheet(isPresented: $settingsOpen) {
            SettingsSheet()
        }
    }

    private var title: String {
        switch appVM.selectedView {
        case .active:  return "Downloads"
        case .history: return "History"
        case .queue:   return "Queue"
        case .about:   return "About"
        }
    }

    private var subtitle: String {
        switch appVM.selectedView {
        case .active:
            let count = activeJobs.count
            return count == 0 ? "Idle" : "\(count) active"
        case .history: return ""
        case .queue:   return ""
        case .about:   return "Open source by osmAPI.com"
        }
    }
}

private struct WindowToolbarSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.toolbar = nil
    }
}

private struct ThemeToggle: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        HStack(spacing: 0) {
            button(.sun, target: .light)
            button(.moon, target: .dark)
        }
        .padding(2)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func button(_ icon: AppIcon, target: ThemePreference) -> some View {
        let active = settings.themePreference == target
        return Button {
            settings.themePreference = target
        } label: {
            Icon(icon: icon, size: 12, color: active ? Theme.text : Theme.text3)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(active ? Theme.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.borderless)
        .help(target.rawValue.capitalized)
    }
}
