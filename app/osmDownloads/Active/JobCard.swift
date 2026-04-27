import SwiftUI

struct JobCard: View {
    @Bindable var job: Job
    @Environment(JobsViewModel.self) private var jobs
    @Environment(LiveProgressStore.self) private var live
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ProgressBar(progress: job.progress, height: 6)
            if expanded {
                VStack(spacing: 0) {
                    ForEach(job.files) { file in
                        FileRow(file: file)
                        if file.id != job.files.last?.id {
                            Divider().background(Theme.border).padding(.leading, 28)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: expanded)
    }

    private var expanded: Bool { appVM.expandedJobIDs.contains(job.id) }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(job.source == .huggingFace ? Theme.accentSoft : Theme.surface3)
                SourceIcon(source: job.source, size: 18)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(job.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    StatusPill(status: job.status)
                    Spacer(minLength: 0)
                }
                metaRow
            }

            Spacer(minLength: 6)
            actions
        }
    }

    private var metaRow: some View {
        let speed = aggregateSpeed
        let totalBytes = job.totalBytes
        let bytes = job.bytesDownloaded
        let remaining = max(0, totalBytes - bytes)

        return HStack(spacing: 8) {
            metaItem(text: "\(job.completedFileCount)/\(job.files.count) files")
            metaSep
            metaItem(text: Fmt.bytesPair(done: bytes, total: totalBytes > 0 ? totalBytes : nil))
            if job.status == .downloading {
                metaSep
                metaItem(text: Fmt.bps(speed))
                metaSep
                metaItem(text: Fmt.eta(remaining: remaining, bytesPerSecond: speed))
            }
        }
    }

    private func metaItem(text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(Theme.text3)
    }

    private var metaSep: some View {
        Text("·")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.text3)
    }

    private var aggregateSpeed: Double {
        var sum: Double = 0
        for file in job.files where file.status == .downloading {
            sum += live.files[file.id]?.bytesPerSecond ?? 0
        }
        return sum
    }

    private var actions: some View {
        HStack(spacing: 6) {
            switch job.status {
            case .downloading:
                IconButton(icon: .pause, label: "Pause") { jobs.pause(job) }
            case .paused, .failed:
                IconButton(icon: .play, label: "Resume") { jobs.resume(job) }
            case .completed:
                IconButton(icon: .folderOpen, label: "Reveal in Finder") {
                    FileSystemService.revealFolder(job.destinationFolder)
                }
            default:
                EmptyView()
            }

            if job.status != .completed {
                IconButton(icon: .stop, label: "Stop & remove") { jobs.cancel(job) }
            }

            Menu {
                Button("Reveal in Finder") {
                    FileSystemService.revealFolder(job.destinationFolder)
                }
                Button("Copy source URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(job.sourceURL.absoluteString, forType: .string)
                }
                Divider()
                Button("Stop & remove", role: .destructive) { jobs.remove(job) }
            } label: {
                Icon(icon: .more, size: 14, color: Theme.text2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)

            Button {
                appVM.toggleExpanded(job.id)
            } label: {
                Icon(icon: expanded ? .chevronDown : .chevronRight,
                     size: 13, color: Theme.text2)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help(expanded ? "Collapse" : "Expand")
        }
    }
}

struct IconButton: View {
    let icon: AppIcon
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(icon: icon, size: 12, color: Theme.text2)
                .frame(width: 28, height: 28)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.borderless)
        .help(label)
    }
}
