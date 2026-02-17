import SwiftUI

// MARK: - Results Screen

struct ResultsScreenView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ResultsHeaderView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Shot summary card
                        if let metrics = viewModel.latestMetrics {
                            ShotSummaryCard(metrics: metrics, club: viewModel.selectedClub)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }

                        // Primary metrics grid
                        if let metrics = viewModel.latestMetrics {
                            PrimaryMetricsGrid(metrics: metrics)
                                .padding(.horizontal, 16)

                            // Direction metrics
                            DirectionMetricsView(metrics: metrics)
                                .padding(.horizontal, 16)

                            // Dispersion chart
                            DispersionChartView(metrics: metrics)
                                .padding(.horizontal, 16)

                            // Confidence indicators
                            ConfidenceView(confidence: metrics.confidence)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 100)
                        }
                    }
                }

                // Bottom action bar
                ResultsActionBar()
            }
        }
    }
}

// MARK: - Header

struct ResultsHeaderView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        HStack {
            Button {
                viewModel.currentScreen = .camera
                viewModel.discardCurrentShot()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Shot Analysis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(viewModel.selectedClub.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(.green)
            }

            Spacer()

            Button {
                // Share sheet
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
}

// MARK: - Shot Summary Card

struct ShotSummaryCard: View {
    let metrics: LaunchMetrics
    let club: ClubType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.05, green: 0.35, blue: 0.15),
                            Color(red: 0.02, green: 0.18, blue: 0.08)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARRY DISTANCE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.5)
                        Text(String(format: "%.0f yds", metrics.carryDistance))
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        ShotShapeBadge(
                            shotData: ShotData(
                                club: club,
                                metrics: metrics,
                                trackingData: TrackingData()
                            )
                        )

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("SMASH FACTOR")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                            Text(String(format: "%.3f", metrics.smashFactor))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(smashFactorColor(metrics.smashFactor, club: club))
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func smashFactorColor(_ sf: Double, club: ClubType) -> Color {
        let range = club.smashFactorRange
        if sf >= range.upperBound * 0.97 { return .green }
        if sf >= range.lowerBound { return .yellow }
        return .red
    }
}

struct ShotShapeBadge: View {
    let shotData: ShotData

    var shapeColor: Color {
        switch shotData.shotShape {
        case .straight: return .white
        case .draw: return .blue
        case .hook: return .purple
        case .fade: return .orange
        case .slice: return .red
        }
    }

    var body: some View {
        Text(shotData.shotShape.rawValue.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(shapeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(shapeColor.opacity(0.2))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(shapeColor, lineWidth: 1))
            .cornerRadius(6)
    }
}

// MARK: - Primary Metrics Grid

struct PrimaryMetricsGrid: View {
    let metrics: LaunchMetrics

    var body: some View {
        VStack(spacing: 12) {
            Text("KEY METRICS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    label: "Ball Speed",
                    value: String(format: "%.1f", metrics.ballSpeed),
                    unit: "mph",
                    icon: "circle.fill",
                    accentColor: .yellow,
                    confidence: metrics.confidence.ballSpeed
                )

                MetricCard(
                    label: "Club Speed",
                    value: String(format: "%.1f", metrics.clubSpeed),
                    unit: "mph",
                    icon: "figure.golf",
                    accentColor: .cyan,
                    confidence: metrics.confidence.clubSpeed
                )

                MetricCard(
                    label: "Spin Rate",
                    value: String(format: "%.0f", metrics.spinRate),
                    unit: "rpm",
                    icon: "arrow.clockwise.circle.fill",
                    accentColor: .orange,
                    confidence: metrics.confidence.spinRate
                )

                MetricCard(
                    label: "Launch Angle",
                    value: String(format: "%.1f", metrics.launchAngle),
                    unit: "°",
                    icon: "arrow.up.right",
                    accentColor: .green,
                    confidence: metrics.confidence.launchAngle
                )
            }
        }
    }
}

// MARK: - Direction Metrics

struct DirectionMetricsView: View {
    let metrics: LaunchMetrics

    var body: some View {
        VStack(spacing: 12) {
            Text("DIRECTION & PATH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                DirectionMetricCard(
                    label: "Club Path",
                    value: metrics.clubPath,
                    unit: "°",
                    negativeLabel: "In-to-Out",
                    positiveLabel: "Out-to-In",
                    confidence: metrics.confidence.clubPath
                )

                DirectionMetricCard(
                    label: "Face Angle",
                    value: metrics.faceAngle,
                    unit: "°",
                    negativeLabel: "Closed",
                    positiveLabel: "Open",
                    confidence: metrics.confidence.faceAngle
                )
            }

            // Face-to-path
            FaceToPathBar(clubPath: metrics.clubPath, faceAngle: metrics.faceAngle)
        }
    }
}

