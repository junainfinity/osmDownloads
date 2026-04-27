import SwiftUI

struct StatusPill: View {
    let status: JobStatus

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 0.35 : 1)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(bgColor)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel(label)
        .onAppear {
            if status == .downloading && !reduceMotion {
                withAnimation(.easeInOut(duration: Theme.pulseDuration).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var showDot: Bool { status == .downloading }
    private var label: String {
        switch status {
        case .queued:      return "Queued"
        case .resolving:   return "Resolving"
        case .downloading: return "Downloading"
        case .paused:      return "Paused"
        case .completed:   return "Completed"
        case .failed:      return "Failed"
        case .canceled:    return "Canceled"
        }
    }
    private var bgColor: Color {
        switch status {
        case .downloading: return Theme.accentSoft
        case .completed:   return Theme.success.opacity(0.18)
        case .failed:      return Theme.danger.opacity(0.18)
        case .paused:      return Theme.surface3
        case .canceled:    return Theme.surface3
        case .queued, .resolving: return Theme.surface3
        }
    }
    private var textColor: Color {
        switch status {
        case .downloading: return Theme.accentInk
        case .completed:   return Theme.success
        case .failed:      return Theme.danger
        default:           return Theme.text2
        }
    }
    private var dotColor: Color {
        switch status {
        case .downloading: return Theme.accentInk
        default:           return Theme.text2
        }
    }
}
