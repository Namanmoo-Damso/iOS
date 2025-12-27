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
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AppDelegate] \(message)")
        #endif
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
        configureUserNotifications(application)
        configureVoipPushRegistry()
        registerCachedTokensIfAvailable()
        return true
    }

    private func configureUserNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        debugLog("requesting notification authorization")
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                self.debugLog("notification authorization error: \(error)")
            } else {
                self.debugLog("notification authorization granted=\(granted)")
            }
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    private func configureVoipPushRegistry() {
        debugLog("configuring VoIP push registry")
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
        registerDeviceToken(apnsToken: token, voipToken: nil)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        debugLog("APNs registration failed: \(error)")
    }

    // ... (rest of methods)

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        debugLog("VoIP token updated \(summarizeToken(token))")
        registerDeviceToken(apnsToken: nil, voipToken: token)
    }

    private func registerCachedTokensIfAvailable() {
        let apnsToken = UserDefaults.standard.string(forKey: apnsKey)
        let voipToken = UserDefaults.standard.string(forKey: voipKey)
        debugLog("cached tokens apns=\(summarizeToken(apnsToken)) voip=\(summarizeToken(voipToken))")
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

        let url = URL(string: "\(AppConfig.apiBaseURL)/v1/devices/register")!
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
        let caller = payloadData["callerName"] as? String
            ?? payloadData["caller"] as? String
            ?? payloadData["callerIdentity"] as? String
            ?? "Unknown"
        let roomName = payloadData["roomName"] as? String ?? payloadData["room_name"] as? String
        let hasVideo = payloadData["hasVideo"] as? Bool
            ?? payloadData["has_video"] as? Bool
            ?? true
        let uuid = UUID(uuidString: callId ?? "") ?? UUID()
        debugLog("voip push received keys=[\(payloadKeys)] callId=\(callId ?? "nil") room=\(roomName ?? "nil") caller=\(caller) hasVideo=\(hasVideo)")

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

