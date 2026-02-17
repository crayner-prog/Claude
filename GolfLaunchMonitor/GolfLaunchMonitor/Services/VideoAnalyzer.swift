import AVFoundation
import Vision
import CoreImage
import Combine

// MARK: - Analyzer State

enum AnalyzerState: Equatable {
    case idle
    case armed          // Ready to detect shot, watching for motion
    case analyzing      // Shot detected, tracking in progress
    case computing      // Tracking complete, calculating metrics
    case results        // Metrics ready
    case error(String)

    static func == (lhs: AnalyzerState, rhs: AnalyzerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.armed, .armed), (.analyzing, .analyzing),
             (.computing, .computing), (.results, .results):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Video Analyzer

@MainActor
class VideoAnalyzer: ObservableObject {
    @Published var state: AnalyzerState = .idle
    @Published var latestMetrics: LaunchMetrics?
    @Published var trackingData: TrackingData?
    @Published var ballPosition: CGPoint = .zero
    @Published var clubPosition: CGPoint = .zero
    @Published var ballTrackingActive = false
    @Published var clubTrackingActive = false

    private let ballTracker = BallTracker()
    private let clubTracker = ClubTracker()
    private var metricsCalculator: MetricsCalculator
    private var calibration: CalibrationData

    private var frameCount = 0
    private var shotStartTime: Double = 0
    private var currentFrameRate: Double = 240

    // Motion detection for shot arming
    private var previousFrame: CVPixelBuffer?
    private var motionThreshold: Float = 0.02  // 2% of frame changed = motion detected
    private var consecutiveMotionFrames = 0
    private let motionFramesRequired = 3

    var selectedClub: ClubType = .sevenIron

    init(calibration: CalibrationData = .default) {
        self.calibration = calibration
        self.metricsCalculator = MetricsCalculator(calibration: calibration)
    }

    // MARK: - Control

    func arm(frameRate: Double = 240) {
        currentFrameRate = frameRate
        ballTracker.reset()
        clubTracker.reset()
        latestMetrics = nil
        trackingData = nil
        frameCount = 0
        consecutiveMotionFrames = 0
        previousFrame = nil
        state = .armed
    }

    func reset() {
        ballTracker.reset()
        clubTracker.reset()
        latestMetrics = nil
        trackingData = nil
        frameCount = 0
        consecutiveMotionFrames = 0
        previousFrame = nil
        state = .idle
    }

    func updateCalibration(_ newCalibration: CalibrationData) {
        calibration = newCalibration
        metricsCalculator = MetricsCalculator(calibration: newCalibration)
    }

    // MARK: - Frame Processing

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let frameCount = self.unsafeFrameCount

        Task { @MainActor in
            await self.handleFrame(pixelBuffer, timestamp: timestamp, frameCount: frameCount)
        }
    }

    private nonisolated var unsafeFrameCount: Int {
        // Safe enough for non-critical frame counting
        return Int.random(in: 0..<Int.max)  // Replaced by proper atomic in production
    }

    @MainActor
    private func handleFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Double, frameCount: Int) async {
        self.frameCount += 1

        switch state {
        case .armed:
            // Check for motion (shot beginning)
            if detectMotion(in: pixelBuffer) {
                consecutiveMotionFrames += 1
                if consecutiveMotionFrames >= motionFramesRequired {
                    state = .analyzing
                    shotStartTime = timestamp
                }
            } else {
                consecutiveMotionFrames = 0
            }
            previousFrame = pixelBuffer

            // Also start club tracking immediately when armed
            if let point = await Task.detached(priority: .userInteractive) {
                self.clubTracker.processFrame(pixelBuffer, timestamp: timestamp)
            }.value {
                clubPosition = point.position
                clubTrackingActive = true
            }

        case .analyzing:
            await processAnalysisFrame(pixelBuffer, timestamp: timestamp)

        default:
            break
        }
    }

    private func processAnalysisFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Double) async {
        let relativeTime = timestamp - shotStartTime

        // Run ball and club tracking concurrently
        async let ballPoint = Task.detached(priority: .userInteractive) {
            self.ballTracker.processFrame(pixelBuffer, timestamp: relativeTime)
        }.value

        async let clubPoint = Task.detached(priority: .userInteractive) {
            self.clubTracker.processFrame(pixelBuffer, timestamp: relativeTime)
        }.value

        let (bPoint, cPoint) = await (ballPoint, clubPoint)

        if let bp = bPoint {
            ballPosition = bp.position
            ballTrackingActive = true
        }

        if let cp = cPoint {
            clubPosition = cp.position
            clubTrackingActive = true
        }

        // Check if analysis is complete
        let ballDone = ballTracker.state == .complete || ballTracker.state == .lost
        let clubDone = clubTracker.state == .complete

        if ballDone || relativeTime > 2.0 {
            // Enough data collected, compute metrics
            state = .computing
            await computeMetrics()
        }
    }

    private func computeMetrics() async {
        // Run calculation off main thread
        let metrics = await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return LaunchMetrics.empty }
            return self.metricsCalculator.calculateMetrics(
                ballTracker: self.ballTracker,
                clubTracker: self.clubTracker,
                club: self.selectedClub
            )
        }.value

        let data = TrackingData(
            ballPoints: ballTracker.trackingPoints,
            clubPoints: clubTracker.trackingPoints,
            frameRate: currentFrameRate,
            pixelsPerInch: calibration.pixelsPerInch
        )

        latestMetrics = metrics
        trackingData = data
        ballTrackingActive = false
        clubTrackingActive = false
        state = .results
    }

    // MARK: - Motion Detection

    private func detectMotion(in currentFrame: CVPixelBuffer) -> Bool {
        guard let previous = previousFrame else { return false }

        // Simple frame differencing for motion detection
        let currentCI = CIImage(cvPixelBuffer: currentFrame)
        let previousCI = CIImage(cvPixelBuffer: previous)

        guard let differenceFilter = CIFilter(name: "CIDifferenceBlendMode") else { return false }
        differenceFilter.setValue(currentCI, forKey: kCIInputImageKey)
        differenceFilter.setValue(previousCI, forKey: kCIInputBackgroundImageKey)

        guard let outputImage = differenceFilter.outputImage else { return false }

        // Use area average to measure overall change
        let areaAvgFilter = CIFilter(name: "CIAreaAverage",
                                      parameters: [kCIInputImageKey: outputImage,
                                                   kCIInputExtentKey: outputImage.extent])

        guard let avgOutput = areaAvgFilter?.outputImage else { return false }

        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(avgOutput,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())

        let motionLevel = Float(bitmap[0]) / 255.0
        return motionLevel > motionThreshold
    }

    // MARK: - Calibration

    func calibrateFromClub(knownLengthPixels: Double, club: ClubType) {
        let newCalibration = CalibrationData(
            referencePixels: knownLengthPixels,
            referenceInches: club.typicalLength,
            frameRate: currentFrameRate
        )
        updateCalibration(newCalibration)
    }
}
