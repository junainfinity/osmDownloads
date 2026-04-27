import SwiftData
import SwiftUI

// TODO: M4 — render queued-only jobs with proper queue-position UI.
struct QueueView: View {
    @Query(filter: #Predicate<Job> { $0.statusRaw == "queued" }) private var queuedJobs: [Job]

    var body: some View {
        VStack {
            if queuedJobs.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface2)
                        Icon(icon: .inbox, size: 22, color: Theme.text3)
                    }
                    .frame(width: 56, height: 56)
                    Text("Queue is empty")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Jobs waiting their turn will appear here.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(queuedJobs) { job in
                            JobCard(job: job)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }
            }
        }
        .background(Theme.bg)
    }
}
