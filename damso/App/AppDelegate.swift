import UIKit
import UserNotifications
import PushKit
import CallKit
import KakaoSDKCommon
import KakaoSDKAuth

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Properties

    let callManager = CallManager.shared
    var voipRegistry: PKPushRegistry?

    var apnsEnv: String { resolveApnsEnv() }
    var bundleId: String { Bundle.main.bundleIdentifier ?? "unknown.bundle" }
    var expectedVoipTopic: String { "\(bundleId).voip" }

    // MARK: - Logging

    nonisolated func debugLog(_ message: String) {
        #if DEBUG
        print("[AppDelegate] \(message)")
        #endif
    }

    nonisolated func diagLog(_ message: String) {
        guard AppConfig.enablePushDiagnostics else { return }
        print("[PushDiagnostics] \(message)")
    }

    // MARK: - Utilities

    private func appVersionString() -> String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func resolveApnsEnv() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "prod"
        #endif
    }

    func summarizeToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "none" }
        let suffix = token.suffix(6)
        return "len=\(token.count) ..\(suffix)"
    }

    // MARK: - App Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        debugLog("didFinishLaunching env=\(apnsEnv)")
        diagLog("launch env=\(apnsEnv) bundle=\(bundleId) voipTopic=\(expectedVoipTopic) version=\(appVersionString()) device=\(UIDevice.current.model) system=\(UIDevice.current.systemVersion)")

        // Kakao SDK 초기화
        if let kakaoAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String {
            KakaoSDK.initSDK(appKey: kakaoAppKey)
            debugLog("Kakao SDK initialized")
        }

        // iPad 등에서 초기화 타이밍 문제 방지를 위해 비동기 실행
        DispatchQueue.main.async {
            self.configureUserNotifications(application)
            self.configureVoipPushRegistry()
            self.logCachedTokens()
        }

        // VAD 모델 미리 로드 (통화 시작 전 준비)
        Task { @MainActor in
            await VadService.shared.loadModel()
        }

        return true
    }

    // MARK: - Kakao Login URL Handler

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        debugLog("🔵 openURL 호출됨: \(url.scheme ?? "no scheme")")
        if AuthApi.isKakaoTalkLoginUrl(url) {
            debugLog("🔵 카카오 로그인 URL 감지 - handleOpenUrl 호출")
            let result = AuthController.handleOpenUrl(url: url)
            debugLog("🔵 handleOpenUrl 결과: \(result)")
            return result
        }
        debugLog("🔵 카카오 로그인 URL 아님")
        return false
    }

    // MARK: - Universal Links Handler

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        debugLog("🔗 Universal Link 수신")

        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            debugLog("🔗 Universal Link 아님")
            return false
        }

        debugLog("🔗 Universal Link URL: \(url)")

        // DeeplinkManager로 처리 위임
        Task { @MainActor in
            DeeplinkManager.shared.handleUniversalLink(url: url)
        }

        return true
    }

    // MARK: - Notification Setup

    private func configureUserNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 통화 알림용 액션 정의 (WiFi-only iPad용)
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_CALL",
            title: "수락",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_CALL",
            title: "거절",
            options: [.destructive]
        )
        let callCategory = UNNotificationCategory(
            identifier: "INCOMING_CALL",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([callCategory])

        // 알림 권한 요청은 PermissionOnboardingView에서 처리
        // 이미 권한이 부여된 경우에만 원격 알림 등록
        center.getNotificationSettings { settings in
            self.debugLog("notification settings status=\(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    private func configureVoipPushRegistry() {
        let capability = resolveCallCapability()
        diagLog("device capability: \(capability)")

        switch capability {
        case .callKit:
            // CallKit 지원 디바이스: VoIP 푸시 등록
            debugLog("configuring VoIP push registry")
            diagLog("configuring VoIP push registry (expected headers apns-push-type=voip, apns-topic=\(expectedVoipTopic))")
            let registry = PKPushRegistry(queue: DispatchQueue.main)
            registry.delegate = self
            registry.desiredPushTypes = [.voIP]
            voipRegistry = registry

        case .notificationOnly:
            // WiFi-only iPad: VoIP 푸시 등록하지 않음 (일반 APNs만 사용)
            debugLog("skipping VoIP registry (CallKit not supported on this device)")
            diagLog("WiFi-only iPad detected - using regular APNs for call notifications")
        }
    }

    // MARK: - APNs Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        debugLog("APNs token updated \(summarizeToken(token))")
        diagLog("APNs token full=\(token)")
        registerDeviceToken(apnsToken: token, voipToken: nil)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        debugLog("APNs registration failed: \(error)")
        diagLog("APNs registration failed: \(error)")
    }

    // MARK: - Token Caching

    /// 캐시된 토큰 로그 출력 (디버깅용)
    func logCachedTokens() {
        let apnsToken = UserDefaults.standard.cachedApnsToken
        let voipToken = UserDefaults.standard.cachedVoipToken
        debugLog("cached tokens apns=\(summarizeToken(apnsToken)) voip=\(summarizeToken(voipToken))")
        if let apnsToken { diagLog("cached APNs token full=\(apnsToken)") }
        if let voipToken { diagLog("cached VoIP token full=\(voipToken)") }
    }

    /// 디바이스 토큰 캐싱 (서버 등록은 로그인 후 AuthService/PushNotificationService에서 처리)
    func registerDeviceToken(apnsToken: String?, voipToken: String?) {
        // 토큰 캐싱만 수행 (로그인 전에도 토큰은 저장)
        if let newApns = apnsToken {
            UserDefaults.standard.cachedApnsToken = newApns
            debugLog("APNs token cached: \(summarizeToken(newApns))")
        }
        if let newVoip = voipToken {
            UserDefaults.standard.cachedVoipToken = newVoip
            debugLog("VoIP token cached: \(summarizeToken(newVoip))")
        }

        // 서버 등록은 로그인 후 AuthService.loginWithKakao에서
        // PushNotificationService.registerDeviceTokens를 호출하여 처리
    }
}
