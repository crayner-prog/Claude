import SwiftUI
import AVFoundation

// MARK: - Main Camera Screen

struct CameraScreenView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(cameraService: viewModel.cameraService)
                .ignoresSafeArea()

            // Tracking overlays
            TrackingOverlayView()

            // UI Overlay
            VStack(spacing: 0) {
                TopBarView()
                Spacer()
                BottomControlsView()
            }
        }
        .statusBarHidden(viewModel.analyzerState == .analyzing)
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer = cameraService.makePreviewLayer()
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewLayer()
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            if let layer = previewLayer {
                self.layer.insertSublayer(layer, at: 0)
                updatePreviewLayer()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewLayer()
    }

    func updatePreviewLayer() {
        previewLayer?.frame = bounds
    }
}

// MARK: - Tracking Overlay

struct TrackingOverlayView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Target line guide
                if viewModel.analyzerState == .armed || viewModel.analyzerState == .analyzing {
                    TargetLineView(size: geo.size)
                }

                // Ball tracking indicator
                if viewModel.ballTrackingActive {
                    TrackingIndicator(
                        position: viewModel.ballPosition,
                        color: .yellow,
                        size: 20,
                        label: "Ball"
                    )
                }

                // Club tracking indicator
                if viewModel.clubTrackingActive {
                    TrackingIndicator(
                        position: viewModel.clubPosition,
                        color: .cyan,
                        size: 28,
                        label: "Club"
                    )
                }

                // Armed pulsing border
                if viewModel.analyzerState == .armed {
                    ArmedBorderView()
                }

                // Analyzing overlay
                if viewModel.analyzerState == .analyzing {
                    AnalyzingOverlayView()
                }

                // Computing overlay
                if viewModel.analyzerState == .computing {
                    ComputingOverlayView()
                }
            }
        }
    }
}

struct TargetLineView: View {
    let size: CGSize
    @State private var opacity: Double = 0.4

    var body: some View {
        Path { path in
            let y = size.height * 0.65
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                opacity = 0.8
            }
        }
    }
}

struct TrackingIndicator: View {
    let position: CGPoint
    let color: Color
    let size: CGFloat
    let label: String

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.4), lineWidth: 2)
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulseScale)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseScale)

            Circle()
                .fill(color.opacity(0.3))
                .overlay(
                    Circle().stroke(color, lineWidth: 2)
                )
                .frame(width: size, height: size)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .offset(y: size / 2 + 8)
        }
        .position(position)
        .onAppear { pulseScale = 1.3 }
    }
}

struct ArmedBorderView: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(Color.green, lineWidth: 3)
            .opacity(opacity)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: opacity)
            .onAppear { opacity = 0.9 }
    }
}

struct AnalyzingOverlayView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .modifier(PulsingModifier())
                    Text("ANALYZING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.trailing, 16)
                .padding(.top, 60)
            }
            Spacer()
        }
    }
}

struct ComputingOverlayView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                    .onAppear { rotation = 360 }
                Text("Computing Metrics...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct PulsingModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: scale)
            .onAppear { scale = 1.4 }
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        HStack(alignment: .center) {
            // Session / History button
            Button {
                viewModel.currentScreen = .history
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20))
                    Text("History")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
                .frame(width: 50, height: 44)
            }

            Spacer()

            // Club selector & frame rate
            VStack(spacing: 4) {
                Text(viewModel.selectedClub.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("\(Int(viewModel.frameRate)) fps")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .onTapGesture {
                viewModel.currentScreen = .setup
            }

            Spacer()

            // Settings button
            Button {
                viewModel.showingSettings = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                    Text("Settings")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
                .frame(width: 50, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Bottom Controls

struct BottomControlsView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @State private var zoomLevel: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 16) {
            // Zoom slider
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.white)
                Slider(value: $zoomLevel, in: 1...5, step: 0.5) { _ in
                    viewModel.setZoom(zoomLevel)
                }
                .tint(.white)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.white)

                Text("\(String(format: "%.1f", zoomLevel))×")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 35)
            }
            .padding(.horizontal, 24)

            // Main action button area
            HStack(spacing: 32) {
                // Club quick-select
                ClubQuickSelectView()

                // Main ARM / CANCEL button
                MainActionButton()

                // Calibration hint
                if !viewModel.isCalibrated {
                    VStack(spacing: 4) {
                        Image(systemName: "ruler.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                        Text("Calibrate")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    .onTapGesture {
                        viewModel.showingCalibration = true
                    }
                } else {
                    // Carry estimate placeholder
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                        Text("Calibrated")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.85)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct ClubQuickSelectView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 4) {
            Button {
                showingPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 52, height: 52)
                    VStack(spacing: 1) {
                        Image(systemName: "figure.golf")
                            .font(.system(size: 20))
                        Text(viewModel.selectedClub.rawValue.prefix(3))
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            Text("Club")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
        .sheet(isPresented: $showingPicker) {
            ClubPickerSheet()
        }
    }
}

struct MainActionButton: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        VStack(spacing: 6) {
            Button {
                handleTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: buttonColor.opacity(0.5), radius: 12)

                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)

                    buttonIcon
                }
            }
            .disabled(isDisabled)

            Text(buttonLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var buttonColor: Color {
        switch viewModel.analyzerState {
        case .idle: return .blue
        case .armed: return .red
        case .analyzing: return .orange
        case .computing: return .gray
        case .results: return .green
        case .error: return .red
        }
    }

    private var buttonLabel: String {
        switch viewModel.analyzerState {
        case .idle: return "ARM"
        case .armed: return "CANCEL"
        case .analyzing: return "ANALYZING"
        case .computing: return "COMPUTING"
        case .results: return "VIEW"
        case .error: return "RETRY"
        }
    }

    private var isDisabled: Bool {
        viewModel.analyzerState == .analyzing || viewModel.analyzerState == .computing
    }

    @ViewBuilder
    private var buttonIcon: some View {
        switch viewModel.analyzerState {
        case .idle:
            Image(systemName: "target")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        case .armed:
            Image(systemName: "xmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        case .analyzing:
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .modifier(PulsingModifier())
        case .computing:
            ProgressView()
                .tint(.white)
        case .results:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 26))
                .foregroundColor(.white)
        case .error:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 26))
                .foregroundColor(.white)
        }
    }

    private func handleTap() {
        switch viewModel.analyzerState {
        case .idle:
            viewModel.armForShot()
        case .armed:
            viewModel.cancelAnalysis()
        case .results:
            viewModel.currentScreen = .results
        case .error:
            viewModel.cancelAnalysis()
        default:
            break
        }
    }
}

// MARK: - Club Picker Sheet

struct ClubPickerSheet: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(Set(ClubType.allCases.map(\.category))).sorted(), id: \.self) { category in
                    Section(category) {
                        ForEach(ClubType.allCases.filter { $0.category == category }) { club in
                            Button {
                                viewModel.selectClub(club)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(club.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int(club.typicalLoft))°")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    if viewModel.selectedClub == club {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
