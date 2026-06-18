import CoreGraphics

enum HiAirRadius {
    static let pill: CGFloat = 999
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let navCapsule: CGFloat = 32

    /// Concentric corner radius: inner = outer − padding (Liquid Glass rule).
    static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(outer - padding, sm)
    }
}
