import SwiftUI

/// Thin capsule progress bar with accent fill. Pass `progress = nil` for an
/// indeterminate bar (queued jobs).
struct ProgressBar: View {
    let progress: Double?
    var height: CGFloat = 6

    @State private var indetOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surface3)

                if let progress {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(0, min(1, progress)) * w)
                        .animation(.linear(duration: Theme.progressFill), value: progress)
                } else {
                    Capsule()
                        .fill(Theme.accent.opacity(0.6))
                        .frame(width: w * 0.25)
                        .offset(x: indetOffset * w)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                                indetOffset = 4
                            }
                        }
                        .clipShape(Capsule())
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}
