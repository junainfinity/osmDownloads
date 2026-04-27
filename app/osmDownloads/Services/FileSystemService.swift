import AppKit
import Foundation

enum FileSystemService {
    /// Reveal a single file in Finder; for multi-file jobs prefer revealing the parent folder.
    static func revealInFinder(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            // Open the parent if the exact file is gone.
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                NSWorkspace.shared.open(parent)
            }
        }
    }

    static func revealFolder(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.open(url)
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Bytes of free space on the volume hosting `url`, or nil if unknown.
    static func freeSpace(at url: URL) -> Int64? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    /// Bytes used vs. capacity on the volume hosting `url`.
    static func volumeStats(at url: URL) -> (free: Int64, capacity: Int64)? {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            guard let free = values.volumeAvailableCapacityForImportantUsage,
                  let capacity = values.volumeTotalCapacity else { return nil }
            return (free, Int64(capacity))
        } catch {
            return nil
        }
    }

    /// Slugify a string to a folder-name-safe form. "meta-llama/Llama-3.1" → "meta-llama_Llama-3.1".
    static func slugify(_ s: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>| ")
        return s.unicodeScalars
            .map { invalid.contains($0) ? "_" : Character($0) }
            .map(String.init)
            .joined()
    }
}
