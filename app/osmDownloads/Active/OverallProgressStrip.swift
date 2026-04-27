import SwiftUI

struct OverallProgressStrip: View {
    let activeJobs: [Job]
    @Environment(LiveProgressStore.self) private var live

    var body: some View {
        HStack(spacing: 16) {
            stat(label: "Active", value: "\(activeJobs.count)")
            divider
            stat(label: "Speed", value: Fmt.bps(aggregateSpeed))
            divider
            stat(label: "ETA", value: etaLabel)

            Spacer(minLength: 18)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Fmt.bytesPair(done: doneBytes, total: totalBytes))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                    Text(Fmt.percent(progress))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                ProgressBar(progress: progress, height: 6)
                    .frame(width: 220)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1, height: 26)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.08 * 9.5)
                .foregroundStyle(Theme.text3)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.text)
        }
    }

    private var aggregateSpeed: Double {
        var sum: Double = 0
        for job in activeJobs {
            for file in job.files where file.status == .downloading {
                sum += live.files[file.id]?.bytesPerSecond ?? 0
            }
        }
        return sum
    }

    private var doneBytes: Int64 {
        activeJobs.reduce(0) { $0 + $1.bytesDownloaded }
    }
    private var totalBytes: Int64 {
        activeJobs.reduce(0) { $0 + $1.totalBytes }
    }
    private var progress: Double? {
        totalBytes > 0 ? Double(doneBytes) / Double(totalBytes) : nil
    }
    private var etaLabel: String {
        let remaining = max(0, totalBytes - doneBytes)
        return Fmt.eta(remaining: remaining, bytesPerSecond: aggregateSpeed)
    }
}
