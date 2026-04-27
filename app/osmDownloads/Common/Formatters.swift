import Foundation

enum Fmt {
    static func bytes(_ count: Int64?) -> String {
        guard let count, count > 0 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: count)
    }

    static func bytesPair(done: Int64, total: Int64?) -> String {
        if let total, total > 0 {
            return "\(bytes(done)) / \(bytes(total))"
        }
        return bytes(done)
    }

    static func bps(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "—" }
        return bytes(Int64(bytesPerSecond)) + "/s"
    }

    static func eta(remaining: Int64, bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 1 else { return "—" }
        let seconds = Double(remaining) / bytesPerSecond
        return duration(seconds)
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s < 60   { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        let h = s / 3600
        let m = (s % 3600) / 60
        return "\(h)h \(m)m"
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func percent(_ p: Double?) -> String {
        guard let p else { return "—" }
        return "\(Int((max(0, min(1, p)) * 100).rounded()))%"
    }
}
