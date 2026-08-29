import SwiftUI

struct LPEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var body: some View { VStack(spacing: 12) { Image(systemName: systemImage).font(.system(size: 24, weight: .semibold)).foregroundStyle(Theme.emerald).frame(width: 52, height: 52).background(Theme.lime.opacity(0.25)).clipShape(Circle()); Text(title).font(.headline).foregroundStyle(Theme.ink); Text(message).font(.subheadline).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 28).leagueCard() }
}

struct LPStatusPill: View {
    enum Kind { case connected, warning, error, neutral }
    let text: String
    let systemImage: String
    var kind: Kind = .neutral
    var body: some View { Label(text, systemImage: systemImage).font(.caption.weight(.semibold)).foregroundStyle(kind == .connected ? Theme.emerald : kind == .error ? Theme.clay : Theme.inkSecondary).padding(.horizontal, 10).frame(minHeight: 28).background((kind == .connected ? Theme.emerald : kind == .error ? Theme.clay : Theme.border).opacity(0.14)).clipShape(Capsule()) }
}

/// Card container shared across screens.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    /// Applies the standard off-white card look with beige border and soft shadow.
    func leagueCard() -> some View { modifier(CardBackground()) }
}

/// Filled forest-green primary button style.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? Theme.forestPressed : Theme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
    }
}

/// Outlined neutral button style for secondary actions (Cancel, Connect ESPN).
struct OutlineButtonStyle: ButtonStyle {
    var stroke: Color = Theme.border
    var textColor: Color = Theme.forest

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.card.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(stroke, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Small rounded status pill.
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}
