import Foundation
import CoreGraphics

// MARK: - Raw Tracking Data

struct TrackingPoint: Codable {
    let position: CGPoint
    let timestamp: Double  // seconds from shot start
    let confidence: Float
}

struct TrackingData: Codable {
    var ballPoints: [TrackingPoint] = []
    var clubPoints: [TrackingPoint] = []
    var impactFrame: Int = 0
    var frameRate: Double = 240.0
    var pixelsPerInch: Double = 1.0  // calibration factor
}

// MARK: - Computed Metrics

struct LaunchMetrics: Codable {
    /// Ball speed in mph
    var ballSpeed: Double

    /// Club head speed in mph
    var clubSpeed: Double

    /// Smash factor = ball speed / club speed (dimensionless)
    var smashFactor: Double

    /// Spin rate in RPM (backspin positive, sidespin represented by spinAxis)
    var spinRate: Double

    /// Spin axis tilt in degrees (positive = draw/right-to-left for RH golfer)
    var spinAxis: Double

    /// Launch angle in degrees above horizontal (positive = upward)
    var launchAngle: Double

    /// Launch direction in degrees from target line
    /// Positive = right of target (fade for RH), Negative = left (draw)
    var launchDirection: Double

    /// Club path in degrees relative to target line
    /// Positive = out-to-in (fade/slice), Negative = in-to-out (draw/hook)
    var clubPath: Double

    /// Face angle at impact relative to target line in degrees
    /// Positive = open (right for RH), Negative = closed (left for RH)
    var faceAngle: Double

    /// Face-to-path ratio (face angle relative to club path)
    var facePath: Double {
        faceAngle - clubPath
    }

    /// Attack angle in degrees (positive = ascending, negative = descending)
    var attackAngle: Double

    /// Carry distance estimate in yards
    var carryDistance: Double

    /// Confidence 0.0 - 1.0 for each metric
    var confidence: MetricConfidence

    // MARK: - Quality Ratings

    enum Quality: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case average = "Average"
        case poor = "Poor"
    }

    func smashFactorQuality(for club: ClubType) -> Quality {
        let range = club.smashFactorRange
        if smashFactor >= range.upperBound * 0.98 { return .excellent }
        if smashFactor >= range.lowerBound + (range.upperBound - range.lowerBound) * 0.5 { return .good }
        if smashFactor >= range.lowerBound { return .average }
        return .poor
    }
}

struct MetricConfidence: Codable {
    var ballSpeed: Float = 0.0
    var clubSpeed: Float = 0.0
    var spinRate: Float = 0.0
    var launchAngle: Float = 0.0
    var clubPath: Float = 0.0
    var faceAngle: Float = 0.0

    var overall: Float {
        (ballSpeed + clubSpeed + spinRate + launchAngle + clubPath + faceAngle) / 6.0
    }
}

// MARK: - Shot Data

struct ShotData: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let club: ClubType
    let metrics: LaunchMetrics
    let trackingData: TrackingData
    var notes: String

    // Shot outcome classification
    var shotShape: ShotShape {
        let ftp = metrics.facePath
        let path = metrics.clubPath
        if abs(ftp) < 2.0 && abs(path) < 2.0 { return .straight }
        if ftp < -2.0 && path < 0 { return .draw }
        if ftp < -4.0 && path < -2.0 { return .hook }
        if ftp > 2.0 && path > 0 { return .fade }
        if ftp > 4.0 && path > 2.0 { return .slice }
        if ftp < 0 { return .draw }
        return .fade
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), club: ClubType,
         metrics: LaunchMetrics, trackingData: TrackingData, notes: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.club = club
        self.metrics = metrics
        self.trackingData = trackingData
        self.notes = notes
    }
}

enum ShotShape: String, Codable {
    case straight = "Straight"
    case draw = "Draw"
    case hook = "Hook"
    case fade = "Fade"
    case slice = "Slice"

    var color: String {
        switch self {
        case .straight: return "white"
        case .draw, .hook: return "blue"
        case .fade, .slice: return "red"
        }
    }

    var description: String {
        switch self {
        case .straight: return "Straight"
        case .draw: return "Draw"
        case .hook: return "Hook"
        case .fade: return "Fade"
        case .slice: return "Slice"
        }
    }
}

// MARK: - Extensions

extension LaunchMetrics {
    static var empty: LaunchMetrics {
        LaunchMetrics(
            ballSpeed: 0,
            clubSpeed: 0,
            smashFactor: 0,
            spinRate: 0,
            spinAxis: 0,
            launchAngle: 0,
            launchDirection: 0,
            clubPath: 0,
            faceAngle: 0,
            attackAngle: 0,
            carryDistance: 0,
            confidence: MetricConfidence()
        )
    }

    static var sample: LaunchMetrics {
        LaunchMetrics(
            ballSpeed: 167.2,
            clubSpeed: 112.4,
            smashFactor: 1.488,
            spinRate: 2650,
            spinAxis: 3.2,
            launchAngle: 13.4,
            launchDirection: 1.8,
            clubPath: -1.2,
            faceAngle: 0.8,
            attackAngle: -1.5,
            carryDistance: 287,
            confidence: MetricConfidence(
                ballSpeed: 0.88,
                clubSpeed: 0.85,
                spinRate: 0.72,
                launchAngle: 0.91,
                clubPath: 0.82,
                faceAngle: 0.76
            )
        )
    }
}
