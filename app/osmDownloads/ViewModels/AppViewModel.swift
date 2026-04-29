import Foundation
import Observation

enum MainView: String, Hashable, CaseIterable, Sendable {
    case active, history, queue
}

enum SourceFilter: String, Hashable, CaseIterable, Sendable {
    case all, huggingFace, github, generic
}

enum HistoryFilter: String, CaseIterable {
    case all, completed, failed
    var label: String { rawValue.capitalized }
}

@Observable
@MainActor
final class AppViewModel {
    static let shared = AppViewModel()

    var selectedView: MainView = .active
    var sourceFilter: SourceFilter = .all
    var historyFilter: HistoryFilter = .all
    var historySearch: String = ""
    var expandedJobIDs: Set<UUID> = []
    var incomingURLString: String?

    func receiveExternalURL(_ url: URL) {
        selectedView = .active
        incomingURLString = AppViewModel.displayString(for: url)
    }

    func receiveURLString(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedView = .active
        incomingURLString = trimmed
    }

    func selectSourceFilter(_ filter: SourceFilter) {
        sourceFilter = (sourceFilter == filter && filter != .all) ? .all : filter
        selectedView = .history
        historyFilter = .all
        historySearch = ""
    }

    func consumeIncomingURLString() -> String? {
        defer { incomingURLString = nil }
        return incomingURLString
    }

    func toggleExpanded(_ id: UUID) {
        if expandedJobIDs.contains(id) {
            expandedJobIDs.remove(id)
        } else {
            expandedJobIDs.insert(id)
        }
    }

    private static func displayString(for url: URL) -> String {
        if url.isFileURL,
           url.pathExtension.localizedCaseInsensitiveCompare("webloc") == .orderedSame,
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let target = dict["URL"] as? String,
           !target.isEmpty {
            return target
        }
        return url.absoluteString
    }
}
