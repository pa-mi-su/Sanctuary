import CoreGraphics

enum ResponsiveLayout {
    // iPhone 12/13/14 width baseline.
    private static let baseWidth: CGFloat = 390

    static func scale(for width: CGFloat) -> CGFloat {
        let raw = width / baseWidth
        return min(max(raw, 0.86), 1.14)
    }

    static func value(_ base: CGFloat, width: CGFloat) -> CGFloat {
        base * scale(for: width)
    }
}
