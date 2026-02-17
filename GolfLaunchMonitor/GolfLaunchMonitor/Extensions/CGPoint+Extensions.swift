import CoreGraphics

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    func angle(to other: CGPoint) -> CGFloat {
        atan2(other.y - y, other.x - x)
    }

    func midpoint(to other: CGPoint) -> CGPoint {
        CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }

    func offset(by vector: CGVector) -> CGPoint {
        CGPoint(x: x + vector.dx, y: y + vector.dy)
    }

    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}

extension CGVector {
    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var normalized: CGVector {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return CGVector(dx: dx / mag, dy: dy / mag)
    }

    var angleDegrees: Double {
        Double(atan2(dy, dx) * 180.0 / .pi)
    }

    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
}
