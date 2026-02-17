import SwiftUI

// MARK: - Metric Card

struct MetricCard: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let accentColor: Color
    let confidence: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)

                Spacer()

                // Confidence dot
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 6, height: 6)
                    .help("Confidence: \(Int(confidence * 100))%")
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.8)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            }
        )
    }

    private var confidenceColor: Color {
        if confidence > 0.8 { return .green }
        if confidence > 0.6 { return .yellow }
        return .orange
    }
}

// MARK: - Inline Metric Row (for compact displays)

struct MetricRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Smash Factor Gauge

struct SmashFactorGauge: View {
    let value: Double
    let club: ClubType

    private var percentage: Double {
        let range = club.smashFactorRange
        return (value - 1.0) / (range.upperBound - 1.0)
    }

    private var gaugeColor: Color {
        let range = club.smashFactorRange
        if value >= range.upperBound * 0.97 { return .green }
        if value >= range.lowerBound { return .yellow }
        return .red
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track arc
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(90))

                // Value arc
                Circle()
                    .trim(from: 0.1, to: 0.1 + 0.8 * min(1, max(0, percentage)))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.8), value: value)

                VStack(spacing: 2) {
                    Text(String(format: "%.3f", value))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("SMASH")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                }
            }
            .frame(width: 100, height: 100)
        }
    }
}

// MARK: - Spin Visualization

struct SpinVisualization: View {
    let spinRate: Double
    let spinAxis: Double  // degrees, positive = draw

    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Ball
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)

                // Spin lines
                ForEach(0..<6, id: \.self) { i in
                    Ellipse()
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                        .frame(width: 60, height: CGFloat(i + 1) * 10)
                }

                // Axis indicator
                Path { path in
                    path.move(to: CGPoint(x: 30, y: 5))
                    path.addLine(to: CGPoint(x: 30, y: 55))
                }
                .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                .rotationEffect(.degrees(spinAxis))
            }
            .frame(width: 60, height: 60)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 60000 / spinRate).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text(String(format: "%.0f rpm", spinRate))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(spinAxis > 0 ? "Draw spin" : spinAxis < 0 ? "Fade spin" : "Pure backspin")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Live Metric Badge (for camera overlay)

struct LiveMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
    }
}
