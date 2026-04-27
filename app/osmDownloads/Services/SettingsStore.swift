import Foundation
import Observation
import SwiftUI

/// Wraps UserDefaults-backed primitives and exposes them as an @Observable.
/// Tokens go through KeychainService, not here.
@Observable
final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    var maxConcurrentJobs: Int {
        didSet { UserDefaults.standard.set(maxConcurrentJobs, forKey: "maxConcurrentJobs") }
    }
    var maxConcurrentFilesPerJob: Int {
        didSet { UserDefaults.standard.set(maxConcurrentFilesPerJob, forKey: "maxConcurrentFilesPerJob") }
    }
    var retryCount: Int {
        didSet { UserDefaults.standard.set(retryCount, forKey: "retryCount") }
    }
    var retryBackoffSeconds: Double {
        didSet { UserDefaults.standard.set(retryBackoffSeconds, forKey: "retryBackoffSeconds") }
    }
    var connectionTimeoutSeconds: Double {
        didSet { UserDefaults.standard.set(connectionTimeoutSeconds, forKey: "connectionTimeoutSeconds") }
    }
    /// Max aggregate download speed in Mbps. 0 = unlimited.
    var maxDownloadMbps: Double {
        didSet { UserDefaults.standard.set(maxDownloadMbps, forKey: "maxDownloadMbps") }
    }
    var autoClearHistoryDays: Int {
        didSet { UserDefaults.standard.set(autoClearHistoryDays, forKey: "autoClearHistoryDays") }
    }
    var resumeIncompleteOnLaunch: Bool {
        didSet { UserDefaults.standard.set(resumeIncompleteOnLaunch, forKey: "resumeIncompleteOnLaunch") }
    }
    var themePreference: ThemePreference {
        didSet { UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference") }
    }
    var density: Density {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: "density") }
    }
    var destinationFolderPath: String {
        didSet { UserDefaults.standard.set(destinationFolderPath, forKey: "destinationFolderPath") }
    }

    var destinationFolderURL: URL {
        URL(fileURLWithPath: destinationFolderPath, isDirectory: true)
    }

    private init() {
        let d = UserDefaults.standard
        self.maxConcurrentJobs        = d.object(forKey: "maxConcurrentJobs") as? Int ?? 3
        self.maxConcurrentFilesPerJob = d.object(forKey: "maxConcurrentFilesPerJob") as? Int ?? 4
        self.retryCount               = d.object(forKey: "retryCount") as? Int ?? 3
        self.retryBackoffSeconds      = d.object(forKey: "retryBackoffSeconds") as? Double ?? 2.0
        self.connectionTimeoutSeconds = d.object(forKey: "connectionTimeoutSeconds") as? Double ?? 30
        self.maxDownloadMbps          = d.object(forKey: "maxDownloadMbps") as? Double ?? 0
        self.autoClearHistoryDays     = d.object(forKey: "autoClearHistoryDays") as? Int ?? 0
        self.resumeIncompleteOnLaunch = d.object(forKey: "resumeIncompleteOnLaunch") as? Bool ?? true
        let themeRaw  = d.string(forKey: "themePreference") ?? ThemePreference.system.rawValue
        self.themePreference = ThemePreference(rawValue: themeRaw) ?? .system
        let densityRaw = d.string(forKey: "density") ?? Density.comfortable.rawValue
        self.density = Density(rawValue: densityRaw) ?? .comfortable
        self.destinationFolderPath = d.string(forKey: "destinationFolderPath")
            ?? AppPaths.defaultDownloadsRoot.path
    }
}

enum ThemePreference: String, CaseIterable, Sendable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

enum Density: String, CaseIterable, Sendable {
    case comfortable, compact

    var rowPaddingV: CGFloat { self == .compact ? 6 : 10 }
    var cardPaddingV: CGFloat { self == .compact ? 8 : 12 }
}
