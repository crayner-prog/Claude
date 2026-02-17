import Foundation
import CoreGraphics

// MARK: - Calibration Data

struct CalibrationData {
    /// Pixels per inch at current zoom and distance
    var pixelsPerInch: Double

    /// Known reference object length in inches (default: driver = 45.5")
    var referenceObjectInches: Double

    /// Camera frame rate (fps)
    var frameRate: Double

    /// Camera height offset from ground (inches) for attack angle correction
    var cameraHeightInches: Double = 36.0

    /// Distance from camera to impact point (inches) for perspective correction
    var distanceToImpactInches: Double = 120.0  // ~10 feet

    init(referencePixels: Double, referenceInches: Double, frameRate: Double) {
        self.pixelsPerInch = referencePixels / referenceInches
        self.referenceObjectInches = referenceInches
        self.frameRate = frameRate
    }

    static var `default`: CalibrationData {
        // Default: assumes club shaft (~45 inches) spans about 300 pixels
        CalibrationData(referencePixels: 300, referenceInches: 45.5, frameRate: 240)
    }
}

// MARK: - Metrics Calculator

class MetricsCalculator {
    private let calibration: CalibrationData

    // Physical constants
    private let pixelsPerSecondToMPH: Double  // conversion factor
    private let gravitationalDecel: Double = 9.8  // m/s^2

    init(calibration: CalibrationData = .default) {
        self.calibration = calibration
        // 1 pixel/frame × frameRate frames/sec ÷ pixelsPerInch in/pixel ÷ 12 ft/in × 3600 sec/hr ÷ 5280 ft/mi
        self.pixelsPerSecondToMPH = calibration.frameRate /
                                    calibration.pixelsPerInch /
                                    12.0 *
                                    3600.0 /
                                    5280.0
    }

    // MARK: - Main Calculation

    func calculateMetrics(
        ballTracker: BallTracker,
        clubTracker: ClubTracker,
        club: ClubType
    ) -> LaunchMetrics {
        let ballSpeed = calculateBallSpeed(from: ballTracker)
        let clubSpeed = calculateClubSpeed(from: clubTracker)
        let smashFactor = calculateSmashFactor(ballSpeed: ballSpeed, clubSpeed: clubSpeed)
        let launchAngle = calculateLaunchAngle(from: ballTracker, club: club)
        let launchDirection = calculateLaunchDirection(from: ballTracker)
        let clubPath = calculateClubPath(from: clubTracker)
        let faceAngle = calculateFaceAngle(clubPath: clubPath, launchDirection: launchDirection)
        let attackAngle = calculateAttackAngle(from: clubTracker, club: club)
        let spinRate = calculateSpinRate(
            ballSpeed: ballSpeed,
            clubSpeed: clubSpeed,
            launchAngle: launchAngle,
            faceAngle: faceAngle,
            attackAngle: attackAngle,
            club: club
        )
        let spinAxis = calculateSpinAxis(clubPath: clubPath, faceAngle: faceAngle)
        let carryDistance = calculateCarryDistance(
            ballSpeed: ballSpeed,
            launchAngle: launchAngle,
            spinRate: spinRate
        )

        let confidence = MetricConfidence(
            ballSpeed: ballTracker.averageConfidence,
            clubSpeed: clubTracker.averageConfidence,
            spinRate: 0.65,  // Estimated, not directly measured
            launchAngle: ballTracker.averageConfidence * 0.9,
            clubPath: clubTracker.averageConfidence * 0.85,
            faceAngle: clubTracker.averageConfidence * 0.75
        )

        return LaunchMetrics(
            ballSpeed: ballSpeed,
            clubSpeed: clubSpeed,
            smashFactor: smashFactor,
            spinRate: spinRate,
            spinAxis: spinAxis,
            launchAngle: launchAngle,
            launchDirection: launchDirection,
            clubPath: clubPath,
            faceAngle: faceAngle,
            attackAngle: attackAngle,
            carryDistance: carryDistance,
            confidence: confidence
        )
    }

    // MARK: - Individual Metric Calculations

