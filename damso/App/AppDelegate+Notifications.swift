import UserNotifications

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// 포그라운드에서 알림 수신 시 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let category = notification.request.content.categoryIdentifier
        let capability = resolveCallCapability()

        debugLog("willPresent category=\(category) capability=\(capability)")
        diagLog("willPresent userInfo=\(userInfo)")

        // WiFi-only iPad에서 통화 알림을 포그라운드에서 받은 경우
        if category == "INCOMING_CALL" && capability == .notificationOnly {
            debugLog("foreground call notification received (WiFi iPad)")
            handleIncomingCallFromAPNs(userInfo: userInfo)
            // 시스템 배너 숨기고 커스텀 UI만 표시
            completionHandler([])
            return
        }

        // 기타 알림은 기본 표시
        completionHandler([.banner, .sound, .badge])
    }

    /// 일반 알림 탭 처리 (통화 알림 외)
    private func handleGeneralNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        debugLog("handleGeneralNotificationTap type=\(type)")

        Task { @MainActor in
            switch type {
            case "call_reminder":
                // 통화 리마인더 → 홈 화면으로 이동
                NotificationCenter.default.post(
                    name: .navigateToTab,
                    object: nil,
                    userInfo: ["tab": "home"]
                )

            case "health_alert":
                // 건강 알림 → 보고서 화면으로 이동
                NotificationCenter.default.post(
                    name: .navigateToTab,
                    object: nil,
                    userInfo: ["tab": "report"]
                )

            case "call_complete", "call_missed":
                // 통화 완료/미진행 → 대시보드로 이동
                NotificationCenter.default.post(
                    name: .navigateToTab,
                    object: nil,
                    userInfo: ["tab": "home"]
                )

            default:
                debugLog("Unknown notification type: \(type)")
            }
        }
    }

    /// 알림 액션(수락/거절) 또는 탭 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        let notificationId = response.notification.request.identifier

        // 일반 알림 탭 처리 (통화 알림 외)
        guard category == "INCOMING_CALL" else {
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                handleGeneralNotificationTap(userInfo: userInfo)
            }
            completionHandler()
            return
        }

        debugLog("notification action: \(response.actionIdentifier)")

        // 알림 제거
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])

        switch response.actionIdentifier {
        case "ACCEPT_CALL", UNNotificationDefaultActionIdentifier:
            // 수락 또는 알림 탭 → 바로 통화 시작
            handleAcceptCallFromAPNs(userInfo: userInfo)
        case "DECLINE_CALL":
            // 거절
            handleDeclineCallFromAPNs(userInfo: userInfo)
        case UNNotificationDismissActionIdentifier:
            // 알림 닫기 (무시)
            debugLog("call notification dismissed")
        default:
            break
        }

        completionHandler()
    }

    // MARK: - APNs Call Handlers

    /// 포그라운드에서 통화 알림 수신 시 (WiFi-only iPad) - 수신 UI 표시
    func handleIncomingCallFromAPNs(userInfo: [AnyHashable: Any]) {
        let callId = userInfo["callId"] as? String ?? userInfo["call_id"] as? String
        let roomName = userInfo["roomName"] as? String ?? userInfo["room_name"] as? String
        let caller = userInfo["callerName"] as? String
            ?? userInfo["caller"] as? String
            ?? "Unknown"
        let hasVideo = userInfo["hasVideo"] as? Bool
            ?? userInfo["has_video"] as? Bool
            ?? true

        debugLog("handleIncomingCallFromAPNs caller=\(caller) room=\(roomName ?? "nil") callId=\(callId ?? "nil")")

        Task { @MainActor in
            // 벨소리 + 진동 시작
            RingtonePlayer.shared.startRinging()

            CallStateStore.shared.setIncoming(
                uuid: UUID(),
                callId: callId,
                handle: caller,
                hasVideo: hasVideo,
                roomName: roomName
            )
        }
    }

    /// 알림에서 수락 버튼 탭 시 (WiFi-only iPad) - 바로 통화 시작
    func handleAcceptCallFromAPNs(userInfo: [AnyHashable: Any]) {
        let callId = userInfo["callId"] as? String ?? userInfo["call_id"] as? String
        let roomName = userInfo["roomName"] as? String ?? userInfo["room_name"] as? String
        let caller = userInfo["callerName"] as? String
            ?? userInfo["caller"] as? String
            ?? "Unknown"
        let hasVideo = userInfo["hasVideo"] as? Bool
            ?? userInfo["has_video"] as? Bool
            ?? true

        debugLog("handleAcceptCallFromAPNs caller=\(caller) room=\(roomName ?? "nil") callId=\(callId ?? "nil")")

        Task { @MainActor in
            // 벨소리 + 진동 중지
            RingtonePlayer.shared.stopRinging()

            CallStateStore.shared.setAnswered(
                uuid: UUID(),
                callId: callId,
                handle: caller,
                hasVideo: hasVideo,
                roomName: roomName
            )
        }
    }

    /// 일반 APNs에서 통화 거절 처리 (WiFi-only iPad)
    func handleDeclineCallFromAPNs(userInfo: [AnyHashable: Any]) {
        // 벨소리 + 진동 중지
        Task { @MainActor in
            RingtonePlayer.shared.stopRinging()
        }

        guard let callId = userInfo["callId"] as? String ?? userInfo["call_id"] as? String else {
            debugLog("decline call: no callId found")
            return
        }

        debugLog("handleDeclineCallFromAPNs callId=\(callId)")

        // 서버에 거절 알림
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/calls/end") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["callId": callId])

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                self.debugLog("decline call failed: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse {
                self.debugLog("decline call status=\(httpResponse.statusCode)")
            }
        }.resume()
    }
}
