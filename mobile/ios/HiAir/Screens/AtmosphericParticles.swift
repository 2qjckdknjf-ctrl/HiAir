import SwiftUI

struct ParticleConfig {
    let count: Int
    let opacity: ClosedRange<Double>
    let speed: Double
}

func particleConfig(pm25: Double) -> ParticleConfig {
    switch pm25 {
    case ..<15:
        return ParticleConfig(count: 3, opacity: 0.08...0.18, speed: 0.22)
    case ..<35:
        return ParticleConfig(count: 5, opacity: 0.14...0.28, speed: 0.18)
    case ..<55:
        return ParticleConfig(count: 7, opacity: 0.20...0.34, speed: 0.14)
    default:
        return ParticleConfig(count: 8, opacity: 0.24...0.40, speed: 0.10)
    }
}

struct AtmosphericParticles: View {
    let pm25: Double
    let tint: Color

    private func point(seed: Int, t: Double, size: CGSize) -> CGPoint {
        let x = (sin(Double(seed) * 1.73 + t * 0.42) * 0.5 + 0.5) * size.width
        let y = (cos(Double(seed) * 2.11 + t * 0.35) * 0.5 + 0.5) * size.height
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let config = particleConfig(pm25: pm25)
            let t = timeline.date.timeIntervalSinceReferenceDate * config.speed
            Canvas { context, size in
                for idx in 0..<config.count {
                    let p = point(seed: idx + 1, t: t, size: size)
                    let radius = CGFloat(1.5 + Double(idx % 3))
                    let alpha = config.opacity.lowerBound + (Double(idx) / Double(max(config.count, 1))) * (config.opacity.upperBound - config.opacity.lowerBound)
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x, y: p.y, width: radius, height: radius)),
                        with: .color(tint.opacity(alpha))
                    )
                }
            }
        }
    }
}
