import Foundation
import Observation
import SwiftData

/// Convenience facade over the DownloadCoordinator that views call into.
@Observable
@MainActor
final class JobsViewModel {
    let coordinator: DownloadCoordinator

    init(coordinator: DownloadCoordinator) {
        self.coordinator = coordinator
    }

    var liveProgress: LiveProgressStore { coordinator.liveProgress }

    func enqueue(manifest: ResolvedManifest, selectedFileIDs: Set<UUID>, destination: URL) {
        coordinator.enqueue(manifest, selectedFileIDs: selectedFileIDs, destination: destination)
    }

    func pause(_ job: Job)  { coordinator.pauseJob(job)  }
    func resume(_ job: Job) { coordinator.resumeJob(job) }
    func cancel(_ job: Job) { coordinator.cancelJob(job) }
    func remove(_ job: Job) { coordinator.removeJob(job) }
    func retry(_ job: Job)  { coordinator.retryJob(job)  }

    func pauseAll(jobs: [Job]) {
        for job in jobs where job.status == .downloading { pause(job) }
    }

    func resumeAll(jobs: [Job]) {
        for job in jobs where job.status == .paused || job.status == .failed { resume(job) }
    }

    func clearAll(jobs: [Job]) {
        for job in jobs { remove(job) }
    }
}
