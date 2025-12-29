import Foundation
#if canImport(LiveKit)
import LiveKit

// MARK: - Type Alias for concrete ViewModel
typealias AppLiveKitViewModel = LiveKitViewModel<LiveKitService, AuthService, CallStateStore, CallManager>

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Services (Concrete types for composition root)

    private(set) lazy var liveKitService: LiveKitService = LiveKitService()
    private(set) lazy var authService: AuthService = AuthService()
    private(set) lazy var networkMonitor: NetworkMonitor = NetworkMonitor.shared
    private(set) lazy var callManager: CallManager = CallManager.shared
    private(set) lazy var callStateStore: CallStateStore = CallStateStore.shared

    private init() {}

    // MARK: - ViewModels

    func makeLiveKitViewModel() -> AppLiveKitViewModel {
        AppLiveKitViewModel(
            liveKitService: liveKitService,
            authService: authService,
            callStateStore: callStateStore,
            callManager: callManager
        )
    }
}
#endif
