import Foundation

enum ResumeStore {
    static func url(for fileID: UUID) -> URL {
        AppPaths.resumeDir.appendingPathComponent("\(fileID.uuidString).resumedata")
    }

    static func write(_ data: Data, for fileID: UUID) throws {
        try data.write(to: url(for: fileID), options: .atomic)
    }

    static func read(for fileID: UUID) -> Data? {
        try? Data(contentsOf: url(for: fileID))
    }

    static func delete(for fileID: UUID) {
        try? FileManager.default.removeItem(at: url(for: fileID))
    }

    static func cleanup(validIDs: Set<UUID>) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: AppPaths.resumeDir,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in entries {
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            if let id, !validIDs.contains(id) {
                try? fm.removeItem(at: url)
            }
        }
    }

    /// Sanitize macOS resume data for the long-standing URLSession bug where
    /// resume blobs are missing keys or have a stale version. Returns nil if
    /// the data can't be repaired.
    static func sanitize(_ data: Data) -> Data? {
        guard var plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainersAndLeaves,
            format: nil
        ) as? [String: Any] else { return nil }

        plist["$archiver"] = "NSKeyedArchiver"
        if (plist["NSURLSessionResumeInfoVersion"] as? Int) != 2 {
            plist["NSURLSessionResumeInfoVersion"] = 2
        }
        return try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
    }
}
