import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LaunchMonitorViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.currentScreen {
            case .camera:
                CameraScreenView()
            case .results:
                ResultsScreenView()
            case .history:
                HistoryView()
            case .setup:
                SetupView()
            }
        }
        .environmentObject(viewModel)
        .task {
            viewModel.setSessionStore(sessionStore)
            await viewModel.startCamera()
        }
        .alert("Camera Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}
