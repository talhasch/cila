import Foundation

/// App-wide shared state.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: Keys.isPaused) }
    }

    private enum Keys {
        static let isPaused = "isPaused"
    }

    private init() {
        isPaused = UserDefaults.standard.bool(forKey: Keys.isPaused)
    }
}
