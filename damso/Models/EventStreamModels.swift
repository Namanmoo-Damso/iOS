//
//  EventStreamModels.swift
//  damso
//
//  SSE (Server-Sent Events) 서비스 모델 정의
//  - GET /v1/events/stream: 실시간 이벤트 스트림
//

import Foundation

// MARK: - SSE 이벤트 데이터 페이로드

/// 케어 알림 이벤트 페이로드
struct CareAlertEventData: Codable, Equatable {
    /// 알림 고유 ID
    let alertId: String

    /// 알림 유형 (fall, emergency, abnormal_activity 등)
    let alertType: SSECareAlertType

    /// 어르신 ID
    let wardId: String

    /// 어르신 이름
    let wardName: String?

    /// 알림 메시지
    let message: String

    /// 심각도 (low, medium, high, critical)
    let severity: AlertSeverity

    /// 위치 정보
    let location: LocationData?

    /// 발생 시간
    let timestamp: Date

    /// 추가 메타데이터
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case alertId
        case alertType
        case wardId
        case wardName
        case message
        case severity
        case location
        case timestamp
        case metadata
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case alertId = "alert_id"
        case alertType = "alert_type"
        case wardId = "ward_id"
        case wardName = "ward_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // alertId
        if let val = try? container.decode(String.self, forKey: .alertId) {
            alertId = val
        } else {
            alertId = try snakeContainer.decode(String.self, forKey: .alertId)
        }

        // alertType
        if let val = try? container.decode(SSECareAlertType.self, forKey: .alertType) {
            alertType = val
        } else {
            alertType = try snakeContainer.decode(SSECareAlertType.self, forKey: .alertType)
        }

        // wardId
        if let val = try? container.decode(String.self, forKey: .wardId) {
            wardId = val
        } else {
            wardId = try snakeContainer.decode(String.self, forKey: .wardId)
        }

        // wardName
        if let val = try? container.decode(String.self, forKey: .wardName) {
            wardName = val
        } else {
            wardName = try? snakeContainer.decode(String.self, forKey: .wardName)
        }

        message = try container.decode(String.self, forKey: .message)
        severity = try container.decode(AlertSeverity.self, forKey: .severity)
        location = try? container.decode(LocationData.self, forKey: .location)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        metadata = try? container.decode([String: String].self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alertId, forKey: .alertId)
        try container.encode(alertType, forKey: .alertType)
        try container.encode(wardId, forKey: .wardId)
        try container.encodeIfPresent(wardName, forKey: .wardName)
        try container.encode(message, forKey: .message)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }

    // 코드에서 직접 생성용
    init(
        alertId: String,
        alertType: SSECareAlertType,
        wardId: String,
        wardName: String? = nil,
        message: String,
        severity: AlertSeverity,
        location: LocationData? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.alertId = alertId
        self.alertType = alertType
        self.wardId = wardId
        self.wardName = wardName
        self.message = message
        self.severity = severity
        self.location = location
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - SSE 케어 알림 유형

/// SSE 케어 알림 유형 enum (기존 CareAlertType과 구분)
enum SSECareAlertType: String, Codable, CaseIterable {
    /// 낙상 감지
    case fall

    /// 긴급 버튼
    case emergency

    /// 비정상 활동
    case abnormalActivity = "abnormal_activity"

    /// 장시간 무응답
    case noResponse = "no_response"

    /// 위치 이탈
    case outOfBounds = "out_of_bounds"

    /// 건강 이상
    case healthAnomaly = "health_anomaly"

    /// 기타
    case other

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .fall:
            return "낙상 감지"
        case .emergency:
            return "긴급 상황"
        case .abnormalActivity:
            return "비정상 활동"
        case .noResponse:
            return "무응답"
        case .outOfBounds:
            return "위치 이탈"
        case .healthAnomaly:
            return "건강 이상"
        case .other:
            return "기타 알림"
        }
    }

    /// 아이콘 이름
    var iconName: String {
        switch self {
        case .fall:
            return "figure.fall"
        case .emergency:
            return "exclamationmark.triangle.fill"
        case .abnormalActivity:
            return "waveform.path.ecg"
        case .noResponse:
            return "phone.down.fill"
        case .outOfBounds:
            return "location.slash.fill"
        case .healthAnomaly:
            return "heart.text.square.fill"
        case .other:
            return "bell.fill"
        }
    }
}

