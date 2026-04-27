import SwiftUI

/// Design tokens lifted from the prototype's styles.css. Light + dark variants
/// are picked at the call site via `Color(light:dark:)`.
enum Theme {
    // Surfaces
    static let bg          = Color(light: 0xFAF8F4, dark: 0x0F0E0C)
    static let surface     = Color(light: 0xFFFFFF, dark: 0x1A1815)
    static let surface2    = Color(light: 0xF4F1EA, dark: 0x221F1B)
    static let surface3    = Color(light: 0xECE7DC, dark: 0x2C2823)

    // Borders
    static let border       = Color(light: 0xE4DED1, dark: 0x2E2A24)
    static let borderStrong = Color(light: 0xD5CCB8, dark: 0x423C32)

    // Text
    static let text  = Color(light: 0x2A2620, dark: 0xF2EDE2)
    static let text2 = Color(light: 0x5C544A, dark: 0xB4AD9F)
    static let text3 = Color(light: 0x8A8175, dark: 0x807868)

    // Accent
    static let accent      = Color(red: 1.0, green: 0.867, blue: 0.333)        // #FFDD55
    static let accentInk   = Color(light: 0x2A2620, dark: 0x1A1815)
    static let accentSoft  = Color(light: 0xFFF4C4, dark: 0x3A3318)

    // Semantic
    static let success = Color(light: 0x4F7A4A, dark: 0x8FBA89)
    static let danger  = Color(light: 0xB6452C, dark: 0xE27A5E)
    static let info    = Color(light: 0x4D6E8C, dark: 0x88AECB)

    // Radii
    static let radiusSm: CGFloat = 6
    static let radius:   CGFloat = 10
    static let radiusLg: CGFloat = 14

    // Animation
    static let pulseDuration: Double = 1.4
    static let progressFill:  Double = 0.3
    static let popIn:         Double = 0.25
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return Color.nsColor(from: isDark ? dark : light)
        })
    }

    fileprivate static func nsColor(from hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
