import Foundation
#if canImport(LiveKit)
import LiveKit

// MARK: - Type Alias for concrete ViewModel
typealias AppLiveKitViewModel = LiveKitViewModel<LiveKitService, AuthService, CallStateStore, CallManager>

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Core Services (Singleton references)

    private(set) lazy var liveKitService: LiveKitService = LiveKitService()
    private(set) lazy var authService: AuthService = AuthService()
    private(set) lazy var networkMonitor: NetworkMonitor = NetworkMonitor.shared
    private(set) lazy var callManager: CallManager = CallManager.shared
    private(set) lazy var callStateStore: CallStateStore = CallStateStore.shared

    // MARK: - Additional Services

    private(set) lazy var locationService: LocationService = LocationService.shared
    private(set) lazy var userService: UserService = UserService.shared
    private(set) lazy var careAlertService: CareAlertService = CareAlertService.shared
    private(set) lazy var pushNotificationService: PushNotificationService = PushNotificationService.shared
    private(set) lazy var wardSettingsService: WardSettingsService = WardSettingsService.shared
    private(set) lazy var callService: CallService = CallService.shared
    
    // MARK: - Repositories
    
    private(set) lazy var authRepository: AuthRepositoryProtocol = AuthRepository.shared

    private init() {}

    // MARK: - ViewModel Factory Methods

    /// LiveKitViewModel 생성
    func makeLiveKitViewModel() -> AppLiveKitViewModel {
        AppLiveKitViewModel(
            liveKitService: liveKitService,
            authService: authService,
            callStateStore: callStateStore,
            callManager: callManager
        )
    }

    /// WardHomeViewModel 생성
    func makeWardHomeViewModel() -> WardHomeViewModel {
        WardHomeViewModel(
            locationService: locationService,
            callService: callService
        )
    }

    /// WardSettingsViewModel 생성
    func makeWardSettingsViewModel() -> WardSettingsViewModel {
        WardSettingsViewModel(
            userService: userService,
            wardSettingsService: wardSettingsService,
            locationService: locationService
        )
    }

    /// CallHistoryViewModel 생성
    func makeCallHistoryViewModel() -> CallHistoryViewModel {
        CallHistoryViewModel(callService: callService)
    }

    /// GuardianSettingsViewModel 생성
    func makeGuardianSettingsViewModel() -> GuardianSettingsViewModel {
        GuardianSettingsViewModel(
            userService: userService,
            authRepository: authRepository
        )
    }

    /// NotificationSettingsViewModel 생성
    func makeNotificationSettingsViewModel() -> NotificationSettingsViewModel {
        NotificationSettingsViewModel(pushNotificationService: pushNotificationService)
    }

    /// CallDetailViewModel 생성
    func makeCallDetailViewModel(call: RecentCall) -> CallDetailViewModel {
        CallDetailViewModel(call: call, callService: callService)
    }

    /// AlertDetailViewModel 생성
    func makeAlertDetailViewModel(alert: DashboardAlert) -> AlertDetailViewModel {
        AlertDetailViewModel(alert: alert, careAlertService: careAlertService)
    }
}
#endif

