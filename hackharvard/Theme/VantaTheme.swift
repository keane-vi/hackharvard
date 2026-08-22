import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum VantaTheme {
    static let background = Color(hex: 0x04143E)
    static let surface = Color(hex: 0x022560)
    static let accent = Color(hex: 0x31C4B1)
    static let gaugeGradientStart = Color(hex: 0x25B5B8)
    static let gaugeGradientEnd = Color(hex: 0x31C4B1)
    static let highlight = Color(hex: 0xF6AE37)
    static let textPrimary = Color(hex: 0xFBF3E5)
    static let textMuted = Color(hex: 0xFBF3E5, opacity: 0.6)
    static let border = Color(hex: 0x25B5B8, opacity: 0.25)
}
