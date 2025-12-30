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

    private let identityKey = "user_identity"
    private let apnsKey = "cached_apns_token"
    private let voipKey = "cached_voip_token"

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
            self.registerCachedTokensIfAvailable()
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

        debugLog("requesting notification authorization")
        diagLog("requesting notification authorization")
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                self.debugLog("notification authorization error: \(error)")
                self.diagLog("notification authorization error: \(error)")
            } else {
                self.debugLog("notification authorization granted=\(granted)")
                self.diagLog("notification authorization granted=\(granted)")
            }
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
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

    // MARK: - Token Registration

    func registerCachedTokensIfAvailable() {
        let apnsToken = UserDefaults.standard.string(forKey: apnsKey)
        let voipToken = UserDefaults.standard.string(forKey: voipKey)
        debugLog("cached tokens apns=\(summarizeToken(apnsToken)) voip=\(summarizeToken(voipToken))")
        if let apnsToken { diagLog("cached APNs token full=\(apnsToken)") }
        if let voipToken { diagLog("cached VoIP token full=\(voipToken)") }
        if apnsToken != nil || voipToken != nil {
            registerDeviceToken(apnsToken: apnsToken, voipToken: voipToken)
        }
    }

    private func stableIdentity() -> String {
        if let stored = UserDefaults.standard.string(forKey: identityKey) {
            return stored
        }
        let newIdentity = "ios-\(UUID().uuidString)"
        UserDefaults.standard.set(newIdentity, forKey: identityKey)
        return newIdentity
    }

    func registerDeviceToken(apnsToken: String?, voipToken: String?) {
        let identity = stableIdentity()
        debugLog("registerDeviceToken identity=\(identity) env=\(apnsEnv) apns=\(summarizeToken(apnsToken)) voip=\(summarizeToken(voipToken))")

        let apiBase = AppConfig.apiBaseURL
        let urlString = "\(apiBase)/v1/devices/register"
        guard let url = URL(string: urlString) else {
            debugLog("Failed to create URL from: \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var currentApns = apnsToken
        var currentVoip = voipToken

        if let newApns = apnsToken {
            UserDefaults.standard.set(newApns, forKey: apnsKey)
        } else {
            currentApns = UserDefaults.standard.string(forKey: apnsKey)
        }

        if let newVoip = voipToken {
            UserDefaults.standard.set(newVoip, forKey: voipKey)
        } else {
            currentVoip = UserDefaults.standard.string(forKey: voipKey)
        }

        let supportsCallKit = resolveCallCapability() == .callKit
        var body: [String: Any] = [
            "identity": identity,
            "displayName": "iOS User",
            "platform": "ios",
            "env": apnsEnv,
            "supportsCallKit": supportsCallKit
        ]
        if let apns = currentApns, !apns.isEmpty {
            body["apnsToken"] = apns
        }
        // WiFi-only iPad는 voipToken을 전송하지 않음
        if supportsCallKit, let voip = currentVoip, !voip.isEmpty {
            body["voipToken"] = voip
        }
        if body["apnsToken"] == nil && body["voipToken"] == nil {
            debugLog("skip registerDeviceToken (no tokens)")
            return
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to serialize register body:", error)
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    debugLog("device registered status=\(httpResponse.statusCode)")
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        let bodyText = String(data: data, encoding: .utf8) ?? ""
                        debugLog("device registration failed status=\(httpResponse.statusCode) body=\(bodyText)")
                    }
                }
            } catch {
                debugLog("device registration error: \(error)")
            }
        }
    }
}
