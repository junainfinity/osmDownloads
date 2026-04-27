import SwiftData
import SwiftUI

struct ActiveView: View {
    @Environment(JobsViewModel.self) private var jobs
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var context

    @State private var resolveVM = ResolveViewModel()
    @Query(sort: [SortDescriptor(\Job.createdAt, order: .reverse)]) private var allJobs: [Job]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NewDownloadBar(resolveVM: resolveVM)

                if !activeJobs.isEmpty {
                    OverallProgressStrip(activeJobs: activeJobs)
                    listToolbar
                    LazyVStack(spacing: 10) {
                        ForEach(activeJobs) { job in
                            JobCard(job: job)
                        }
                    }
                } else if !resolveVM.urlString.isEmpty {
                    // Avoid showing the empty state while the user is still resolving.
                    EmptyView()
                } else {
                    emptyState
                        .padding(.top, 80)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 80)
        }
        .background(Theme.bg)
    }

    private var activeJobs: [Job] {
        allJobs.filter { job in
            switch job.status {
            case .downloading, .resolving, .paused, .queued: return true
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

    private var listToolbar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Button("Pause all") {
                jobs.pauseAll(jobs: activeJobs)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
            .disabled(!activeJobs.contains { $0.status == .downloading })

            Button("Resume all") {
                jobs.resumeAll(jobs: activeJobs)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
            .disabled(!activeJobs.contains { $0.status == .paused || $0.status == .failed })

            Button("Clear all") {
                jobs.clearAll(jobs: activeJobs)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
            .disabled(activeJobs.isEmpty)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface2)
                Icon(icon: .download, size: 22, color: Theme.text3)
            }
            .frame(width: 56, height: 56)
            Text("No active downloads")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Paste a URL above to get started. osmDownloads detects Hugging Face repos, GitHub releases, and direct URLs.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
    }
}
