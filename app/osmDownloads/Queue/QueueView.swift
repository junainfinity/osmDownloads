import SwiftData
import SwiftUI

struct QueueView: View {
    @Environment(JobsViewModel.self) private var jobs
    @Environment(SettingsStore.self) private var settings
    @Environment(AppViewModel.self) private var appVM
    @Query(sort: [SortDescriptor(\Job.createdAt, order: .forward)]) private var allJobs: [Job]

    var body: some View {
        VStack(spacing: 0) {
            if queuedJobs.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface2)
                        Icon(icon: .inbox, size: 22, color: Theme.text3)
                    }
                    .frame(width: 56, height: 56)
                    Text("Queue is empty")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Jobs waiting their turn will appear here.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        queueHeader
                        LazyVStack(spacing: 8) {
                            ForEach(Array(queuedJobs.enumerated()), id: \.element.id) { index, job in
                                queueRow(job: job, position: index + 1)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }
            }
        }
        .background(Theme.bg)
    }

    private var queuedJobs: [Job] {
        allJobs
            .filter { $0.status == .queued }
            .filter(matchesSourceFilter)
    }

    private var activeJobs: [Job] {
        allJobs
            .filter { $0.status == .downloading || $0.status == .resolving }
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

    private var queueHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(queuedJobs.count) waiting")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("\(activeJobs.count) of \(settings.maxConcurrentJobs) job slots in use")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
            }
            Spacer(minLength: 0)
            Button("Cancel all") {
                for job in queuedJobs { jobs.cancel(job) }
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
    }

    private func queueRow(job: Job, position: Int) -> some View {
        HStack(spacing: 12) {
            Text("#\(position)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text3)
                .frame(width: 38, alignment: .leading)

            SourceIcon(source: job.source, size: 15)

            VStack(alignment: .leading, spacing: 3) {
                Text(job.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(queueSubtitle(job))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button("Cancel") {
                jobs.cancel(job)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func queueSubtitle(_ job: Job) -> String {
        let count = job.files.count
        let size = Fmt.bytes(job.totalBytes)
        let destination = job.destinationFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        return "\(count) file\(count == 1 ? "" : "s") · \(size) · \(destination)"
    }
}
