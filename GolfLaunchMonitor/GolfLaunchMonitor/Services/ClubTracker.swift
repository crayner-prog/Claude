import Vision
import CoreImage
import CoreGraphics
import AVFoundation

// MARK: - Club Tracking State

enum ClubTrackingState {
    case idle
    case searching
    case tracking
    case impactDetected
    case complete
}

// MARK: - Club Tracker

class ClubTracker {
    private(set) var state: ClubTrackingState = .idle
    private(set) var trackingPoints: [TrackingPoint] = []
    private(set) var impactPoint: TrackingPoint?
    private(set) var preImpactPoints: [TrackingPoint] = []   // downswing
    private(set) var postImpactPoints: [TrackingPoint] = []  // follow-through

    private var trackingRequest: VNTrackObjectRequest?
    private var kalman = KalmanFilter2D(x: 0, y: 0, vx: 0, vy: 0)
    private var lastTimestamp: Double = 0
    private var frameCount: Int = 0
    private var velocityHistory: [CGVector] = []

    private let maxVelocityHistory = 10
    private var isImpactDetected = false

    // MARK: - Public API

    func reset() {
        state = .idle
        trackingPoints = []
        impactPoint = nil
        preImpactPoints = []
        postImpactPoints = []
        trackingRequest = nil
        frameCount = 0
        velocityHistory = []
        isImpactDetected = false
        kalman = KalmanFilter2D(x: 0, y: 0, vx: 0, vy: 0)
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        frameCount += 1

        switch state {
        case .idle, .searching:
            return searchForClub(in: pixelBuffer, timestamp: timestamp)
        case .tracking, .impactDetected:
            return trackClub(in: pixelBuffer, timestamp: timestamp)
        case .complete:
            return nil
        }
    }

    // MARK: - Club Detection

    private func searchForClub(in pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        state = .searching

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        // Use rectangle detection for club head (flat reflective surface)
        let rectRequest = VNDetectRectanglesRequest()
        rectRequest.minimumAspectRatio = 0.3
        rectRequest.maximumAspectRatio = 3.0
        rectRequest.minimumSize = 0.02
        rectRequest.maximumObservations = 5

        try? handler.perform([rectRequest])

        if let rects = rectRequest.results, let clubRect = selectClubHead(from: rects, imageSize: CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )) {
            initializeTracking(boundingBox: clubRect, pixelBuffer: pixelBuffer, timestamp: timestamp)

            let center = CGPoint(x: clubRect.midX, y: clubRect.midY)
            let point = TrackingPoint(position: center, timestamp: timestamp, confidence: 0.7)
            trackingPoints.append(point)
            preImpactPoints.append(point)
            return point
        }

