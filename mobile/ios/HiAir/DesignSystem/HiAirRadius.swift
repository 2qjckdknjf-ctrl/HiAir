import CoreGraphics

enum HiAirRadius {
    static let pill: CGFloat = 999
    static let sm: CGFloat = 8
    static let chip: CGFloat = 13
    static let md: CGFloat = 16
    static let compact: CGFloat = 16
    static let lg: CGFloat = 20
    static let hero: CGFloat = 24
    static let xl: CGFloat = 28
    static let navCapsule: CGFloat = 32
    static let tabBar: CGFloat = 30
    static let cta: CGFloat = 20

    /// Concentric corner radius: inner = outer − padding (Liquid Glass rule).
    static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(outer - padding, sm)
    }
}
