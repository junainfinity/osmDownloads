import SwiftData
import SwiftUI

struct AppShell: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SettingsStore.self) private var settings
    @State private var sidebarVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 232, max: 260)
        } detail: {
            MainPane()
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.bg)
    }
}

private struct MainPane: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 0) {
            Titlebar()
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
        }
    }
}

private struct Titlebar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Job> { $0.statusRaw == "downloading" }) private var activeJobs: [Job]
    @State private var settingsOpen: Bool = false

    var body: some View {
        HStack(spacing: 12) {
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
        }
    }

    private var subtitle: String {
        switch appVM.selectedView {
        case .active:
            let count = activeJobs.count
            return count == 0 ? "Idle" : "\(count) active"
        case .history: return ""
        case .queue:   return ""
        }
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
