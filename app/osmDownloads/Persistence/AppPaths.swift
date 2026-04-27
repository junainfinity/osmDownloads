import Foundation

enum AppPaths {
    static var supportDir: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("osmDownloads", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var storeURL: URL {
        supportDir.appendingPathComponent("store.sqlite")
    }

    static var resumeDir: URL {
        let url = supportDir.appendingPathComponent("resume", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var logsDir: URL {
        let url = supportDir.appendingPathComponent("logs", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Default downloads root: ~/Downloads/osmDownloads/
    static var defaultDownloadsRoot: URL {
        let downloads = (try? FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let dir = downloads.appendingPathComponent("osmDownloads", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
