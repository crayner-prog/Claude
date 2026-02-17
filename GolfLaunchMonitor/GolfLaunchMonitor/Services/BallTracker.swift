import Vision
import CoreImage
import CoreGraphics
import AVFoundation

// MARK: - Ball Detection State

enum BallTrackingState {
    case idle
    case searching          // Looking for ball in frame
    case detected           // Ball found, initializing tracker
    case tracking           // Actively tracking ball in flight
    case lost               // Tracking lost
    case complete           // Ball out of frame / shot complete
}

// MARK: - Kalman Filter for ball position smoothing

struct KalmanFilter2D {
    var x: Double       // x position
    var y: Double       // y position
    var vx: Double      // x velocity
    var vy: Double      // y velocity

    // Process noise covariance
    var q: Double = 0.01
    // Measurement noise covariance
    var r: Double = 0.1
    // Error covariance
    var p: Double = 1.0

    mutating func predict(dt: Double) {
        x += vx * dt
        y += vy * dt
        p += q
    }

    mutating func update(measuredX: Double, measuredY: Double) -> (x: Double, y: Double) {
        let k = p / (p + r)
        x += k * (measuredX - x)
        y += k * (measuredY - y)
        vx = (measuredX - x) / max(0.001, 1.0)
        vy = (measuredY - y) / max(0.001, 1.0)
        p = (1 - k) * p
        return (x, y)
    }
}

// MARK: - Ball Tracker

class BallTracker {
    private(set) var state: BallTrackingState = .idle
    private(set) var trackingPoints: [TrackingPoint] = []
    private(set) var currentBoundingBox: CGRect = .zero
    private(set) var detectionConfidence: Float = 0.0

    private var trackingRequest: VNTrackObjectRequest?
    private var kalman = KalmanFilter2D(x: 0, y: 0, vx: 0, vy: 0)
    private var lastTimestamp: Double = 0
    private var frameCount: Int = 0
    private var lostFrameCount: Int = 0
    private let maxLostFrames = 5

    // Detection parameters
    private let minCircleRadius: CGFloat = 5
    private let maxCircleRadius: CGFloat = 30
    private let minWhitenessTreshold: Float = 0.7

    // MARK: - Public API

    func reset() {
        state = .idle
        trackingPoints = []
        currentBoundingBox = .zero
        detectionConfidence = 0
        trackingRequest = nil
        frameCount = 0
        lostFrameCount = 0
        kalman = KalmanFilter2D(x: 0, y: 0, vx: 0, vy: 0)
    }

    /// Process a frame. Call this for every camera frame.
    /// - Returns: tracking point if ball was tracked, nil otherwise
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        frameCount += 1

