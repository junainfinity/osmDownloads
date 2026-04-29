import AppKit
import SwiftData
import SwiftUI

@main
struct osmDownloadsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let container: ModelContainer
    @State private var coordinator: DownloadCoordinator
    @State private var jobs: JobsViewModel
    @State private var appVM = AppViewModel.shared
    @State private var settings = SettingsStore.shared

    init() {
        let container: ModelContainer
        do {
            let schema = Schema([Job.self, FileItem.self])
            let config = ModelConfiguration(
                "osmDownloads",
                schema: schema,
                url: AppPaths.storeURL,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container
        let coord = MainActor.assumeIsolated {
            DownloadCoordinator(context: container.mainContext)
        }
        _coordinator = State(initialValue: coord)
        _jobs = State(initialValue: MainActor.assumeIsolated { JobsViewModel(coordinator: coord) })
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(coordinator.liveProgress)
                .environment(jobs)
                .environment(appVM)
                .environment(settings)
                .preferredColorScheme(settings.themePreference.colorScheme)
                .frame(minWidth: 880, minHeight: 560)
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }   // disable File > New
        }

        MenuBarExtra("osmDownloads", systemImage: "arrow.down.circle") {
            MenuBarContent()
                .environment(coordinator.liveProgress)
                .environment(jobs)
                .environment(appVM)
                .environment(settings)
                .modelContainer(container)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                AppViewModel.shared.receiveExternalURL(url)
            }
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        Task { @MainActor in
            AppViewModel.shared.receiveExternalURL(URL(fileURLWithPath: filename))
        }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        Task { @MainActor in
            for filename in filenames {
                AppViewModel.shared.receiveExternalURL(URL(fileURLWithPath: filename))
            }
            sender.reply(toOpenOrPrint: .success)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }

    func application(_ application: NSApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DownloadEngine.backgroundCompletionHandler = completionHandler
    }
}

private struct MenuBarContent: View {
    @Environment(JobsViewModel.self) private var jobs
    @Environment(AppViewModel.self) private var appVM

    @Query(sort: [SortDescriptor(\Job.createdAt, order: .reverse)]) private var allJobs: [Job]

    var body: some View {
        Text(statusLine)

        Button("Open osmDownloads") {
            openMainWindow()
        }

        Button("Paste URL from Clipboard") {
            if let string = NSPasteboard.general.string(forType: .string) {
                appVM.receiveURLString(string)
                openMainWindow()
            }
        }

        Divider()

        Button("Pause All") {
            jobs.pauseAll(jobs: activeJobs)
        }
        .disabled(activeJobs.isEmpty)

        Button("Resume All") {
            jobs.resumeAll(jobs: pausedJobs)
            openMainWindow()
        }
        .disabled(pausedJobs.isEmpty)

        Divider()

        Button("Quit osmDownloads") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var activeJobs: [Job] {
        allJobs.filter { $0.status == .downloading || $0.status == .resolving }
    }

    private var queuedJobs: [Job] {
        allJobs.filter { $0.status == .queued }
    }

    private var pausedJobs: [Job] {
        allJobs.filter { $0.status == .paused || $0.status == .failed }
    }

    private var statusLine: String {
        if activeJobs.isEmpty, queuedJobs.isEmpty {
            return "Idle"
        }
        let active = "\(activeJobs.count) active"
        let queued = queuedJobs.isEmpty ? "" : " · \(queuedJobs.count) queued"
        return active + queued
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