struct DirectionMetricCard: View {
    let label: String
    let value: Double
    let unit: String
    let negativeLabel: String
    let positiveLabel: String
    let confidence: Float

    private var direction: String {
        value < -0.5 ? negativeLabel : value > 0.5 ? positiveLabel : "Neutral"
    }

    private var directionColor: Color {
        value < -0.5 ? .blue : value > 0.5 ? .red : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value >= 0 ? "+" : "")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(String(format: "%.1f", value))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(directionColor)
                    .frame(width: 6, height: 6)
                Text(direction)
                    .font(.system(size: 11))
                    .foregroundColor(directionColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct FaceToPathBar: View {
    let clubPath: Double
    let faceAngle: Double

    private var facePath: Double { faceAngle - clubPath }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Face-to-Path")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%+.1f°", facePath))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(facePathColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 16)
                        .offset(x: geo.size.width / 2 - 1)

                    // Face-to-path indicator
                    Capsule()
                        .fill(facePathColor)
                        .frame(width: max(4, abs(facePath) / 10 * geo.size.width / 2), height: 8)
                        .offset(x: facePath > 0
                            ? geo.size.width / 2
                            : geo.size.width / 2 - max(4, abs(facePath) / 10 * geo.size.width / 2))
                }
            }
            .frame(height: 16)

            HStack {
                Text("Draw")
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.7))
                Spacer()
                Text("Straight")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("Fade")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private var facePathColor: Color {
        if facePath < -4 { return .blue }
        if facePath < -1 { return .cyan }
        if abs(facePath) <= 1 { return .green }
        if facePath < 4 { return .orange }
        return .red
    }
}

// MARK: - Dispersion Chart

struct DispersionChartView: View {
    let metrics: LaunchMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAUNCH WINDOW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)

            GeometryReader { geo in
                ZStack {
                    // Background grid
                    LaunchWindowGrid(size: geo.size)

                    // Ball flight dot
                    let x = geo.size.width / 2 + CGFloat(metrics.launchDirection) * 8
                    let y = geo.size.height - CGFloat(metrics.launchAngle) * 3

                    // Trajectory line
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    .stroke(Color.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                    // Ball impact point
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 10, height: 10)
                        .shadow(color: .yellow, radius: 4)
                        .position(x: x, y: y)

                    // Labels
                    Text(String(format: "%.1f°", metrics.launchAngle))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                        .position(x: x + 16, y: y)
                }
            }
            .frame(height: 140)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }
}

struct LaunchWindowGrid: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Angle arcs
            ForEach([10, 20, 30, 40], id: \.self) { angle in
                Path { path in
                    let cx = size.width / 2
                    let cy = size.height
                    let radius = CGFloat(angle) * 3.5
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: radius,
                        startAngle: .degrees(-160),
                        endAngle: .degrees(-20),
                        clockwise: false
                    )
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                Text("\(angle)°")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.3))
                    .position(
                        x: size.width / 2 + CGFloat(angle) * 3.5,
                        y: size.height - 4
                    )
            }

            // Center line
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}

// MARK: - Confidence View

struct ConfidenceView: View {
    let confidence: MetricConfidence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Text("MEASUREMENT CONFIDENCE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
            }

            VStack(spacing: 8) {
                ConfidenceRow(label: "Ball Speed", value: confidence.ballSpeed)
                ConfidenceRow(label: "Club Speed", value: confidence.clubSpeed)
                ConfidenceRow(label: "Spin Rate", value: confidence.spinRate, isEstimated: true)
                ConfidenceRow(label: "Launch Angle", value: confidence.launchAngle)
                ConfidenceRow(label: "Club Path", value: confidence.clubPath)
                ConfidenceRow(label: "Face Angle", value: confidence.faceAngle, isEstimated: true)
            }

            Text("* Spin rate and face angle are physics-based estimates. For highest accuracy, use reflective club face tape and calibrate with a known distance reference.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}

struct ConfidenceRow: View {
    let label: String
    let value: Float
    var isEstimated: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text(label + (isEstimated ? " *" : ""))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 6)

            Text("\(Int(value * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(confidenceColor)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var confidenceColor: Color {
        if value > 0.8 { return .green }
        if value > 0.6 { return .yellow }
        return .orange
    }
}

// MARK: - Action Bar

struct ResultsActionBar: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.discardCurrentShot()
                viewModel.currentScreen = .camera
            } label: {
                Label("Discard", systemImage: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(12)
            }

            Button {
                viewModel.saveAndContinue()
            } label: {
                Label("New Shot", systemImage: "target")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
}
