import SwiftUI

struct HistoryRow: View {
    @Bindable var job: Job
    @Environment(JobsViewModel.self) private var jobs
    @State private var fileExists: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(job.source == .huggingFace ? Theme.accentSoft : Theme.surface3)
                SourceIcon(source: job.source, size: 16)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(job.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    StatusPill(status: job.status)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    Text("\(job.files.count) files")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.text3)
                    Text("·").foregroundStyle(Theme.text3)
                    Text(Fmt.bytes(job.totalBytes))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.text3)
                    if let finished = job.completedAt {
                        Text("·").foregroundStyle(Theme.text3)
                        Text(Fmt.relative(finished))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.text3)
                    }
                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                if job.status == .completed {
                    Button("Reveal") {
                        FileSystemService.revealFolder(job.destinationFolder)
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                    .disabled(!fileExists)
                }
                if job.status == .failed || job.status == .canceled {
                    Button("Retry") {
                        jobs.retry(job)
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                }
                Button {
                    jobs.remove(job)
                } label: {
                    Icon(icon: .trash, size: 12, color: Theme.text3)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("Delete row")
            }
        }
        .padding(12)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .onAppear {
            fileExists = FileSystemService.fileExists(at: job.destinationFolder)
        }
    }
}
