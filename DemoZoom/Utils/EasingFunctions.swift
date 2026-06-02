import Foundation

enum EasingFunctions {
    static func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = (2 * t - 2)
            return 1 - (f * f * f) / 2
        }
    }

    static func lerp(from: Double, to: Double, t: Double) -> Double {
        return from + (to - from) * t
    }

    static func lerpPoint(from: CGPoint, to: CGPoint, t: Double) -> CGPoint {
        return CGPoint(
            x: lerp(from: from.x, to: to.x, t: t),
            y: lerp(from: from.y, to: to.y, t: t)
        )
    }

    static func lerpSize(from: CGSize, to: CGSize, t: Double) -> CGSize {
        return CGSize(
            width: lerp(from: from.width, to: to.width, t: t),
            height: lerp(from: from.height, to: to.height, t: t)
        )
    }
}
