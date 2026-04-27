import SwiftUI

struct FileRow: View {
    @Bindable var file: FileItem
    @Environment(LiveProgressStore.self) private var live
    @Environment(JobsViewModel.self) private var jobs

    var body: some View {
        HStack(spacing: 10) {
            Text(extLabel)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .frame(width: 38, alignment: .leading)

            Text(file.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 6)

            ProgressBar(progress: progress, height: 4)
                .frame(width: 110)

            Text(Fmt.bytesPair(done: bytes, total: file.expectedSize))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.text3)
                .frame(minWidth: 110, alignment: .trailing)

            controls
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    private var extLabel: String {
        let ext = (file.name as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }

    private var bytes: Int64 {
        live.files[file.id]?.bytesDownloaded ?? file.bytesDownloaded
    }

    private var progress: Double? {
        guard let total = file.expectedSize, total > 0 else {
            return file.status == .downloading ? nil : 0
        }
        return Double(bytes) / Double(total)
    }

    /// Per-file action row — pause/resume/cancel for files in active states,
    /// and a static glyph for terminal states.
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 4) {
            switch file.status {
            case .downloading:
                fileButton(.pause, label: "Pause") { jobs.pauseFile(file) }
                fileButton(.stop,  label: "Stop")  { jobs.cancelFile(file) }
            case .paused, .queued:
                fileButton(.play, label: "Resume") { jobs.resumeFile(file) }
                fileButton(.stop, label: "Stop")   { jobs.cancelFile(file) }
            case .failed:
                fileButton(.refresh, label: "Retry") { jobs.resumeFile(file) }
            case .completed:
                Icon(icon: .checkOn, size: 12, color: Theme.success)
            case .canceled:
                Icon(icon: .stop, size: 11, color: Theme.text3)
            }
        }
    }

    private func fileButton(_ icon: AppIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon: icon, size: 10, color: Theme.text2)
                .frame(width: 22, height: 22)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.borderless)
        .help(label)
    }
}
