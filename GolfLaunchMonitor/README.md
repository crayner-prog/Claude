# Golf Launch Monitor

A professional golf launch monitor app for iPhone 15 Pro Max, using computer vision to measure key shot metrics.

## Key Metrics

| Metric | Method | Accuracy |
|--------|--------|----------|
| **Ball Speed** | Optical tracking via Vision framework | High (calibrated) |
| **Club Speed** | Club head tracking at impact | High |
| **Smash Factor** | Ball Speed ÷ Club Speed | Derived |
| **Spin Rate** | Physics-based model | Estimated ~±15% |
| **Launch Angle** | Ball trajectory angle from horizontal | High |
| **Club Path** | Club head path direction at impact | Medium-High |
| **Face Angle** | Derived from D-Plane + launch direction | Medium |

## iPhone 15 Pro Max Features Used

- **240fps Slow-Mo** at 1080p — captures ball flight with enough frames for accurate velocity measurement
- **A17 Pro chip** — real-time Vision framework processing
- **Triple camera system** — telephoto (3×) lens for better ball isolation
- **LiDAR scanner** — depth calibration (future enhancement)

## Setup Requirements

### Hardware
- iPhone 15 Pro Max (recommended) or any modern iPhone with 240fps capability
- Tripod or stable mount
- Good lighting conditions

### Camera Position
```
         [iPhone on tripod]
               |
               | 8–12 feet
               |
          [Impact zone]  -----> Target line
```

- **Height**: Waist height (~3 feet) for ideal impact zone coverage
- **Distance**: 8–12 feet behind the ball, parallel to target line
- **Angle**: Camera faces perpendicular to the target line

## Building the App

### Prerequisites
- Xcode 15.2+
- iOS 17.0+ deployment target
- XcodeGen (optional, for project generation)

### Option 1: XcodeGen (Recommended)
```bash
# Install XcodeGen
brew install xcodegen

# Generate Xcode project
cd GolfLaunchMonitor
xcodegen generate

# Open in Xcode
open GolfLaunchMonitor.xcodeproj
```

### Option 2: Manual Xcode Setup
1. Open Xcode → File → New → Project
2. Choose "App" template with SwiftUI
3. Set Bundle ID: `com.golflaunchmonitor.app`
4. Add all Swift files from the `GolfLaunchMonitor/` directory
5. Set deployment target to iOS 17.0
6. Add camera permissions to Info.plist:
   - `NSCameraUsageDescription`
   - `NSPhotoLibraryUsageDescription`

## Architecture

```
GolfLaunchMonitor/
├── App/
│   └── GolfLaunchMonitorApp.swift     # @main entry point
├── Models/
│   ├── ClubType.swift                  # Club database with loft/length data
│   ├── ShotData.swift                  # Shot metrics & tracking data
│   └── Session.swift                   # Session management & persistence
├── Services/
│   ├── CameraService.swift             # AVFoundation 240fps camera setup
│   ├── BallTracker.swift               # Vision framework ball tracking + Kalman filter
│   ├── ClubTracker.swift               # Club head tracking & path analysis
│   ├── MetricsCalculator.swift         # Physics-based metrics computation
│   └── VideoAnalyzer.swift             # Analysis pipeline orchestrator
├── ViewModels/
│   └── LaunchMonitorViewModel.swift    # Main app state & business logic
└── Views/
    ├── ContentView.swift               # Root navigation
    ├── Screens/
    │   ├── CameraScreenView.swift      # Live camera + tracking overlay
    │   ├── ResultsScreenView.swift     # Shot metrics display
    │   ├── HistoryView.swift           # Session history & stats
    │   └── SetupView.swift             # Club selection & calibration
    ├── Components/
    │   └── MetricCard.swift            # Reusable metric display components
    └── Extensions/
        └── CGPoint+Extensions.swift   # Geometry helpers
```

## Limitations & Notes

### Spin Rate
Spin rate cannot be directly measured optically without special ball markers. The app uses a physics-based model based on:
- Club type and loft
- Ball speed and club speed
- Face angle and attack angle

For measured spin rate, apply reflective dot stickers to the ball (as used in research studies).

### Face Angle
Face angle is estimated from the D-Plane relationship:
- Ball starts ~75-80% toward where the face points (relative to club path)
- Working backwards from launch direction gives approximate face angle

### Calibration
For accurate speed measurements in real-world units:
1. Place the club shaft in the camera frame
2. Use the calibration tool to mark the shaft length in pixels
3. Enter the known club length — the app calculates pixels-per-inch

Without calibration, relative comparisons between shots are still valid.

## Physics Models

### Ball Speed → Carry Distance
Uses a simplified ballistic model with:
- Drag coefficient: 0.21 (dimpled golf ball)
- Magnus force (lift from backspin)
- Sea-level air density

### Smash Factor
Standard definition: `Ball Speed ÷ Club Speed`
- Driver optimal: 1.44–1.52
- Higher = more efficient energy transfer

## Comparison with Commercial Launch Monitors

| Feature | This App | TrackMan | FlightScope |
|---------|----------|----------|-------------|
| Ball Speed | Optical | Radar | Radar |
| Club Speed | Optical | Radar | Radar |
| Spin Rate | Estimated | Measured | Measured |
| Face Angle | Estimated | Measured | Measured |
| Price | Free | $25,000+ | $5,000+ |

This app provides a practical tool for practice feedback. For tournament-grade precision, use radar-based devices.
