import PushKit
import UIKit

// MARK: - PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {

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
        completion: @escaping @Sendable () -> Void
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

    func handleIncomingVoipPush(payload: PKPushPayload, completion: (@Sendable () -> Void)?) {
        let payloadData = payload.dictionaryPayload
        let payloadKeys = payloadData.keys.map { "\($0)" }.joined(separator: ",")

        let callId = payloadData["callId"] as? String ?? payloadData["call_id"] as? String
        let type = (payloadData["type"] as? String)?.uppercased() ?? "INVITE"

        print("📥 [VoIP] ========== PUSH RECEIVED ==========")
        print("📥 [VoIP] type=\(type) callId=\(callId ?? "nil")")
        print("📥 [VoIP] keys=[\(payloadKeys)]")
        print("📥 [VoIP] payload=\(payloadData)")
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

        // 앱 상태 확인
        let isForeground = UIApplication.shared.applicationState == .active

        print("📥 [VoIP] App state: \(isForeground ? "FOREGROUND" : "BACKGROUND")")
        print("📥 [VoIP] uuid=\(uuid) caller=\(caller) roomName=\(roomName ?? "nil") hasVideo=\(hasVideo)")

        if isForeground {
            // Foreground: Custom UI 사용, CallKit 리포트 후 즉시 종료
            print("📥 [VoIP] 🎨 Foreground - Using custom incoming call UI")

            // CallKit에 리포트 (iOS 필수 요구사항)
            callManager.reportIncomingCall(
                uuid: uuid,
                handle: caller,
                hasVideo: hasVideo,
                callId: callId,
                roomName: roomName
            ) { [self] error in
                if let error = error {
                    print("📥 [VoIP] ❌ CallKit report failed: \(error)")
                } else {
                    print("📥 [VoIP] ✅ CallKit reported, immediately ending to hide UI")
                    // CallKit UI가 뜨기 전에 즉시 종료 (reason: answeredElsewhere로 우리가 처리한다고 알림)
                    Task { @MainActor in
                        self.callManager.reportCallEnded(uuid: uuid, reason: .answeredElsewhere)
                    }
                }

                // Custom UI 표시
                Task { @MainActor in
                    CallStateStore.shared.setIncoming(
                        uuid: uuid,
                        callId: callId,
                        handle: caller,
                        hasVideo: hasVideo,
                        roomName: roomName
                    )
                }
                completion?()
            }
        } else {
            // Background: 일반 CallKit 플로우
            print("📥 [VoIP] 📱 Background - Using CallKit UI")

            callManager.reportIncomingCall(
                uuid: uuid,
                handle: caller,
                hasVideo: hasVideo,
                callId: callId,
                roomName: roomName
            ) { error in
                if let error = error {
                    print("📥 [VoIP] ❌ CallKit report failed: \(error)")
                } else {
                    print("📥 [VoIP] ✅ CallKit report success")
                }
                completion?()
            }
        }
    }
}
