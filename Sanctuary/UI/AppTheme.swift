import SwiftUI

enum AppTheme {
    static let gradientTop = Color(hex: "#081724")
    static let gradientMid = Color(hex: "#0D3547")
    static let gradientBottom = Color(hex: "#031018")
    static let glowBlue = Color(hex: "#4CB6D8")
    static let glowGold = Color(hex: "#E5C66A")
    static let glowRose = Color(hex: "#C78BB8")

    static let primaryButtonTop = Color(hex: "#3E9FC1")
    static let primaryButtonBottom = Color(hex: "#195E78")
    static let primaryButtonText = Color.white
    static let purpleButton = Color(hex: "#2B728D")
    static let purpleOutline = Color(hex: "#7CC7DE")
    static let cardBackground = Color(hex: "#102738").opacity(0.84)
    static let cardBackgroundSoft = Color.white.opacity(0.08)
    static let cardText = Color.white
    static let subtitleText = Color.white.opacity(0.74)

    static let tabBackground = Color(hex: "#08131D").opacity(0.86)
    static let tabBorder = Color(hex: "#2A5B70")
    static let tabInactive = Color(hex: "#A5C4D0")
    static let tabActive = Color(hex: "#8EE0F2")

    static let advent = Color(hex: "#7858B9")
    static let christmas = Color(hex: "#DCB969")
    static let lent = Color(hex: "#9B5087")
    static let easter = Color(hex: "#F5F5FA")
    static let ordinary = Color(hex: "#3C9B5F")
    static let todayHighlight = Color(hex: "#F2CF63")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMid, gradientBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [primaryButtonTop, primaryButtonBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Single source of truth for liturgical season -> UI border color mapping.
    // This is intentionally separate from decorative legend colors so seasonal
    // borders can follow the required canonical mapping.
    static func liturgicalBorderColor(for season: LiturgicalSeason) -> Color {
        switch season {
        case .advent:
            return advent
        case .christmas:
            return .white
        case .lent:
            return lent
        case .easter:
            return .white
        case .ordinary:
            return ordinary
        }
    }
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient

            Circle()
                .fill(AppTheme.glowBlue.opacity(0.24))
                .frame(width: 340, height: 340)
                .blur(radius: 18)
                .offset(x: 110, y: -240)

            Circle()
                .fill(AppTheme.glowGold.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 22)
                .offset(x: -130, y: -40)

            Circle()
                .fill(AppTheme.glowRose.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 26)
                .offset(x: 120, y: 260)

            LinearGradient(
                colors: [Color.white.opacity(0.09), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct AppGlassCardStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.white.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
            )
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(AppGlassCardStyle(cornerRadius: cornerRadius))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.rounded(16, weight: .semibold))
            .foregroundStyle(AppTheme.primaryButtonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                AppTheme.primaryButtonGradient
                    .opacity(configuration.isPressed ? 0.82 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .shadow(color: AppTheme.glowBlue.opacity(configuration.isPressed ? 0.12 : 0.28), radius: 14, x: 0, y: 10)
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.rounded(16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackgroundSoft.opacity(configuration.isPressed ? 0.9 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.purpleOutline.opacity(0.6), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}

struct TopActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(AppTheme.rounded(13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                Text(title)
                    .font(AppTheme.rounded(12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.cardBackgroundSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
