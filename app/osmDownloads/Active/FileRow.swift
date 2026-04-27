import SwiftUI

struct FileRow: View {
    @Bindable var file: FileItem
    @Environment(LiveProgressStore.self) private var live

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

            statusGlyph
                .frame(width: 14)
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

    @ViewBuilder
    private var statusGlyph: some View {
        switch file.status {
        case .completed:
            Icon(icon: .checkOn, size: 12, color: Theme.success)
        case .failed:
            Icon(icon: .warn, size: 12, color: Theme.danger)
        case .paused:
            Icon(icon: .pause, size: 11, color: Theme.text3)
        case .canceled:
            Icon(icon: .stop, size: 11, color: Theme.text3)
        case .downloading, .queued:
            EmptyView()
        }
    }
}
