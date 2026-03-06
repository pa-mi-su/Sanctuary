import SwiftUI

enum AppTheme {
    static let gradientTop = Color(hex: "#17324A")
    static let gradientMid = Color(hex: "#0F4C5C")
    static let gradientBottom = Color(hex: "#0B1320")

    static let purpleButton = Color(hex: "#6A4F95")
    static let purpleOutline = Color(hex: "#7A629C")
    static let cardBackground = Color(hex: "#ECEAF0")
    static let cardText = Color(hex: "#1F2430")
    static let subtitleText = Color.white.opacity(0.82)

    static let tabBackground = Color(hex: "#0B1320")
    static let tabBorder = Color(hex: "#1E2D45")
    static let tabInactive = Color(hex: "#9BA1A6")
    static let tabActive = Color(hex: "#00A3D9")

    static let advent = Color(hex: "#7858B9")
    static let christmas = Color(hex: "#DCB969")
    static let lent = Color(hex: "#9B5087")
    static let easter = Color(hex: "#F5F5FA")
    static let ordinary = Color(hex: "#3C9B5F")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMid, gradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
            .font(AppTheme.rounded(13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.purpleButton.opacity(configuration.isPressed ? 0.82 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.rounded(13, weight: .semibold))
            .foregroundStyle(AppTheme.purpleButton)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.purpleOutline, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

struct TopActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppTheme.rounded(13, weight: .semibold))
                Text(title)
                    .font(AppTheme.rounded(12, weight: .semibold))
            }
            .foregroundStyle(Color.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(AppTheme.purpleButton.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
