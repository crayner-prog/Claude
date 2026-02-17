import SwiftUI
import AVFoundation
import Combine

// MARK: - App Screen

enum AppScreen {
    case setup
    case camera
    case results
    case history
}

// MARK: - Launch Monitor ViewModel

@MainActor
class LaunchMonitorViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentScreen: AppScreen = .camera
    @Published var selectedClub: ClubType = .sevenIron
    @Published var analyzerState: AnalyzerState = .idle
    @Published var latestShot: ShotData?
    @Published var latestMetrics: LaunchMetrics?

    // Tracking overlays
    @Published var ballPosition: CGPoint = .zero
    @Published var clubPosition: CGPoint = .zero
    @Published var ballTrackingActive = false
    @Published var clubTrackingActive = false

    // UI State
    @Published var showingCalibration = false
    @Published var showingSettings = false
    @Published var calibrationReferenceLength: Double = 0
    @Published var isCalibrated = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Settings
    @Published var frameRate: Double = 240
    @Published var cameraHeight: Double = 36.0
    @Published var targetLineAngle: Double = 0.0
    @Published var handedness: Handedness = .right
    @Published var unitSystem: UnitSystem = .imperial

    // MARK: - Services

    let cameraService = CameraService()
    let videoAnalyzer = VideoAnalyzer()
    private var sessionStore: SessionStore?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        setupBindings()
    }

    func setSessionStore(_ store: SessionStore) {
        self.sessionStore = store
    }

    // MARK: - Setup

    private func setupBindings() {
        // Sync analyzer state
        videoAnalyzer.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.analyzerState = state
                if state == .results {
                    self?.handleResultsReady()
                }
            }
            .store(in: &cancellables)

        // Sync tracking positions for overlay
        videoAnalyzer.$ballPosition
            .receive(on: RunLoop.main)
            .assign(to: &$ballPosition)

        videoAnalyzer.$clubPosition
            .receive(on: RunLoop.main)
            .assign(to: &$clubPosition)

        videoAnalyzer.$ballTrackingActive
            .receive(on: RunLoop.main)
            .assign(to: &$ballTrackingActive)

        videoAnalyzer.$clubTrackingActive
            .receive(on: RunLoop.main)
            .assign(to: &$clubTrackingActive)

        // Camera errors
        cameraService.$error
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.showError = true
            }
            .store(in: &cancellables)

        // Connect camera frames to analyzer
        cameraService.frameHandler = { [weak self] sampleBuffer in
            self?.videoAnalyzer.processFrame(sampleBuffer)
        }
    }

    // MARK: - Camera Lifecycle

    func startCamera() async {
        await cameraService.requestPermissionAndSetup()
        cameraService.startSession()
    }

    func stopCamera() {
        cameraService.stopSession()
    }

    // MARK: - Shot Analysis Flow

    func armForShot() {
        videoAnalyzer.selectedClub = selectedClub
        videoAnalyzer.arm(frameRate: frameRate)
        cameraService.switchToAnalysisMode()
        cameraService.lockFocusAndExposure(at: CGPoint(x: 0.5, y: 0.6))
    }

    func cancelAnalysis() {
        videoAnalyzer.reset()
        cameraService.switchToPreviewMode()
        cameraService.unlockFocusAndExposure()
    }

    private func handleResultsReady() {
        guard let metrics = videoAnalyzer.latestMetrics,
              let trackingData = videoAnalyzer.trackingData else { return }

        latestMetrics = metrics

        let shot = ShotData(
            club: selectedClub,
            metrics: metrics,
            trackingData: trackingData
        )
        latestShot = shot
        sessionStore?.addShot(shot)

        cameraService.switchToPreviewMode()
        cameraService.unlockFocusAndExposure()
        currentScreen = .results
    }

    func discardCurrentShot() {
        latestShot = nil
        latestMetrics = nil
        videoAnalyzer.reset()
    }

    func saveAndContinue() {
        // Shot already saved in handleResultsReady
        videoAnalyzer.reset()
        currentScreen = .camera
    }

    // MARK: - Calibration

    func calibrateWithClub(pixelLength: Double) {
        videoAnalyzer.calibrateFromClub(
            knownLengthPixels: pixelLength,
            club: selectedClub
        )
        isCalibrated = true
        showingCalibration = false
    }

    // MARK: - Session Management

    func startNewSession(name: String = "") {
        sessionStore?.startNewSession(name: name)
    }

    func endSession() {
        sessionStore?.finalizeCurrentSession()
    }

    // MARK: - Club Selection

    func selectClub(_ club: ClubType) {
        selectedClub = club
        videoAnalyzer.selectedClub = club
    }

    // MARK: - Zoom

    func setZoom(_ factor: CGFloat) {
        cameraService.setZoom(factor)
    }
}

// MARK: - Supporting Types

enum Handedness: String, CaseIterable {
    case right = "Right Handed"
    case left = "Left Handed"
}

enum UnitSystem: String, CaseIterable {
    case imperial = "Imperial (mph, yards)"
    case metric = "Metric (km/h, meters)"
}

// MARK: - Metric Display Helpers

extension LaunchMonitorViewModel {
    func displaySpeed(_ mph: Double) -> String {
        switch unitSystem {
        case .imperial:
            return String(format: "%.1f mph", mph)
        case .metric:
            return String(format: "%.1f km/h", mph * 1.60934)
        }
    }

    func displayDistance(_ yards: Double) -> String {
        switch unitSystem {
        case .imperial:
            return String(format: "%.0f yds", yards)
        case .metric:
            return String(format: "%.0f m", yards * 0.9144)
        }
    }

    func displaySpin(_ rpm: Double) -> String {
        String(format: "%.0f rpm", rpm)
    }

    func displayAngle(_ degrees: Double, sign: Bool = true) -> String {
        let absVal = abs(degrees)
        let prefix = sign ? (degrees >= 0 ? "+" : "-") : ""
        return String(format: "\(prefix)%.1f°", absVal)
    }
}
