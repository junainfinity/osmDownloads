import SwiftData
import SwiftUI

enum HistoryFilter: String, CaseIterable {
    case all, completed, failed
    var label: String { rawValue.capitalized }
}

struct HistoryView: View {
    @Environment(JobsViewModel.self) private var jobs
    @Environment(AppViewModel.self) private var appVM

    @Query(sort: [SortDescriptor(\Job.completedAt, order: .reverse)]) private var allJobs: [Job]
    @State private var filter: HistoryFilter = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toolbar
                if filteredJobs.isEmpty {
                    emptyState.padding(.top, 80)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredJobs) { job in
                            HistoryRow(job: job)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 80)
        }
        .background(Theme.bg)
    }

    private var historyJobs: [Job] {
        allJobs.filter { job in
            switch job.status {
            case .completed, .failed, .canceled: return true
            default: return false
            }
        }
        .filter(matchesSourceFilter)
    }

    private func matchesSourceFilter(_ job: Job) -> Bool {
        switch appVM.sourceFilter {
        case .all:         return true
        case .huggingFace: return job.source == .huggingFace
        case .github:      return job.source == .github
        case .generic:     return job.source == .generic
        }
    }

    private var filteredJobs: [Job] {
        let base: [Job]
        switch filter {
        case .all:       base = historyJobs
        case .completed: base = historyJobs.filter { $0.status == .completed }
        case .failed:    base = historyJobs.filter { $0.status == .failed || $0.status == .canceled }
        }
        let q = appVM.historySearch.lowercased()
        if q.isEmpty { return base }
        return base.filter {
            $0.title.lowercased().contains(q) || $0.sourceURL.absoluteString.lowercased().contains(q)
        }
    }

    private var toolbar: some View {
        @Bindable var appVMBinding = appVM
        return HStack(spacing: 10) {
            Picker("", selection: $filter) {
                ForEach(HistoryFilter.allCases, id: \.self) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            HStack(spacing: 6) {
                Icon(icon: .search, size: 12, color: Theme.text3)
                TextField("Search history", text: $appVMBinding.historySearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Spacer(minLength: 0)

            Button("Clear all") {
                jobs.clearAll(jobs: historyJobs)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
            .disabled(historyJobs.isEmpty)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface2)
                Icon(icon: .clock, size: 22, color: Theme.text3)
            }
            .frame(width: 56, height: 56)
            Text("No history yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Completed and failed downloads will appear here.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
