import SwiftUI

// Native LEAGUEPILOT AI design tokens.
// Add this file to the LeaguePilotAI application target or merge its values into Theme.swift.

extension Color {
    init(lpHex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((lpHex >> 16) & 0xFF) / 255,
            green: Double((lpHex >> 8) & 0xFF) / 255,
            blue: Double(lpHex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum LPColor {
    static let background = Color(lpHex: 0xF3EFE5)
    static let card = Color(lpHex: 0xFFFDF8)
    static let primary = Color(lpHex: 0x1D5949)
    static let highlight = Color(lpHex: 0x2F7A63)
    static let text = Color(lpHex: 0x17221F)
    static let border = Color(lpHex: 0xD7D1C6)
    static let muted = Color(lpHex: 0x6E7772)
    static let lime = Color(lpHex: 0xB8DC73)
    static let softGreen = Color(lpHex: 0xE7F0EB)
    static let limeWash = Color(lpHex: 0xE7F1D2)
    static let warningSurface = Color(lpHex: 0xF7EAD8)
    static let warningText = Color(lpHex: 0x7D512F)
    static let errorSurface = Color(lpHex: 0xF8E6E2)
    static let error = Color(lpHex: 0xB54C45)
    static let success = Color(lpHex: 0x2F7A63)
}

enum LPSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum LPRadius {
    static let field: CGFloat = 11
    static let button: CGFloat = 12
    static let card: CGFloat = 16
    static let hero: CGFloat = 18
    static let sheet: CGFloat = 24
    static let pill: CGFloat = 999
}

enum LPType {
    static let screenTitle = Font.system(size: 22, weight: .bold, design: .default)
    static let heroTitle = Font.system(size: 25, weight: .bold, design: .default)
    static let sectionTitle = Font.system(size: 17, weight: .bold, design: .default)
    static let cardTitle = Font.system(size: 14, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let supporting = Font.system(size: 13, weight: .regular, design: .default)
    static let metadata = Font.system(size: 11, weight: .medium, design: .default)
    static let overline = Font.system(size: 11, weight: .bold, design: .default)
    static let button = Font.system(size: 15, weight: .semibold, design: .default)
}

struct LPCardSurface: ViewModifier {
    var radius: CGFloat = LPRadius.card
    var padding: CGFloat = LPSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(LPColor.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LPColor.border, lineWidth: 1)
            }
    }
}

extension View {
    func lpCard(radius: CGFloat = LPRadius.card, padding: CGFloat = LPSpacing.md) -> some View {
        modifier(LPCardSurface(radius: radius, padding: padding))
    }
}