// MARK: - 알림 심각도

/// 알림 심각도 enum
enum AlertSeverity: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .low:
            return "낮음"
        case .medium:
            return "보통"
        case .high:
            return "높음"
        case .critical:
            return "긴급"
        }
    }

    /// 우선순위 (높을수록 긴급)
    var priority: Int {
        switch self {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        case .critical:
            return 4
        }
    }
}

// MARK: - 위치 데이터

/// 위치 정보
struct LocationData: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let address: String?
    let timestamp: Date?

    // 코드에서 직접 생성용
    init(
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        address: String? = nil,
        timestamp: Date? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.address = address
        self.timestamp = timestamp
    }
}

// MARK: - 통화 초대 이벤트 페이로드

/// 통화 초대 이벤트 페이로드
struct CallInviteEventData: Codable, Equatable {
    /// 통화 ID
    let callId: String

    /// 방 이름
    let roomName: String

    /// 발신자 identity
    let callerIdentity: String

    /// 발신자 이름
    let callerName: String?

    /// 수신자 identity
    let calleeIdentity: String

    /// 통화 유형 (video, audio, ai_bot)
    let callType: String?

    /// 발생 시간
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case callId
        case roomName
        case callerIdentity
        case callerName
        case calleeIdentity
        case callType
        case timestamp
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case callId = "call_id"
        case roomName = "room_name"
        case callerIdentity = "caller_identity"
        case callerName = "caller_name"
        case calleeIdentity = "callee_identity"
        case callType = "call_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // callId
        if let val = try? container.decode(String.self, forKey: .callId) {
            callId = val
        } else {
            callId = try snakeContainer.decode(String.self, forKey: .callId)
        }

        // roomName
        if let val = try? container.decode(String.self, forKey: .roomName) {
            roomName = val
        } else {
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
        }

        // callerIdentity
        if let val = try? container.decode(String.self, forKey: .callerIdentity) {
            callerIdentity = val
        } else {
            callerIdentity = try snakeContainer.decode(String.self, forKey: .callerIdentity)
        }

        // callerName
        if let val = try? container.decode(String.self, forKey: .callerName) {
            callerName = val
        } else {
            callerName = try? snakeContainer.decode(String.self, forKey: .callerName)
        }

        // calleeIdentity
        if let val = try? container.decode(String.self, forKey: .calleeIdentity) {
            calleeIdentity = val
        } else {
            calleeIdentity = try snakeContainer.decode(String.self, forKey: .calleeIdentity)
        }

        // callType
        if let val = try? container.decode(String.self, forKey: .callType) {
            callType = val
        } else {
            callType = try? snakeContainer.decode(String.self, forKey: .callType)
        }

        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(callId, forKey: .callId)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(callerIdentity, forKey: .callerIdentity)
        try container.encodeIfPresent(callerName, forKey: .callerName)
        try container.encode(calleeIdentity, forKey: .calleeIdentity)
        try container.encodeIfPresent(callType, forKey: .callType)
        try container.encode(timestamp, forKey: .timestamp)
    }

    // 코드에서 직접 생성용
    init(
        callId: String,
        roomName: String,
        callerIdentity: String,
        callerName: String? = nil,
        calleeIdentity: String,
        callType: String? = nil,
        timestamp: Date = Date()
    ) {
        self.callId = callId
        self.roomName = roomName
        self.callerIdentity = callerIdentity
        self.callerName = callerName
        self.calleeIdentity = calleeIdentity
        self.callType = callType
        self.timestamp = timestamp
    }
}

// MARK: - 통화 종료 이벤트 페이로드

/// 통화 종료 이벤트 페이로드
struct CallEndedEventData: Codable, Equatable {
    /// 통화 ID
    let callId: String

    /// 방 이름
    let roomName: String

    /// 종료 사유
    let endReason: CallEndReason

    /// 통화 시간 (초)
    let duration: Int?

    /// 종료 시간
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case callId
        case roomName
        case endReason
        case duration
        case timestamp
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case callId = "call_id"
        case roomName = "room_name"
        case endReason = "end_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // callId
        if let val = try? container.decode(String.self, forKey: .callId) {
            callId = val
        } else {
            callId = try snakeContainer.decode(String.self, forKey: .callId)
        }

