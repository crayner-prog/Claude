import SwiftUI

// MARK: - Setup Screen

struct SetupView: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var sessionName = ""
    @State private var showingCalibrationGuide = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Club selection
                        ClubSelectionSection()

                        // Session setup
                        SessionSetupSection(sessionName: $sessionName)

                        // Camera setup
                        CameraSetupSection()

                        // Calibration
                        CalibrationSection()

                        // Tips
                        SetupTipsCard()
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(red: 0.06, green: 0.07, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.currentScreen = .camera
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if !sessionName.isEmpty {
                            sessionStore.startNewSession(name: sessionName)
                        }
                        viewModel.currentScreen = .camera
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Club Selection Section

struct ClubSelectionSection: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @State private var selectedCategory = "Irons"

    private let categories = ["Woods", "Hybrids", "Irons", "Wedges"]

    var body: some View {
        SetupCard(title: "Club Selection", icon: "figure.golf", iconColor: .green) {
            VStack(spacing: 14) {
                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedCategory == category ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedCategory == category
                                        ? Color.green
                                        : Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                }

                // Club grid for selected category
                let clubs = ClubType.allCases.filter { $0.category == selectedCategory }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(clubs) { club in
                        ClubGridCell(
                            club: club,
                            isSelected: viewModel.selectedClub == club
                        ) {
                            viewModel.selectClub(club)
                        }
                    }
                }

                // Selected club details
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedClub.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 16) {
                            Label(String(format: "%.1f° loft", viewModel.selectedClub.typicalLoft),
                                  systemImage: "angle")
                            Label(String(format: "%.1f\" length", viewModel.selectedClub.typicalLength),
                                  systemImage: "ruler")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Target Smash")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        let range = viewModel.selectedClub.smashFactorRange
                        Text(String(format: "%.2f–%.2f", range.lowerBound, range.upperBound))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
}

struct ClubGridCell: View {
    let club: ClubType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(club.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .black : .white)

                Text("\(Int(club.typicalLoft))°")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .black.opacity(0.7) : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.green : Color.white.opacity(0.08))
            .cornerRadius(8)
        }
    }
}

// MARK: - Session Setup

struct SessionSetupSection: View {
    @Binding var sessionName: String
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        SetupCard(title: "Session", icon: "folder.fill", iconColor: .blue) {
            VStack(spacing: 12) {
                TextField("Session name (optional)", text: $sessionName)
                    .textFieldStyle(DarkTextFieldStyle())
                    .submitLabel(.done)

                if let current = sessionStore.currentSession {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 8))
                        Text("Active: \(current.name)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(current.shots.count) shots")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

// MARK: - Camera Setup Section

struct CameraSetupSection: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel

    var body: some View {
        SetupCard(title: "Camera Settings", icon: "camera.fill", iconColor: .cyan) {
            VStack(spacing: 16) {
                // Frame rate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Frame Rate")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(viewModel.frameRate)) fps")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Slider(value: $viewModel.frameRate, in: 60...240, step: 60)
                        .tint(.cyan)
                    HStack {
                        Text("60fps")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("240fps recommended")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Handedness
                VStack(alignment: .leading, spacing: 8) {
                    Text("Handedness")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Picker("Handedness", selection: $viewModel.handedness) {
                        ForEach(Handedness.allCases, id: \.self) { h in
                            Text(h.rawValue).tag(h)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().background(Color.white.opacity(0.1))

                // Units
                VStack(alignment: .leading, spacing: 8) {
                    Text("Units")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Picker("Units", selection: $viewModel.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

// MARK: - Calibration Section

struct CalibrationSection: View {
    @EnvironmentObject private var viewModel: LaunchMonitorViewModel
    @State private var referenceInches = ""

    var body: some View {
        SetupCard(
            title: "Distance Calibration",
            icon: viewModel.isCalibrated ? "checkmark.seal.fill" : "ruler.fill",
            iconColor: viewModel.isCalibrated ? .green : .orange
        ) {
            VStack(spacing: 14) {
                if viewModel.isCalibrated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Calibrated for accurate speed readings")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Button("Recalibrate") {
                        viewModel.isCalibrated = false
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("For accurate speed readings, calibrate the camera by placing your club shaft in view and entering its length.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Your \(viewModel.selectedClub.rawValue) is approximately \(String(format: "%.1f\"", viewModel.selectedClub.typicalLength)) long.")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                    }

                    // Auto-calibration button
                    Button {
                        // Use default club length calibration
                        viewModel.calibrateWithClub(pixelLength: 300) // User would drag on screen
                        viewModel.isCalibrated = true
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Auto-calibrate with \(viewModel.selectedClub.rawValue)")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
}

// MARK: - Setup Tips

struct SetupTipsCard: View {
    var body: some View {
        SetupCard(title: "Setup Tips", icon: "lightbulb.fill", iconColor: .yellow) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(tips, id: \.title) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tip.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(tip.description)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
    }

    private let tips: [(title: String, description: String, icon: String)] = [
        (
            title: "Camera Position",
            description: "Place iPhone on a tripod at waist height, 8-12 feet behind the ball, facing down the target line.",
            icon: "camera.on.rectangle"
        ),
        (
            title: "240fps Mode",
            description: "Use 240fps for best tracking accuracy. The ball travels 100+ mph and needs high frame rates.",
            icon: "video.fill"
        ),
        (
            title: "Lighting",
            description: "Film in good natural light or well-lit conditions. Avoid harsh backlighting.",
            icon: "sun.max.fill"
        ),
        (
            title: "Ball Visibility",
            description: "Ensure the ball is clearly visible and contrasts with the background before arming.",
            icon: "circle.fill"
        ),
        (
            title: "Spin Rate Note",
            description: "Spin rate is estimated from physics models. For measured spin, use reflective dot stickers on the ball.",
            icon: "info.circle"
        )
    ]
}

// MARK: - Reusable Card

struct SetupCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            content
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Text Field Style

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 15))
            .foregroundColor(.white)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}
