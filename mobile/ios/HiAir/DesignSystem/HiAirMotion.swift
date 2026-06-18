import Foundation
import SwiftUI

enum HiAirMotion {
    static let fast: Double = 0.24
    static let normal: Double = 0.32
    static let heroMorph: Double = 0.8
    static let orbPulseLow: Double = 4.0
    static let orbPulseModerate: Double = 2.8
    static let orbPulseHigh: Double = 2.0
    static let orbPulseVeryHigh: Double = 1.5

    /// Liquid Glass spring curves (snappy press, bouncy appear).
    static let springBouncy = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let springSnappy = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let springGentle = Animation.spring(response: 0.55, dampingFraction: 0.92)
    static let materialize = Animation.spring(response: 0.48, dampingFraction: 0.84)
}
