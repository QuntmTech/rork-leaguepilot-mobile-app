import SwiftUI

struct LPBrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundStyle(LPColor.card)
                .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                .background(LPColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("LEAGUEPILOT")
                .font(.system(size: compact ? 11 : 13, weight: .black))
                .foregroundStyle(LPColor.text)

            Text("AI")
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .foregroundStyle(LPColor.highlight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LEAGUEPILOT AI")
    }
}

struct LPPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LPSpacing.xs) {
                if isLoading {
                    ProgressView().tint(LPColor.card)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(LPType.button)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(LPColor.card)
            .background(isDisabled ? LPColor.muted : LPColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: LPRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityAddTraits(.isButton)
    }
}

struct LPSectionHeader: View {
    let overline: String
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(overline.uppercased())
                    .font(LPType.overline)
                    .tracking(1.1)
                    .foregroundStyle(LPColor.highlight)
                Text(title).font(LPType.sectionTitle).foregroundStyle(LPColor.text)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(LPType.metadata)
                    .foregroundStyle(LPColor.primary)
                    .frame(minHeight: 44)
            }
        }
    }
}

struct LPStatusPill: View {
    enum Kind { case connected, warning, error, neutral }
    let text: String
    let systemImage: String
    var kind: Kind = .neutral

    private var colors: (Color, Color) {
        switch kind {
        case .connected: return (LPColor.softGreen, LPColor.success)
        case .warning: return (LPColor.warningSurface, LPColor.warningText)
        case .error: return (LPColor.errorSurface, LPColor.error)
        case .neutral: return (LPColor.background, LPColor.muted)
        }
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(LPType.metadata)
            .foregroundStyle(colors.1)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(colors.0)
            .clipShape(Capsule())
    }
}

struct LPConfidenceBadge: View {
    let value: Int?

    var body: some View {
        Group {
            if let value {
                Text("\(value)% confidence")
            } else {
                Text("Confidence unavailable")
            }
        }
        .font(LPType.metadata)
        .foregroundStyle(LPColor.primary)
        .padding(.horizontal, 9)
        .frame(minHeight: 28)
        .background(LPColor.softGreen)
        .clipShape(Capsule())
        .accessibilityLabel(value.map { "Confidence, \($0) percent" } ?? "Confidence unavailable")
    }
}

struct LPRiskBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(LPType.metadata)
            .foregroundStyle(LPColor.warningText)
            .padding(.horizontal, 9)
            .frame(minHeight: 30)
            .background(LPColor.warningSurface)
            .clipShape(Capsule())
    }
}

struct LPEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: LPSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LPColor.highlight)
                .frame(width: 52, height: 52)
                .background(LPColor.limeWash)
                .clipShape(Circle())
            Text(title).font(LPType.cardTitle).foregroundStyle(LPColor.text)
            Text(message)
                .font(LPType.supporting)
                .foregroundStyle(LPColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LPSpacing.xxl)
        .lpCard()
    }
}

enum LPBottomTab: String, CaseIterable, Identifiable {
    case home, recommendations, reports, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .recommendations: return "sparkles.rectangle.stack"
        case .reports: return "doc.text"
        case .settings: return "gearshape"
        }
    }
}

struct LPBottomNavigationBar: View {
    @Binding var selection: LPBottomTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LPBottomTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? "\(tab.symbol).fill" : tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? LPColor.primary : LPColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .background(LPColor.card)
        .overlay(alignment: .top) { Divider().foregroundStyle(LPColor.border) }
    }
}