    /// Ball speed in mph from pixel velocity
    func calculateBallSpeed(from tracker: BallTracker) -> Double {
        guard let velocity = tracker.impactVelocity(frameRate: calibration.frameRate) else {
            return 0
        }
        let pixelsPerFrame = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let pixelsPerSecond = pixelsPerFrame * calibration.frameRate
        let mph = pixelsPerSecond * pixelsPerSecondToMPH

        // Sanity clamp: ball speed range 0-220mph (max pro tour ~185mph)
        return max(0, min(220, mph))
    }

    /// Club speed in mph
    func calculateClubSpeed(from tracker: ClubTracker) -> Double {
        guard let speedPixPerSec = tracker.impactSpeed() else {
            return 0
        }
        let mph = speedPixPerSec * pixelsPerSecondToMPH

        // Sanity clamp: club speed range 0-140mph
        return max(0, min(140, mph))
    }

    /// Smash factor = ball speed / club speed
    func calculateSmashFactor(ballSpeed: Double, clubSpeed: Double) -> Double {
        guard clubSpeed > 0 else { return 0 }
        let sf = ballSpeed / clubSpeed
        // Smash factor is physically limited to ~1.5 by rules of physics
        return max(0, min(1.56, sf))
    }

    /// Launch angle in degrees
    func calculateLaunchAngle(from tracker: BallTracker, club: ClubType) -> Double {
        if let measuredAngle = tracker.launchAngleDegrees() {
            // Apply perspective correction based on camera angle
            let corrected = measuredAngle * perspectiveCorrectionFactor()
            return max(0, min(60, corrected))
        }
        // Fallback: estimate from club loft
        return club.typicalLoft * 0.65
    }

    /// Launch direction in degrees left/right of target
    func calculateLaunchDirection(from tracker: BallTracker) -> Double {
        tracker.launchDirectionDegrees() ?? 0
    }

    /// Club path in degrees (+ = out-to-in/fade, - = in-to-out/draw)
    func calculateClubPath(from tracker: ClubTracker) -> Double {
        tracker.clubPathDegrees() ?? 0
    }

    /// Face angle in degrees (+ = open/right, - = closed/left)
    func calculateFaceAngle(clubPath: Double, launchDirection: Double) -> Double {
        // Face angle is the primary driver of initial ball direction
        // Ball starts ~75-80% toward face angle from club path
        // Face angle ≈ launchDirection / 0.75 (working backwards from D-plane)
        return launchDirection / 0.75
    }

    /// Attack angle in degrees (+ = ascending, - = descending)
    func calculateAttackAngle(from tracker: ClubTracker, club: ClubType) -> Double {
        // Estimate from club movement trajectory near impact
        let analysisPoints = tracker.preImpactPoints.suffix(6)
        guard analysisPoints.count >= 2 else {
            // Default by club type
            switch club.category {
            case "Woods": return -1.3
            case "Irons": return -4.0
            case "Wedges": return -6.0
            default: return -3.0
            }
        }

        let pts = Array(analysisPoints)
        var sumDy = 0.0
        var sumDx = 0.0
        var count = 0

        for i in 1..<pts.count {
            let dt = pts[i].timestamp - pts[i-1].timestamp
            guard dt > 0 else { continue }
            sumDy += Double(pts[i].position.y - pts[i-1].position.y)
            sumDx += Double(pts[i].position.x - pts[i-1].position.x)
            count += 1
        }

        guard count > 0, abs(sumDx) > 0.001 else { return -3.0 }

        // In camera coords Y increases downward
        // Negative dy = club moving up = ascending attack
        let angleRad = atan2(-sumDy, abs(sumDx))
        let angleDeg = angleRad * 180.0 / .pi
        return max(-15, min(5, angleDeg))
    }

    // MARK: - Spin Rate Estimation
    // Spin rate cannot be directly measured via optical tracking without special markers.
    // We use a physics-based model from trackable parameters.