        // roomName
        if let val = try? container.decode(String.self, forKey: .roomName) {
            roomName = val
        } else {
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
        }

        // endReason
        if let val = try? container.decode(CallEndReason.self, forKey: .endReason) {
            endReason = val
        } else {
            endReason = (try? snakeContainer.decode(CallEndReason.self, forKey: .endReason)) ?? .unknown
        }

        duration = try? container.decode(Int.self, forKey: .duration)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(callId, forKey: .callId)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(endReason, forKey: .endReason)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(timestamp, forKey: .timestamp)
    }

    // 코드에서 직접 생성용
    init(
        callId: String,
        roomName: String,
        endReason: CallEndReason,
        duration: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.callId = callId
        self.roomName = roomName
        self.endReason = endReason
        self.duration = duration
        self.timestamp = timestamp
    }
}

// MARK: - 통화 종료 사유

/// 통화 종료 사유 enum
enum CallEndReason: String, Codable, CaseIterable {
    /// 정상 종료
    case normal

    /// 부재중
    case missed

    /// 거절
    case rejected

    /// 취소
    case cancelled

    /// 네트워크 오류
    case networkError = "network_error"

    /// 타임아웃
    case timeout

    /// 알 수 없음
    case unknown

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .normal:
            return "정상 종료"
        case .missed:
            return "부재중"
        case .rejected:
            return "거절됨"
        case .cancelled:
            return "취소됨"
        case .networkError:
            return "네트워크 오류"
        case .timeout:
            return "응답 없음"
        case .unknown:
            return "알 수 없음"
        }
    }
}

// MARK: - 시스템 알림 이벤트 페이로드

/// 시스템 알림 이벤트 페이로드
struct SystemNotificationEventData: Codable, Equatable {
    /// 알림 ID
    let notificationId: String

    /// 알림 유형
    let notificationType: SystemNotificationType

    /// 제목
    let title: String

    /// 메시지
    let message: String

    /// 액션 URL (앱 내 딥링크)
    let actionUrl: String?

    /// 발생 시간
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case notificationId
        case notificationType
        case title
        case message
        case actionUrl
        case timestamp
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case notificationType = "notification_type"
        case actionUrl = "action_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // notificationId
        if let val = try? container.decode(String.self, forKey: .notificationId) {
            notificationId = val
        } else {
            notificationId = try snakeContainer.decode(String.self, forKey: .notificationId)
        }

        // notificationType
        if let val = try? container.decode(SystemNotificationType.self, forKey: .notificationType) {
            notificationType = val
        } else {
            notificationType = (try? snakeContainer.decode(SystemNotificationType.self, forKey: .notificationType)) ?? .info
        }

        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)

        // actionUrl
        if let val = try? container.decode(String.self, forKey: .actionUrl) {
            actionUrl = val
        } else {
            actionUrl = try? snakeContainer.decode(String.self, forKey: .actionUrl)
        }

        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notificationId, forKey: .notificationId)
        try container.encode(notificationType, forKey: .notificationType)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(actionUrl, forKey: .actionUrl)
        try container.encode(timestamp, forKey: .timestamp)
    }

    // 코드에서 직접 생성용
    init(
        notificationId: String,
        notificationType: SystemNotificationType,
        title: String,
        message: String,
        actionUrl: String? = nil,
        timestamp: Date = Date()
    ) {
        self.notificationId = notificationId
        self.notificationType = notificationType
        self.title = title
        self.message = message
        self.actionUrl = actionUrl
        self.timestamp = timestamp
    }
}

// MARK: - 시스템 알림 유형

/// 시스템 알림 유형 enum
enum SystemNotificationType: String, Codable, CaseIterable {
    /// 정보
    case info

    /// 경고
    case warning

    /// 오류
    case error

    /// 성공
    case success

    /// 업데이트 알림
    case update

    /// 유지보수 알림
    case maintenance

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .info:
            return "정보"
        case .warning:
            return "경고"
        case .error:
            return "오류"
        case .success:
            return "성공"
        case .update:
            return "업데이트"
        case .maintenance:
            return "유지보수"
        }
    }
}

// MARK: - 사용자 상태 변경 이벤트 페이로드

/// 사용자 상태 변경 이벤트 페이로드
struct UserStatusChangedEventData: Codable, Equatable {
    /// 사용자 ID
    let userId: String

