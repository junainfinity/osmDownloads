import SwiftData
import SwiftUI

struct Sidebar: View {
    @Environment(AppViewModel.self) private var appVM
    @Query private var allJobs: [Job]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHeader()
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 2) {
                NavRow(view: .active, icon: .download, count: activeCount)
                NavRow(view: .history, icon: .clock, count: historyCount)
                NavRow(view: .queue, icon: .inbox, count: queueCount)
            }
            .padding(.horizontal, 8)

            SectionTitle("Sources")
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 2) {
                SourceRow(label: "All sources",  filter: .all,         count: allJobs.count, glyph: nil)
                SourceRow(label: "Hugging Face", filter: .huggingFace, count: count(for: .huggingFace), glyph: .huggingFace)
                SourceRow(label: "GitHub",       filter: .github,      count: count(for: .github),      glyph: .github)
                SourceRow(label: "Other URLs",   filter: .generic,     count: count(for: .generic),     glyph: .generic)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            DiskMeter()
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface2)
    }

    private var activeCount: Int {
        allJobs.filter { $0.status == .downloading || $0.status == .resolving || $0.status == .paused }.count
    }
    private var historyCount: Int {
        allJobs.filter { $0.status == .completed || $0.status == .failed || $0.status == .canceled }.count
    }
    private var queueCount: Int {
        allJobs.filter { $0.status == .queued }.count
    }
    private func count(for source: Source) -> Int {
        allJobs.filter { $0.source == source }.count
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 9) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
            HStack(spacing: 0) {
                Text("osm").foregroundStyle(Theme.text).fontWeight(.semibold)
                Text("Downloads").foregroundStyle(Theme.text3)
            }
            .font(.system(size: 15))
        }
    }
}

private struct NavRow: View {
    let view: MainView
    let icon: AppIcon
    let count: Int

    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        let active = appVM.selectedView == view
        Button {
            appVM.selectedView = view
        } label: {
            HStack(spacing: 9) {
                Icon(icon: icon, size: 13, color: active ? Theme.text : Theme.text2)
                Text(label)
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Theme.text : Theme.text2)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.surface3)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(active ? Theme.surface : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .stroke(active ? Theme.border : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .shadow(color: active ? Color.black.opacity(0.04) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.borderless)
    }

    private var label: String {
        switch view {
        case .active:  return "Active"
        case .history: return "History"
        case .queue:   return "Queue"
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.08 * 10.5)
            .foregroundStyle(Theme.text3)
    }
}

private struct SourceRow: View {
    let label: String
    let filter: SourceFilter
    let count: Int
    let glyph: Source?

    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        let active = appVM.sourceFilter == filter
        Button {
            appVM.selectSourceFilter(filter)
        } label: {
            HStack(spacing: 9) {
                if let glyph {
                    SourceIcon(source: glyph, size: 14)
                        .frame(width: 14, height: 14)
                } else {
                    Icon(icon: .download, size: 12, color: active ? Theme.text : Theme.text3)
                        .frame(width: 14, height: 14)
                }
                Text(label)
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Theme.text : Theme.text2)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(active ? Theme.text2 : Theme.text3)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(active ? Theme.surface : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .stroke(active ? Theme.border : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        }
        .buttonStyle(.borderless)
    }
}

private struct DiskMeter: View {
    @Environment(SettingsStore.self) private var settings
    @State private var stats: (free: Int64, capacity: Int64)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Icon(icon: .folder, size: 11, color: Theme.text3)
                Text("Disk")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text3)
                Spacer(minLength: 0)
                if let stats {
                    Text("\(Fmt.bytes(stats.free)) free")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text3)
                }
            }
            ProgressBar(progress: stats.flatMap { s in
                s.capacity > 0 ? Double(s.capacity - s.free) / Double(s.capacity) : nil
            }, height: 4)
        }
        .padding(10)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .task {
            stats = FileSystemService.volumeStats(at: settings.destinationFolderURL)
        }
    }
}