    func calculateSpinRate(
        ballSpeed: Double,
        clubSpeed: Double,
        launchAngle: Double,
        faceAngle: Double,
        attackAngle: Double,
        club: ClubType
    ) -> Double {
        // Spin rate model based on golf physics:
        // Spin ≈ (dynamic loft - attack angle) × spin_loft_factor × gear_effect
        let dynamicLoft = club.typicalLoft + attackAngle * 0.5
        let spinLoft = dynamicLoft - attackAngle
        let gearEffect = 1.0 + abs(faceAngle) * 0.02

        // Base spin from impact conditions
        var baseSpin: Double
        switch club.category {
        case "Woods":
            baseSpin = spinLoft * 180 + ballSpeed * 8
        case "Hybrids":
            baseSpin = spinLoft * 220 + ballSpeed * 10
        case "Irons":
            baseSpin = spinLoft * 240 + ballSpeed * 12
        case "Wedges":
            baseSpin = spinLoft * 260 + ballSpeed * 15
        default:
            baseSpin = spinLoft * 200 + ballSpeed * 10
        }

        baseSpin *= gearEffect

        // Sanity clamp by club type
        let (minSpin, maxSpin): (Double, Double)
        switch club.category {
        case "Woods":    (minSpin, maxSpin) = (1500, 4000)
        case "Hybrids":  (minSpin, maxSpin) = (3000, 6000)
        case "Irons":    (minSpin, maxSpin) = (4000, 9000)
        case "Wedges":   (minSpin, maxSpin) = (6000, 12000)
        default:         (minSpin, maxSpin) = (1500, 12000)
        }

        return max(minSpin, min(maxSpin, baseSpin))
    }

    /// Spin axis tilt in degrees (+ = draw/right-to-left for RH golfer)
    func calculateSpinAxis(clubPath: Double, faceAngle: Double) -> Double {
        // Spin axis is roughly the average of club path and face angle weighted toward face
        return (clubPath * 0.3 + faceAngle * 0.7) * -1.0
    }

    // MARK: - Carry Distance

    /// Estimated carry distance in yards using simplified ballistic model
    func calculateCarryDistance(
        ballSpeed: Double,
        launchAngle: Double,
        spinRate: Double
    ) -> Double {
        guard ballSpeed > 0, launchAngle > 0 else { return 0 }

        let speedMPS = ballSpeed * 0.44704  // mph to m/s
        let angleRad = launchAngle * .pi / 180.0

        // Initial velocity components
        let vx = speedMPS * cos(angleRad)
        let vy = speedMPS * sin(angleRad)

        // Magnus force coefficient (spin lift)
        let cl = spinRate / 30000.0  // simplified lift coefficient
        let cd = 0.21  // drag coefficient for golf ball

        // Air density at sea level
        let airDensity = 1.225  // kg/m³
        let ballDiameter = 0.04267  // meters (1.68 inches)
        let ballArea = .pi * pow(ballDiameter / 2, 2)
        let ballMass = 0.04593  // kg

        let dragForce = 0.5 * airDensity * cd * ballArea
        let liftForce = 0.5 * airDensity * cl * ballArea

        // Simplified numerical integration
        var x = 0.0, y = 0.0
        var vxc = vx, vyc = vy
        let dt = 0.01

        var maxIterations = 10000
        while y >= 0 && maxIterations > 0 {
            let speed = sqrt(vxc * vxc + vyc * vyc)
            let fx = -dragForce * speed * vxc / ballMass
            let fy = -gravitationalDecel + (liftForce * speed / ballMass) - (dragForce * speed * vyc / ballMass)

            vxc += fx * dt
            vyc += fy * dt
            x += vxc * dt
            y += vyc * dt

            maxIterations -= 1
        }

        // Convert meters to yards
        let yards = x * 1.09361
        return max(0, min(400, yards))
    }

    // MARK: - Helpers

    private func perspectiveCorrectionFactor() -> Double {
        // Correct for camera not being perfectly level at impact zone
        // Based on camera height and distance to ball
        let heightRatio = calibration.cameraHeightInches / calibration.distanceToImpactInches
        return 1.0 + heightRatio * 0.1
    }
}

// MARK: - Formatting Helpers

extension LaunchMetrics {
    func formatted(_ keyPath: KeyPath<LaunchMetrics, Double>, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", self[keyPath: keyPath])
    }
}
