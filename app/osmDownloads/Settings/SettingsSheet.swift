import SwiftUI

// TODO: M6 — full settings form (destination, max concurrent, retry counts,
// theme, density, HF/GH tokens via KeychainService).
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(GhostButtonStyle(compact: true))
            }
            Text("Settings UI lands in M6. Defaults from SettingsStore are already in effect.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text3)
        }
        .padding(20)
        .frame(width: 480, height: 280)
        .background(Theme.surface)
    }
}
