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
    static let canvas = Color(hex: "FAF6EE")       // warm cream background
    static let card = Color(hex: "FFFFFF")         // soft off-white cards
    static let border = Color(hex: "E8DFCE")       // soft beige borders
    static let forest = Color(hex: "1F4730")       // primary buttons + headers
    static let forestPressed = Color(hex: "173423")
    static let emerald = Color(hex: "2F9E6A")      // positive accents
    static let lime = Color(hex: "C9E265")         // subtle highlights
    static let ink = Color(hex: "16211A")          // near-black text
    static let inkSecondary = Color(hex: "5C6B60") // secondary text
    static let clay = Color(hex: "C0532F")         // disconnected / danger
}
