import SwiftUI

enum AppIcon: String {
    case download   = "arrow.down.to.line"
    case pause      = "pause.fill"
    case play       = "play.fill"
    case stop       = "xmark"
    case more       = "ellipsis"
    case folder     = "folder"
    case folderOpen = "folder.fill"
    case clock      = "clock"
    case inbox      = "tray"
    case settings   = "gearshape"
    case sun        = "sun.max"
    case moon       = "moon"
    case search     = "magnifyingglass"
    case checkOn    = "checkmark.square.fill"
    case checkOff   = "square"
    case chevronRight = "chevron.right"
    case chevronDown  = "chevron.down"
    case warn       = "exclamationmark.triangle"
    case link       = "link"
    case globe      = "globe"
    case refresh    = "arrow.clockwise"
    case trash      = "trash"
    case github     = "chevron.left.forwardslash.chevron.right"
}

/// Lightweight SF Symbols wrapper. Pass a size and tint; falls back to text2.
struct Icon: View {
    let icon: AppIcon
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var color: Color = Theme.text2

    var body: some View {
        Image(systemName: icon.rawValue)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}

/// Hugging Face glyph: yellow nucleus + 2 rotated warm strokes. Approximation of
/// the SVG in the prototype's icons.jsx.
struct HuggingFaceGlyph: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Capsule()
                .stroke(Theme.text, lineWidth: max(1, size * 0.06))
                .frame(width: size * 0.95, height: size * 0.55)
                .rotationEffect(.degrees(-20))
            Capsule()
                .stroke(Theme.text, lineWidth: max(1, size * 0.06))
                .frame(width: size * 0.95, height: size * 0.55)
                .rotationEffect(.degrees(20))
            Circle()
                .fill(Theme.accent)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

/// Source-aware icon used in cards and lists.
struct SourceIcon: View {
    let source: Source
    var size: CGFloat = 16

    var body: some View {
        switch source {
        case .huggingFace:
            HuggingFaceGlyph(size: size)
        case .github:
            Icon(icon: .github, size: size, weight: .semibold, color: Theme.text)
        case .generic:
            Icon(icon: .globe, size: size, color: Theme.text2)
        }
    }
}
