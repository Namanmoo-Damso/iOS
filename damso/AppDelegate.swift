import UIKit
import UserNotifications
import PushKit
import Security
import Security

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, PKPushRegistryDelegate {
    private let callManager = CallManager.shared
    private var voipRegistry: PKPushRegistry?
    private let identityKey = "user_identity"
    private let apnsKey = "cached_apns_token"
    private let voipKey = "cached_voip_token"
    private var apnsEnv: String {
        resolveApnsEnv()
    }
    private var bundleId: String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle"
    }
    private var expectedVoipTopic: String {
        "\(bundleId).voip"
    }
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AppDelegate] \(message)")
        #endif
    }
    private func diagLog(_ message: String) {
        guard AppConfig.enablePushDiagnostics else { return }
        print("[PushDiagnostics] \(message)")
    }
    private func appVersionString() -> String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func resolveApnsEnv() -> String {
        #if DEBUG
        return "dev"
        #else
        return "prod"
        #endif
    }

    private func summarizeToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "none" }
        let suffix = token.suffix(6)
        return "len=\(token.count) ..\(suffix)"
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        debugLog("didFinishLaunching env=\(apnsEnv)")
        diagLog("launch env=\(apnsEnv) bundle=\(bundleId) voipTopic=\(expectedVoipTopic) version=\(appVersionString()) device=\(UIDevice.current.model) system=\(UIDevice.current.systemVersion)")
        
        // iPad 등에서 초기화 타이밍 문제 방지를 위해 비동기 실행
        DispatchQueue.main.async {
            self.configureUserNotifications(application)
            self.configureVoipPushRegistry()
            self.registerCachedTokensIfAvailable()
        }
        return true
    }

    private func configureUserNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
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
        debugLog("configuring VoIP push registry")
        diagLog("configuring VoIP push registry (expected headers apns-push-type=voip, apns-topic=\(expectedVoipTopic))")
        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry
    }

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

    // ... (rest of methods)

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        debugLog("VoIP token updated \(summarizeToken(token))")
        diagLog("VoIP token full=\(token)")
        diagLog("expected headers apns-push-type=voip apns-topic=\(expectedVoipTopic)")
        registerDeviceToken(apnsToken: nil, voipToken: token)
    }

    private func registerCachedTokensIfAvailable() {
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

    private func registerDeviceToken(apnsToken: String?, voipToken: String?) {
        let identity = stableIdentity()
        debugLog("registerDeviceToken identity=\(identity) env=\(apnsEnv) apns=\(summarizeToken(apnsToken)) voip=\(summarizeToken(voipToken))")
        if let apnsToken { debugLog("registerDeviceToken env=\(apnsEnv) apns=\(apnsToken)") }
        if let voipToken { debugLog("registerDeviceToken env=\(apnsEnv) voip=\(voipToken)") }

        let apiBase: String = AppConfig.apiBaseURL
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
        
        var body: [String: Any] = [
            "identity": identity,
            "displayName": "iOS User",
            "platform": "ios",
            "env": apnsEnv
        ]
        if let apns = currentApns, !apns.isEmpty {
            body["apnsToken"] = apns
        }
        if let voip = currentVoip, !voip.isEmpty {
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

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        debugLog("VoIP token invalidated")
        diagLog("VoIP token invalidated")
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        handleIncomingVoipPush(payload: payload, completion: completion)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) {
        handleIncomingVoipPush(payload: payload, completion: nil)
    }

    private func handleIncomingVoipPush(payload: PKPushPayload, completion: (() -> Void)?) {
        let payloadData = payload.dictionaryPayload
        let payloadKeys = payloadData.keys.map { "\($0)" }.joined(separator: ",")
        
        let callId = payloadData["callId"] as? String ?? payloadData["call_id"] as? String
        let type = (payloadData["type"] as? String)?.uppercased() ?? "INVITE"
        
        debugLog("voip push received type=\(type) keys=[\(payloadKeys)] callId=\(callId ?? "nil")")
        diagLog("voip push received type=\(type) keys=[\(payloadKeys)] callId=\(callId ?? "nil")")

        // 통화 종료 푸시 처리 (백그라운드에서 CallKit 종료용)
        if type == "BYE" || type == "END" || type == "DISCONNECT" {
            if let uuidString = callId, let uuid = UUID(uuidString: uuidString) {
                debugLog("ending call via push uuid=\(uuid)")
                callManager.endCall(uuid: uuid)
            }
            completion?()
            return
        }

        // 통화 초대 처리 (기본값)
        let caller = payloadData["callerName"] as? String
            ?? payloadData["caller"] as? String
            ?? payloadData["callerIdentity"] as? String
            ?? "Unknown"
        let roomName = payloadData["roomName"] as? String ?? payloadData["room_name"] as? String
        let hasVideo = payloadData["hasVideo"] as? Bool
            ?? payloadData["has_video"] as? Bool
            ?? true
        let uuid = UUID(uuidString: callId ?? "") ?? UUID()

        callManager.reportIncomingCall(
            uuid: uuid,
            handle: caller,
            hasVideo: hasVideo,
            callId: callId,
            roomName: roomName
        ) { error in
            if let error = error {
                print("CallKit report failed:", error)
            }
            completion?()
        }
    }
}