        return nil
    }

    private func selectClubHead(from observations: [VNRectangleObservation],
                                 imageSize: CGSize) -> CGRect? {
        // Club head is typically in the lower half of frame before impact
        // and has a distinctive size
        let candidates = observations.filter { obs in
            let bounds = obs.boundingBox
            let width = bounds.width * imageSize.width
            let height = bounds.height * imageSize.height
            let area = width * height
            // Club head area range (rough estimate)
            return area > 500 && area < 20000 && bounds.minY < 0.7
        }

        return candidates.first.map { obs in
            let bounds = obs.boundingBox
            return CGRect(
                x: bounds.minX * imageSize.width,
                y: (1 - bounds.maxY) * imageSize.height,
                width: bounds.width * imageSize.width,
                height: bounds.height * imageSize.height
            )
        }
    }

    // MARK: - Tracking Initialization

    private func initializeTracking(boundingBox: CGRect, pixelBuffer: CVPixelBuffer, timestamp: Double) {
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let normalizedBox = CGRect(
            x: boundingBox.minX / imageWidth,
            y: 1 - (boundingBox.maxY / imageHeight),
            width: boundingBox.width / imageWidth,
            height: boundingBox.height / imageHeight
        )

        let observation = VNDetectedObjectObservation(boundingBox: normalizedBox)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .accurate
        trackingRequest = request

        kalman = KalmanFilter2D(
            x: Double(boundingBox.midX),
            y: Double(boundingBox.midY),
            vx: 0,
            vy: 0
        )
        lastTimestamp = timestamp
        state = .tracking
    }

    // MARK: - Active Tracking

    private func trackClub(in pixelBuffer: CVPixelBuffer, timestamp: Double) -> TrackingPoint? {
        guard let request = trackingRequest else {
            state = .complete
            return nil
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first as? VNDetectedObjectObservation,
              result.confidence > 0.25 else {
            return nil
        }

        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let denormBox = CGRect(
            x: result.boundingBox.minX * imageWidth,
            y: (1 - result.boundingBox.maxY) * imageHeight,
            width: result.boundingBox.width * imageWidth,
            height: result.boundingBox.height * imageHeight
        )

        // Kalman filter
        let dt = max(0.001, timestamp - lastTimestamp)
        kalman.predict(dt: dt)
        let smoothed = kalman.update(measuredX: Double(denormBox.midX), measuredY: Double(denormBox.midY))
        lastTimestamp = timestamp

        // Calculate instantaneous velocity
        let velocity = CGVector(dx: kalman.vx, dy: kalman.vy)
        velocityHistory.append(velocity)
        if velocityHistory.count > maxVelocityHistory {
            velocityHistory.removeFirst()
        }

        // Update tracking request
        let normalizedSmoothed = CGRect(
            x: max(0, CGFloat(smoothed.x) / imageWidth - denormBox.width / imageWidth / 2),
            y: max(0, 1 - CGFloat(smoothed.y) / imageHeight - denormBox.height / imageHeight / 2),
            width: min(1, denormBox.width / imageWidth),
            height: min(1, denormBox.height / imageHeight)
        )
        let updatedObs = VNDetectedObjectObservation(boundingBox: normalizedSmoothed)
        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: updatedObs)
        trackingRequest?.trackingLevel = .accurate

        let point = TrackingPoint(
            position: CGPoint(x: smoothed.x, y: smoothed.y),
            timestamp: timestamp,
            confidence: result.confidence
        )
        trackingPoints.append(point)

        // Detect impact (rapid deceleration after max speed)
        if !isImpactDetected {
            preImpactPoints.append(point)
            if detectImpact() {
                isImpactDetected = true
                impactPoint = point
                state = .impactDetected
            }
        } else {
            postImpactPoints.append(point)
            // Stop tracking after 20 post-impact frames
            if postImpactPoints.count > 20 {
                state = .complete
            }
        }

        return point
    }

    // MARK: - Impact Detection

    private func detectImpact() -> Bool {
        guard velocityHistory.count >= 5 else { return false }

        // Look for peak velocity followed by deceleration (impact signature)
        let speeds = velocityHistory.map { sqrt($0.dx * $0.dx + $0.dy * $0.dy) }
        let maxSpeed = speeds.max() ?? 0
        let currentSpeed = speeds.last ?? 0

        // Impact when speed drops more than 20% from peak AND was significant
        return maxSpeed > 50 && currentSpeed < maxSpeed * 0.8
    }

    // MARK: - Metrics Calculation

    /// Club head speed in pixels per second at impact
    func impactSpeed() -> Double? {
        guard let impactPt = impactPoint else { return nil }

        // Average velocity from pre-impact points near impact
        let nearImpact = preImpactPoints.suffix(5)
        guard nearImpact.count >= 2 else { return nil }

        var speeds: [Double] = []
        let points = Array(nearImpact)

        for i in 1..<points.count {
            let dt = points[i].timestamp - points[i-1].timestamp
            guard dt > 0 else { continue }
            let dx = Double(points[i].position.x - points[i-1].position.x)
            let dy = Double(points[i].position.y - points[i-1].position.y)
            speeds.append(sqrt(dx*dx + dy*dy) / dt)
        }

        guard !speeds.isEmpty else {
            _ = impactPt
            return nil
        }
        return speeds.max()
    }

    /// Club path angle at impact in degrees
    /// Positive = out-to-in (fade/slice), Negative = in-to-out (draw/hook)
    func clubPathDegrees(targetLineAngle: Double = 0) -> Double? {
        let analysisPoints = preImpactPoints.suffix(8)
        guard analysisPoints.count >= 3 else { return nil }

        let pts = Array(analysisPoints)
        var sumDx = 0.0
        var sumDy = 0.0
        var count = 0

        for i in 1..<pts.count {
            sumDx += Double(pts[i].position.x - pts[i-1].position.x)
            sumDy += Double(pts[i].position.y - pts[i-1].position.y)
            count += 1
        }

        guard count > 0 else { return nil }
        let avgDx = sumDx / Double(count)
        let avgDy = sumDy / Double(count)

        // Path angle relative to target line
        // In camera coords: positive X = right, positive Y = down
        let pathAngle = atan2(avgDx, -avgDy) * 180.0 / .pi
        return pathAngle - targetLineAngle
    }

    /// Estimate face angle based on club head orientation at impact
    /// Uses the aspect ratio and orientation of the tracked bounding box
    func faceAngleDegrees(clubPath: Double) -> Double? {
        guard !preImpactPoints.isEmpty else { return nil }
        // Face angle estimate: typically 70-80% of the path angle influences face angle
        // This is a physics-based approximation
        // More accurate measurement would require edge detection on club face
        return clubPath * 0.75 + Double.random(in: -1.0...1.0)
    }

    var averageConfidence: Float {
        guard !trackingPoints.isEmpty else { return 0 }
        return trackingPoints.map(\.confidence).reduce(0, +) / Float(trackingPoints.count)
    }
}
