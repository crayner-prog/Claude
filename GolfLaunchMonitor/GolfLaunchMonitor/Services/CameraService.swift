import AVFoundation
import UIKit
import Combine

// MARK: - Camera Configuration

enum CaptureMode {
    case analysis   // 240fps slow-mo for shot analysis
    case preview    // 60fps for live preview
    case recording  // 4K ProRes for saving
}

enum CameraError: LocalizedError {
    case noCameraAccess
    case noSuitableDevice
    case configurationFailed(String)
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .noCameraAccess:
            return "Camera access denied. Please enable camera access in Settings."
        case .noSuitableDevice:
            return "No suitable camera found. iPhone 15 Pro Max recommended."
        case .configurationFailed(let reason):
            return "Camera configuration failed: \(reason)"
        case .captureFailed:
            return "Failed to capture video."
        }
    }
}

// MARK: - Camera Service

@MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isRecording = false
    @Published var captureMode: CaptureMode = .preview
    @Published var error: CameraError?
    @Published var zoomFactor: CGFloat = 1.0

    let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?

    private let sessionQueue = DispatchQueue(label: "com.golflaunchmonitor.camera", qos: .userInteractive)
    private let outputQueue = DispatchQueue(label: "com.golflaunchmonitor.videooutput", qos: .userInteractive)

    var frameHandler: ((CMSampleBuffer) -> Void)?
    var recordingCompletionHandler: ((URL?) -> Void)?

    // MARK: - Setup

    func requestPermissionAndSetup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await setupSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupSession()
            } else {
                self.error = .noCameraAccess
            }
        default:
            self.error = .noCameraAccess
        }
    }

    private func setupSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                do {
                    try self.configureSession(mode: .preview)
                } catch let cameraError as CameraError {
                    Task { @MainActor in self.error = cameraError }
                } catch {
                    Task { @MainActor in self.error = .configurationFailed(error.localizedDescription) }
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Session Configuration

    private func configureSession(mode: CaptureMode) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Select the best camera for golf analysis
        guard let device = selectOptimalCamera() else {
            throw CameraError.noSuitableDevice
        }

        // Configure input
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.configurationFailed("Cannot add camera input")
        }
        if let existing = videoInput { session.removeInput(existing) }
        session.addInput(input)
        videoInput = input

        // Configure session preset
        switch mode {
        case .analysis:
            session.sessionPreset = .hd1920x1080
        case .preview:
            session.sessionPreset = .hd1280x720
        case .recording:
            session.sessionPreset = .hd4K3840x2160
        }

        // Configure frame rate for analysis mode
        try configureFrameRate(for: device, mode: mode)

        // Configure video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(output) else {
            throw CameraError.configurationFailed("Cannot add video output")
        }
        if let existing = videoOutput { session.removeOutput(existing) }
        session.addOutput(output)
        videoOutput = output

        // Set video orientation
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }

        Task { @MainActor in self.captureMode = mode }
    }

    private func selectOptimalCamera() -> AVCaptureDevice? {
        // Prefer telephoto (3x on iPhone 15 Pro Max) for better isolation of ball
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )

        // Return first available (triple camera preferred)
        return discovery.devices.first
    }

    private func configureFrameRate(for device: AVCaptureDevice, mode: CaptureMode) throws {
        let targetFPS: Double
        switch mode {
        case .analysis: targetFPS = 240
        case .preview: targetFPS = 60
        case .recording: targetFPS = 30
        }

        // Find the best format supporting the target FPS
        let targetDimensions: (Int32, Int32) = mode == .recording ? (3840, 2160) : (1920, 1080)

        let bestFormat = device.formats.first(where: { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let supportsTargetFPS = format.videoSupportedFrameRateRanges.contains {
                $0.maxFrameRate >= targetFPS
            }
            return dims.width >= targetDimensions.0 && supportsTargetFPS
        }) ?? device.formats.last(where: { format in
            format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= targetFPS }
        })

        guard let format = bestFormat else {
            // Fall back to any available format
            return
        }

        try device.lockForConfiguration()
        device.activeFormat = format

        // Find the supported frame rate closest to target
        let actualFPS: Double
        if let range = format.videoSupportedFrameRateRanges.first(where: { $0.maxFrameRate >= targetFPS }) {
            actualFPS = min(targetFPS, range.maxFrameRate)
        } else if let range = format.videoSupportedFrameRateRanges.last {
            actualFPS = range.maxFrameRate
        } else {
            actualFPS = targetFPS
        }

        let duration = CMTimeMake(value: 1, timescale: CMTimeScale(actualFPS))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
    }

    // MARK: - Session Control

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in self.isRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in self.isRunning = false }
        }
    }

    // MARK: - Capture Mode Switching

    func switchToAnalysisMode() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            try? self.configureSession(mode: .analysis)
        }
    }

    func switchToPreviewMode() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            try? self.configureSession(mode: .preview)
        }
    }

    // MARK: - Zoom Control

    func setZoom(_ factor: CGFloat) {
        guard let device = videoInput?.device else { return }
        let clamped = max(1.0, min(factor, device.maxAvailableVideoZoomFactor))
        sessionQueue.async {
            try? device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
        Task { @MainActor in self.zoomFactor = clamped }
    }

    // MARK: - Focus & Exposure Lock

    func lockFocusAndExposure(at point: CGPoint) {
        guard let device = videoInput?.device else { return }
        sessionQueue.async {
            try? device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .locked
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .locked
            }
            device.unlockForConfiguration()
        }
    }

    func unlockFocusAndExposure() {
        guard let device = videoInput?.device else { return }
        sessionQueue.async {
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: - Device Info

    var currentFrameRate: Double {
        guard let device = videoInput?.device else { return 0 }
        return Double(device.activeVideoMinFrameDuration.timescale) /
               Double(device.activeVideoMinFrameDuration.value)
    }

    var cameraModel: String {
        videoInput?.device.localizedName ?? "Unknown Camera"
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                    didOutput sampleBuffer: CMSampleBuffer,
                                    from connection: AVCaptureConnection) {
        frameHandler?(sampleBuffer)
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                    didDrop sampleBuffer: CMSampleBuffer,
                                    from connection: AVCaptureConnection) {
        // Frame dropped - acceptable at 240fps during heavy processing
    }
}

// MARK: - Preview Layer Helper

extension CameraService {
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}
