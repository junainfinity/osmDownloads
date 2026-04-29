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
    case sidebar    = "sidebar.left"
    case info       = "info.circle"
    case code       = "curlybraces"
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

/// Source-aware icon used in cards and lists.
struct SourceIcon: View {
    let source: Source
    var size: CGFloat = 16

    var body: some View {
        switch source {
        case .huggingFace:
            Image("SourceHuggingFace")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel("Hugging Face")
        case .github:
            Image("SourceGitHub")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel("GitHub")
        case .generic:
            Icon(icon: .globe, size: size, color: Theme.text2)
        }
    }
}
