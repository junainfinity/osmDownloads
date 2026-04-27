import Foundation
import Observation

enum MainView: String, Hashable, CaseIterable, Sendable {
    case active, history, queue
}

enum SourceFilter: String, Hashable, CaseIterable, Sendable {
    case all, huggingFace, github, generic
}

@Observable
@MainActor
final class AppViewModel {
    var selectedView: MainView = .active
    var sourceFilter: SourceFilter = .all
    var historySearch: String = ""
    var expandedJobIDs: Set<UUID> = []

    func toggleExpanded(_ id: UUID) {
        if expandedJobIDs.contains(id) {
            expandedJobIDs.remove(id)
        } else {
            expandedJobIDs.insert(id)
        }
    }
}
