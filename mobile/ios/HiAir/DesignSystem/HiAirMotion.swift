import Foundation
import SwiftUI

enum HiAirMotion {
    static let press: Double = 0.13
    static let fast: Double = 0.20
    static let normal: Double = 0.27
    static let cardEntrance: Double = 0.30
    static let chart: Double = 0.70
    static let riskScore: Double = 0.80
    static let heroMorph: Double = 0.8
    static let orbBreath: Double = 5.0
    static let backgroundDrift: Double = 16.0

    static let orbPulseLow: Double = 5.0
    static let orbPulseModerate: Double = 4.2
    static let orbPulseHigh: Double = 3.4
    static let orbPulseVeryHigh: Double = 2.6

    static let pressScale: CGFloat = 0.978

    static let springBouncy = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let springSnappy = Animation.spring(response: 0.22, dampingFraction: 0.90)
    static let springGentle = Animation.spring(response: 0.55, dampingFraction: 0.92)
    static let materialize = Animation.spring(response: 0.48, dampingFraction: 0.86)
    static let tabChange = Animation.easeInOut(duration: normal)
    static let chipSelect = Animation.easeInOut(duration: fast)
}
