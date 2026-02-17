import SwiftUI
import Charts

// MARK: - History Screen

struct HistoryView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var selectedSession: GolfSession?
    @State private var showingSessionDetail = false
    @State private var filterClub: ClubType?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

                if sessionStore.sessions.isEmpty && sessionStore.currentSession == nil {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Current session banner
                            if let current = sessionStore.currentSession, !current.shots.isEmpty {
                                CurrentSessionBanner(session: current)
                                    .padding(.horizontal, 16)
                            }

                            // Career best metrics
                            CareerHighlightsCard()
                                .padding(.horizontal, 16)

                            // Session list
                            if !sessionStore.sessions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("PAST SESSIONS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                        .tracking(2)
                                        .padding(.horizontal, 16)

                                    ForEach(sessionStore.sessions) { session in
                                        SessionRowView(session: session)
                                            .padding(.horizontal, 16)
                                            .onTapGesture {
                                                selectedSession = session
                                                showingSessionDetail = true
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(red: 0.06, green: 0.07, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.currentScreen = .camera
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if sessionStore.currentSession != nil {
                        Button("End Session") {
                            sessionStore.finalizeCurrentSession()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
        }
    }
}

// MARK: - Current Session Banner

struct CurrentSessionBanner: View {
    let session: GolfSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .modifier(PulsingModifier())
                    Text("ACTIVE SESSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .tracking(1.5)
                }
                Text(session.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(session.shots.count) shots recorded")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if let maxBall = session.maxBallSpeed {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best Ball Speed")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.1f mph", maxBall))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Career Highlights

struct CareerHighlightsCard: View {
    @EnvironmentObject private var sessionStore: SessionStore

    private var allShots: [ShotData] {
        sessionStore.sessions.flatMap(\.shots) + (sessionStore.currentSession?.shots ?? [])
    }

    private var maxBallSpeed: Double { allShots.map(\.metrics.ballSpeed).max() ?? 0 }
    private var maxClubSpeed: Double { allShots.map(\.metrics.clubSpeed).max() ?? 0 }
    private var maxCarry: Double { allShots.map(\.metrics.carryDistance).max() ?? 0 }
    private var totalShots: Int { allShots.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL BESTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)

            HStack(spacing: 12) {
                CareerStatCell(
                    label: "Max Ball Speed",
                    value: String(format: "%.1f", maxBallSpeed),
                    unit: "mph",
                    icon: "bolt.fill",
                    color: .yellow
                )
                CareerStatCell(
                    label: "Max Club Speed",
                    value: String(format: "%.1f", maxClubSpeed),
                    unit: "mph",
                    icon: "figure.golf",
                    color: .cyan
                )
                CareerStatCell(
                    label: "Max Carry",
                    value: String(format: "%.0f", maxCarry),
                    unit: "yds",
                    icon: "arrow.up.right.circle.fill",
                    color: .green
                )
            }

            HStack {
                Image(systemName: "number")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(totalShots) total shots across \(sessionStore.sessions.count) sessions")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

struct CareerStatCell: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: GolfSession
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        HStack(spacing: 14) {
            // Date icon
            VStack(spacing: 2) {
                Text(monthString(session.date))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Text(dayString(session.date))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(width: 44)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(session.shots.count) shots", systemImage: "target")
                    if let avg = session.averageMetrics {
                        Label(String(format: "%.0f mph avg", avg.ballSpeed), systemImage: "speedometer")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                sessionStore.deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func monthString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: GolfSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Session averages
                        if let avg = session.averageMetrics {
                            SessionAveragesView(metrics: avg)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }

                        // Shot list
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ALL SHOTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)
                                .padding(.horizontal, 16)

                            ForEach(session.shots.reversed()) { shot in
                                ShotRowView(shot: shot)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.06, green: 0.07, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct SessionAveragesView: View {
    let metrics: LaunchMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SESSION AVERAGES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SmallMetricCell(label: "Ball Speed", value: String(format: "%.1f", metrics.ballSpeed), unit: "mph")
                SmallMetricCell(label: "Club Speed", value: String(format: "%.1f", metrics.clubSpeed), unit: "mph")
                SmallMetricCell(label: "Smash Factor", value: String(format: "%.3f", metrics.smashFactor), unit: "")
                SmallMetricCell(label: "Spin Rate", value: String(format: "%.0f", metrics.spinRate), unit: "rpm")
                SmallMetricCell(label: "Launch Angle", value: String(format: "%.1f", metrics.launchAngle), unit: "°")
                SmallMetricCell(label: "Carry", value: String(format: "%.0f", metrics.carryDistance), unit: "yds")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

struct SmallMetricCell: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct ShotRowView: View {
    let shot: ShotData
    @State private var expanded = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Club label
                    Text(shot.club.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, alignment: .leading)

                    // Key stats
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f mph", shot.metrics.ballSpeed))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.0f yds", shot.metrics.carryDistance))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        HStack(spacing: 8) {
                            Text(String(format: "LA: %.1f°", shot.metrics.launchAngle))
                            Text(String(format: "SF: %.3f", shot.metrics.smashFactor))
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        ShotShapeBadge(shotData: shot)
                        Text(Self.timeFormatter.string(from: shot.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())

            if expanded {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)

                VStack(spacing: 0) {
                    MetricRow(label: "Club Speed", value: String(format: "%.1f", shot.metrics.clubSpeed), unit: "mph", color: .cyan)
                    MetricRow(label: "Spin Rate", value: String(format: "%.0f", shot.metrics.spinRate), unit: "rpm", color: .orange)
                    MetricRow(label: "Club Path", value: String(format: "%+.1f", shot.metrics.clubPath), unit: "°", color: .white)
                    MetricRow(label: "Face Angle", value: String(format: "%+.1f", shot.metrics.faceAngle), unit: "°", color: .white)
                    MetricRow(label: "Attack Angle", value: String(format: "%+.1f", shot.metrics.attackAngle), unit: "°", color: .white)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.2))

            VStack(spacing: 8) {
                Text("No sessions yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text("Record your first golf shot using the camera to see your launch metrics here.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