    /// 사용자 identity
    let identity: String?

    /// 이전 상태
    let previousStatus: UserOnlineStatus?

    /// 현재 상태
    let currentStatus: UserOnlineStatus

    /// 마지막 활동 시간
    let lastActiveAt: Date?

    /// 발생 시간
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case userId
        case identity
        case previousStatus
        case currentStatus
        case lastActiveAt
        case timestamp
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case userId = "user_id"
        case previousStatus = "previous_status"
        case currentStatus = "current_status"
        case lastActiveAt = "last_active_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // userId
        if let val = try? container.decode(String.self, forKey: .userId) {
            userId = val
        } else {
            userId = try snakeContainer.decode(String.self, forKey: .userId)
        }

        identity = try? container.decode(String.self, forKey: .identity)

        // previousStatus
        if let val = try? container.decode(UserOnlineStatus.self, forKey: .previousStatus) {
            previousStatus = val
        } else {
            previousStatus = try? snakeContainer.decode(UserOnlineStatus.self, forKey: .previousStatus)
        }

        // currentStatus
        if let val = try? container.decode(UserOnlineStatus.self, forKey: .currentStatus) {
            currentStatus = val
        } else {
            currentStatus = try snakeContainer.decode(UserOnlineStatus.self, forKey: .currentStatus)
        }

        // lastActiveAt
        if let val = try? container.decode(Date.self, forKey: .lastActiveAt) {
            lastActiveAt = val
        } else {
            lastActiveAt = try? snakeContainer.decode(Date.self, forKey: .lastActiveAt)
        }

        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(identity, forKey: .identity)
        try container.encodeIfPresent(previousStatus, forKey: .previousStatus)
        try container.encode(currentStatus, forKey: .currentStatus)
        try container.encodeIfPresent(lastActiveAt, forKey: .lastActiveAt)
        try container.encode(timestamp, forKey: .timestamp)
    }

    // 코드에서 직접 생성용
    init(
        userId: String,
        identity: String? = nil,
        previousStatus: UserOnlineStatus? = nil,
        currentStatus: UserOnlineStatus,
        lastActiveAt: Date? = nil,
        timestamp: Date = Date()
    ) {
        self.userId = userId
        self.identity = identity
        self.previousStatus = previousStatus
        self.currentStatus = currentStatus
        self.lastActiveAt = lastActiveAt
        self.timestamp = timestamp
    }
}

// MARK: - 사용자 온라인 상태

/// 사용자 온라인 상태 enum
enum UserOnlineStatus: String, Codable, CaseIterable {
    /// 온라인
    case online

    /// 오프라인
    case offline

    /// 자리비움
    case away

    /// 통화 중
    case inCall = "in_call"

    /// 방해금지
    case doNotDisturb = "do_not_disturb"

    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .online:
            return "온라인"
        case .offline:
            return "오프라인"
        case .away:
            return "자리비움"
        case .inCall:
            return "통화 중"
        case .doNotDisturb:
            return "방해금지"
        }
    }

    /// 상태 색상 (SwiftUI Color 이름)
    var colorName: String {
        switch self {
        case .online:
            return "green"
        case .offline:
            return "gray"
        case .away:
            return "yellow"
        case .inCall:
            return "blue"
        case .doNotDisturb:
            return "red"
        }
    }
}

// MARK: - Heartbeat 이벤트 페이로드

/// Heartbeat 이벤트 페이로드
struct HeartbeatEventData: Codable, Equatable {
    /// 서버 시간
    let serverTime: Date

    /// 다음 heartbeat 간격 (초)
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case serverTime
        case interval
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case serverTime = "server_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        // serverTime
        if let val = try? container.decode(Date.self, forKey: .serverTime) {
            serverTime = val
        } else {
            serverTime = try snakeContainer.decode(Date.self, forKey: .serverTime)
        }

        interval = try? container.decode(Int.self, forKey: .interval)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverTime, forKey: .serverTime)
        try container.encodeIfPresent(interval, forKey: .interval)
    }

    // 코드에서 직접 생성용
    init(serverTime: Date = Date(), interval: Int? = nil) {
        self.serverTime = serverTime
        self.interval = interval
    }
}

// MARK: - 이벤트 페이로드 파싱 헬퍼
// EventStreamPayload extension은 EventStreamServiceProtocol.swift에 정의됨
