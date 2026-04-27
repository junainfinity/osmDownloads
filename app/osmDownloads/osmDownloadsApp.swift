import SwiftData
import SwiftUI

@main
struct osmDownloadsApp: App {
    let container: ModelContainer
    @State private var coordinator: DownloadCoordinator
    @State private var jobs: JobsViewModel
    @State private var appVM = AppViewModel()
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
    }
}
