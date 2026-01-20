//
//  EventStreamServiceProtocol.swift
//  damso
//
//  Created by Claude Code on 2025-01-16.
//

import Foundation
import Combine

// MARK: - 이벤트 타입

/// SSE 이벤트 타입 정의
enum EventStreamType: String, Codable, CaseIterable {
    /// 케어 알림 (낙상 감지, 긴급 상황 등)
    case careAlert = "care_alert"

    /// 영상통화 초대
    case callInvite = "call_invite"

    /// 통화 종료
    case callEnded = "call_ended"

    /// 시스템 알림
    case systemNotification = "system_notification"

    /// 연결 유지용 heartbeat
    case heartbeat = "heartbeat"

    /// 사용자 상태 변경
    case userStatusChanged = "user_status_changed"

    /// 알 수 없는 이벤트 타입
    case unknown = "unknown"
}

// MARK: - 이벤트 페이로드

/// SSE 이벤트 페이로드
struct EventStreamPayload: Codable, Equatable {
    /// 이벤트 고유 ID (서버에서 제공)
    let id: String?

    /// 이벤트 타입
    let eventType: EventStreamType

    /// 이벤트 데이터 (JSON 문자열)
    let data: String

    /// 타임스탬프
    let timestamp: Date

    /// 재연결 시 사용할 retry interval (밀리초)
    let retry: Int?

    init(id: String? = nil, eventType: EventStreamType, data: String, timestamp: Date = Date(), retry: Int? = nil) {
        self.id = id
        self.eventType = eventType
        self.data = data
        self.timestamp = timestamp
        self.retry = retry
    }
}

// MARK: - 연결 상태

/// SSE 연결 상태
enum EventStreamConnectionState: Equatable {
    /// 연결 안됨
    case disconnected

    /// 연결 중
    case connecting

    /// 연결됨
    case connected

    /// 재연결 중
    case reconnecting(attempt: Int)

    /// 연결 실패
    case failed(error: String)
}

// MARK: - 에러 타입

/// SSE 에러 타입
enum EventStreamError: LocalizedError, Equatable {
    case invalidURL
    case connectionFailed(String)
    case parsingFailed(String)
    case serverError(statusCode: Int)
    case timeout
    case disconnected
    case maxReconnectAttemptsReached

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 SSE URL입니다"
        case .connectionFailed(let message):
            return "SSE 연결 실패: \(message)"
        case .parsingFailed(let message):
            return "이벤트 파싱 실패: \(message)"
        case .serverError(let statusCode):
            return "서버 에러: HTTP \(statusCode)"
        case .timeout:
            return "연결 시간 초과"
        case .disconnected:
            return "연결이 끊어졌습니다"
        case .maxReconnectAttemptsReached:
            return "최대 재연결 시도 횟수를 초과했습니다"
        }
    }
}

// MARK: - Protocol

/// SSE 이벤트 스트림 서비스 프로토콜
protocol EventStreamServiceProtocol: AnyObject {
    /// 현재 연결 상태
    var connectionState: EventStreamConnectionState { get }

    /// 연결 상태 Publisher
    var connectionStatePublisher: AnyPublisher<EventStreamConnectionState, Never> { get }

    /// 이벤트 스트림 (AsyncStream)
    var eventStream: AsyncStream<EventStreamPayload> { get }

    /// 이벤트 Publisher (Combine)
    var eventPublisher: AnyPublisher<EventStreamPayload, Never> { get }

    /// SSE 연결 시작
    /// - Parameter lastEventId: 마지막으로 받은 이벤트 ID (재연결 시 사용)
    func connect(lastEventId: String?) async throws

    /// SSE 연결 종료
    func disconnect()

    /// 특정 이벤트 타입만 필터링하여 구독
    /// - Parameter types: 구독할 이벤트 타입 배열
    /// - Returns: 필터링된 이벤트 Publisher
    func subscribe(to types: [EventStreamType]) -> AnyPublisher<EventStreamPayload, Never>
}

// MARK: - EventStreamPayload 파싱 헬퍼

extension EventStreamPayload {
    /// 케어 알림 데이터로 파싱
    func asCareAlert() -> CareAlertEventData? {
        guard eventType == .careAlert else { return nil }
        return try? JSONDecoder.apiDecoder.decode(CareAlertEventData.self, from: Data(data.utf8))
    }

    /// 통화 초대 데이터로 파싱
    func asCallInvite() -> CallInviteEventData? {
        guard eventType == .callInvite else { return nil }
        return try? JSONDecoder.apiDecoder.decode(CallInviteEventData.self, from: Data(data.utf8))
    }

    /// 통화 종료 데이터로 파싱
    func asCallEnded() -> CallEndedEventData? {
        guard eventType == .callEnded else { return nil }
        return try? JSONDecoder.apiDecoder.decode(CallEndedEventData.self, from: Data(data.utf8))
    }

    /// 시스템 알림 데이터로 파싱
    func asSystemNotification() -> SystemNotificationEventData? {
        guard eventType == .systemNotification else { return nil }
        return try? JSONDecoder.apiDecoder.decode(SystemNotificationEventData.self, from: Data(data.utf8))
    }

    /// 사용자 상태 변경 데이터로 파싱
    func asUserStatusChanged() -> UserStatusChangedEventData? {
        guard eventType == .userStatusChanged else { return nil }
        return try? JSONDecoder.apiDecoder.decode(UserStatusChangedEventData.self, from: Data(data.utf8))
    }

    /// Heartbeat 데이터로 파싱
    func asHeartbeat() -> HeartbeatEventData? {
        guard eventType == .heartbeat else { return nil }
        return try? JSONDecoder.apiDecoder.decode(HeartbeatEventData.self, from: Data(data.utf8))
    }
}
