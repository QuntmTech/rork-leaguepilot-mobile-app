import SwiftUI

extension Color {
    /// Creates a color from a hex string like "1F4730".
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

/// App-wide palette: warm cream canvas, forest-green primaries, emerald/lime accents.
enum Theme {
    static let canvas = Color(hex: "F3EFE5")
    static let card = Color(hex: "FFFDF8")
    static let border = Color(hex: "D7D1C6")
    static let forest = Color(hex: "1D5949")
    static let forestPressed = Color(hex: "174638")
    static let emerald = Color(hex: "2F7A63")
    static let lime = Color(hex: "B8DC73")
    static let ink = Color(hex: "17221F")
    static let inkSecondary = Color(hex: "6E7772")
    static let clay = Color(hex: "C0532F")         // disconnected / danger
}