        switch state {
        case .idle, .searching:
            return searchForBall(in: pixelBuffer, timestamp: timestamp)
        case .detected, .tracking:
            return trackBall(in: pixelBuffer, timestamp: timestamp)
        case .lost:
            lostFrameCount += 1
            if lostFrameCount > maxLostFrames {
                state = .complete
                return nil
            }
            return trackBall(in: pixelBuffer, timestamp: timestamp)
        case .complete:
            return nil
        }
    }

    // MARK: - Ball Detection

    private func searchForBall(in pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        state = .searching

        // Use Vision to detect circular objects (golf ball)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        // Detect contours for circular ball shape
        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 1.5
        contourRequest.detectsDarkOnLight = false

        try? handler.perform([contourRequest])

        if let contours = contourRequest.results?.first {
            if let ballBox = findBallInContours(contours, imageSize: CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )) {
                initializeTracking(boundingBox: ballBox, pixelBuffer: pixelBuffer, timestamp: timestamp)
                let center = CGPoint(x: ballBox.midX, y: ballBox.midY)
                let point = TrackingPoint(position: center, timestamp: timestamp, confidence: 0.8)
                trackingPoints.append(point)
                return point
            }
        }

        return nil
    }

    private func findBallInContours(_ observation: VNContoursObservation,
                                     imageSize: CGSize) -> CGRect? {
        // Look for circular contours that match golf ball dimensions
        var bestMatch: (rect: CGRect, score: Float) = (.zero, 0)

        for i in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }

            let bounds = contour.normalizedPath.boundingBox
            let width = bounds.width * imageSize.width
            let height = bounds.height * imageSize.height

            // Golf ball is roughly circular
            let aspectRatio = width / height
            guard aspectRatio > 0.6 && aspectRatio < 1.6 else { continue }

            // Check size range (golf ball diameter ~1.68 inches, at 10 feet ~50 pixels at typical zoom)
            let radius = (width + height) / 4
            guard radius >= minCircleRadius && radius <= maxCircleRadius else { continue }

            // Score by circularity
            let area = Double(width * height) * .pi / 4
            let perimeter = Double(width + height) * .pi / 2
            let circularity = Float(4 * .pi * area / (perimeter * perimeter))

            if circularity > bestMatch.score {
                let denormRect = CGRect(
                    x: bounds.minX * imageSize.width,
                    y: bounds.minY * imageSize.height,
                    width: width,
                    height: height
                )
                bestMatch = (denormRect, circularity)
            }
        }

        return bestMatch.score > 0.5 ? bestMatch.rect : nil
    }

    // MARK: - Tracking Initialization

    private func initializeTracking(boundingBox: CGRect, pixelBuffer: CVPixelBuffer, timestamp: Double) {
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // Normalize bounding box for Vision
        let normalizedBox = CGRect(
            x: boundingBox.minX / imageWidth,
            y: boundingBox.minY / imageHeight,
            width: boundingBox.width / imageWidth,
            height: boundingBox.height / imageHeight
        )

        let observation = VNDetectedObjectObservation(boundingBox: normalizedBox)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .accurate
        trackingRequest = request

        currentBoundingBox = boundingBox
        kalman = KalmanFilter2D(
            x: Double(boundingBox.midX),
            y: Double(boundingBox.midY),
            vx: 0,
            vy: 0
        )
        lastTimestamp = timestamp
        state = .detected
        lostFrameCount = 0
    }

    // MARK: - Active Tracking

    private func trackBall(in pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        guard let request = trackingRequest else {
            state = .lost
            return nil
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            state = .lost
            return nil
        }

        guard let result = request.results?.first as? VNDetectedObjectObservation else {
            lostFrameCount += 1
            if lostFrameCount > maxLostFrames { state = .lost }
            return nil
        }

        detectionConfidence = result.confidence

        guard result.confidence > 0.3 else {
            lostFrameCount += 1
            if lostFrameCount > maxLostFrames { state = .lost }
            return nil
        }

        lostFrameCount = 0
        state = .tracking

        // Convert normalized coordinates to pixel coordinates
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let denormBox = CGRect(
            x: result.boundingBox.minX * imageWidth,
            y: (1 - result.boundingBox.maxY) * imageHeight,  // Flip Y (Vision uses bottom-left origin)
            width: result.boundingBox.width * imageWidth,
            height: result.boundingBox.height * imageHeight
        )
        currentBoundingBox = denormBox

        // Apply Kalman filter
        let dt = timestamp - lastTimestamp
        kalman.predict(dt: dt)
        let smoothed = kalman.update(measuredX: Double(denormBox.midX), measuredY: Double(denormBox.midY))
        lastTimestamp = timestamp

        // Update tracking request with new observation
        let normalizedSmoothed = CGRect(
            x: CGFloat(smoothed.x) / imageWidth - (denormBox.width / imageWidth / 2),
            y: 1 - (CGFloat(smoothed.y) / imageHeight + (denormBox.height / imageHeight / 2)),
            width: denormBox.width / imageWidth,
            height: denormBox.height / imageHeight
        )

        let updatedObservation = VNDetectedObjectObservation(boundingBox: normalizedSmoothed)
        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: updatedObservation)
        trackingRequest?.trackingLevel = .accurate

        let point = TrackingPoint(
            position: CGPoint(x: smoothed.x, y: smoothed.y),
            timestamp: timestamp,
            confidence: result.confidence
        )
        trackingPoints.append(point)

        // Check if ball has left frame
        if denormBox.maxX > imageWidth * 0.98 || denormBox.maxY > imageHeight * 0.98 ||
           denormBox.minX < imageWidth * 0.02 {
            state = .complete
        }

        return point
    }

    // MARK: - Velocity Analysis

    /// Calculate velocity at impact (first few frames after detection)
    func impactVelocity(frameRate: Double) -> CGVector? {
        let minPoints = 3
        guard trackingPoints.count >= minPoints else { return nil }

        // Use first several points (right after impact) for velocity
        let analysisPoints = Array(trackingPoints.prefix(10))
        guard analysisPoints.count >= 2 else { return nil }

        // Linear regression for stable velocity estimate
        var sumDx = 0.0
        var sumDy = 0.0
        var count = 0

        for i in 1..<analysisPoints.count {
            let dt = analysisPoints[i].timestamp - analysisPoints[i-1].timestamp
            guard dt > 0 else { continue }
            sumDx += Double(analysisPoints[i].position.x - analysisPoints[i-1].position.x) / dt
            sumDy += Double(analysisPoints[i].position.y - analysisPoints[i-1].position.y) / dt
            count += 1
        }

        guard count > 0 else { return nil }
        return CGVector(dx: sumDx / Double(count), dy: sumDy / Double(count))
    }

    /// Trajectory angle from horizontal in degrees
    func launchAngleDegrees() -> Double? {
        guard let velocity = impactVelocity(frameRate: 240) else { return nil }
        // In camera coordinates, Y increases downward, so negate for physics
        let angle = atan2(-velocity.dy, abs(velocity.dx)) * 180.0 / .pi
        return angle
    }

    /// Horizontal launch direction from camera target line
    func launchDirectionDegrees(targetLineAngle: Double = 0) -> Double? {
        guard let velocity = impactVelocity(frameRate: 240) else { return nil }
        let shotAngle = atan2(velocity.dx, abs(velocity.dy)) * 180.0 / .pi
        return shotAngle - targetLineAngle
    }

    var averageConfidence: Float {
        guard !trackingPoints.isEmpty else { return 0 }
        return trackingPoints.map(\.confidence).reduce(0, +) / Float(trackingPoints.count)
    }
}
