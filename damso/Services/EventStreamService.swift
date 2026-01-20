//
//  EventStreamService.swift
//  damso
//
//  Created by Claude Code on 2025-01-16.
//

import Foundation
import Combine

/// SSE (Server-Sent Events) 스트리밍 서비스
/// `/v1/events/stream` 엔드포인트를 통해 실시간 이벤트 수신
@MainActor
final class EventStreamService: ObservableObject, EventStreamServiceProtocol {

    // MARK: - Singleton

    static let shared = EventStreamService()

    // MARK: - Constants

    /// SSE 엔드포인트 경로
    private let sseEndpointPath = "/v1/events/stream"

    /// 최대 재연결 시도 횟수
    private let maxReconnectAttempts = 10

    /// 기본 재연결 대기 시간 (초)
    private let baseReconnectDelay: TimeInterval = 1.0

    /// 최대 재연결 대기 시간 (초)
    private let maxReconnectDelay: TimeInterval = 60.0

    // MARK: - Published Properties

    /// 현재 연결 상태
    @Published private(set) var connectionState: EventStreamConnectionState = .disconnected

    // MARK: - Protocol Conformance

    /// 연결 상태 Publisher
    var connectionStatePublisher: AnyPublisher<EventStreamConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }

    /// 이벤트 Publisher (Combine)
    var eventPublisher: AnyPublisher<EventStreamPayload, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// 이벤트 스트림 (AsyncStream)
    var eventStream: AsyncStream<EventStreamPayload> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            // Sendable 호환을 위해 Box 패턴 사용
            final class CancellableHolder: @unchecked Sendable {
                var cancellable: AnyCancellable?
            }

            let holder = CancellableHolder()
            holder.cancellable = self.eventSubject.sink { payload in
                continuation.yield(payload)
            }

            continuation.onTermination = { _ in
                holder.cancellable?.cancel()
            }
        }
    }

    // MARK: - Private Properties

    /// 이벤트 Subject (Combine)
    private let eventSubject = PassthroughSubject<EventStreamPayload, Never>()

    /// URLSession Task
    private var streamTask: URLSessionDataTask?

    /// 현재 재연결 시도 횟수
    private var reconnectAttempt = 0

    /// 마지막으로 받은 이벤트 ID
    private var lastEventId: String?

    /// 서버에서 제공한 retry interval (밀리초)
    private var serverRetryInterval: Int?

    /// 자동 재연결 활성화 여부
    private var autoReconnect = true

    /// 재연결 Task
    private var reconnectTask: Task<Void, Never>?

    /// Combine 구독 저장소
    private var cancellables = Set<AnyCancellable>()

    /// SSE 파싱 버퍼
    private var parseBuffer = ""

    /// URLSession for SSE
    private lazy var sseSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval.infinity  // SSE는 무한 대기
        config.timeoutIntervalForResource = TimeInterval.infinity
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: streamDelegate, delegateQueue: nil)
    }()

    /// SSE Stream Delegate
    private let streamDelegate = SSEStreamDelegate()

    // MARK: - Init

    private init() {
        setupDelegateBindings()
    }

    deinit {
        // MainActor 컨텍스트에서 disconnect 호출
        let task = streamTask
        task?.cancel()
        reconnectTask?.cancel()
    }

    // MARK: - Public Methods

    /// SSE 연결 시작
    /// - Parameter lastEventId: 마지막으로 받은 이벤트 ID (재연결 시 사용)
    func connect(lastEventId: String? = nil) async throws {
        // 이미 연결 중이면 무시
        guard connectionState == .disconnected || connectionState.isFailedState else {
            debugLog("Already connected or connecting, ignoring connect request")
            return
        }

        self.lastEventId = lastEventId ?? self.lastEventId
        self.autoReconnect = true
        self.reconnectAttempt = 0

        try await startConnection()
    }

    /// SSE 연결 종료
    func disconnect() {
        debugLog("Disconnecting SSE stream")
        autoReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        streamTask?.cancel()
        streamTask = nil
        parseBuffer = ""
        connectionState = .disconnected
    }

    /// 특정 이벤트 타입만 필터링하여 구독
    /// - Parameter types: 구독할 이벤트 타입 배열
    /// - Returns: 필터링된 이벤트 Publisher
    func subscribe(to types: [EventStreamType]) -> AnyPublisher<EventStreamPayload, Never> {
        eventSubject
            .filter { types.contains($0.eventType) }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    /// Delegate 바인딩 설정
    private func setupDelegateBindings() {
        // 데이터 수신 처리
        streamDelegate.onDataReceived = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleReceivedData(data)
            }
        }

        // 연결 완료 처리
        streamDelegate.onConnectionEstablished = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleConnectionEstablished()
            }
        }

        // 연결 종료 처리
        streamDelegate.onConnectionClosed = { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.handleConnectionClosed(error: error)
            }
        }

        // HTTP 응답 처리
        streamDelegate.onHTTPResponse = { [weak self] statusCode in
            Task { @MainActor [weak self] in
                self?.handleHTTPResponse(statusCode: statusCode)
            }
        }
    }

    /// SSE 연결 시작
    private func startConnection() async throws {
        connectionState = .connecting

        // URL 구성
        guard let url = URL(string: "\(AppConfig.apiBaseURL)\(sseEndpointPath)") else {
            connectionState = .failed(error: EventStreamError.invalidURL.localizedDescription)
            throw EventStreamError.invalidURL
        }

        debugLog("Starting SSE connection to: \(url.absoluteString)")

        // Request 구성
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        // Last-Event-ID 헤더 추가 (재연결 시)
        if let lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
            debugLog("Resuming from Last-Event-ID: \(lastEventId)")
        }

        // 토큰이 있으면 Authorization 헤더 추가 (선택적)
        // 문서에는 인증 불필요라고 되어 있지만, 필요시 활성화
        // if let token = TokenManager.shared.accessToken {
        //     request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }

        // URLSession Task 생성
        parseBuffer = ""
        streamTask = sseSession.dataTask(with: request)
        streamTask?.resume()
    }

    /// 수신된 데이터 처리
    private func handleReceivedData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            debugLog("Failed to decode received data as UTF-8")
            return
        }

        parseBuffer += text
        parseEvents()
    }

    /// SSE 이벤트 파싱
    private func parseEvents() {
        // SSE 이벤트는 빈 줄(\n\n)로 구분됨
        let events = parseBuffer.components(separatedBy: "\n\n")

        // 마지막 요소는 아직 완성되지 않았을 수 있으므로 버퍼에 유지
        parseBuffer = events.last ?? ""

        // 마지막 요소를 제외한 나머지 이벤트 처리
        for eventText in events.dropLast() {
            if !eventText.isEmpty {
                parseAndEmitEvent(eventText)
            }
        }
    }

    /// 개별 이벤트 파싱 및 발행
    private func parseAndEmitEvent(_ eventText: String) {
        var eventType: EventStreamType = .unknown
        var eventData = ""
        var eventId: String?
        var retryInterval: Int?

        // 줄별로 파싱
        let lines = eventText.components(separatedBy: "\n")
        for line in lines {
            // 주석 무시 (콜론으로 시작)
            if line.hasPrefix(":") {
                continue
            }

            // 필드 파싱
            if line.hasPrefix("event:") {
                let value = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                eventType = EventStreamType(rawValue: value) ?? .unknown
            } else if line.hasPrefix("data:") {
                let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !eventData.isEmpty {
                    eventData += "\n"
                }
                eventData += value
            } else if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("retry:") {
                let value = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                retryInterval = Int(value)
            }
        }

        // 이벤트 ID 저장 (재연결 시 사용)
        if let eventId {
            lastEventId = eventId
        }

        // retry interval 저장
        if let retryInterval {
            serverRetryInterval = retryInterval
        }

        // 데이터가 비어있으면 이벤트 무시 (heartbeat 등 제외)
        if eventData.isEmpty && eventType != .heartbeat {
            return
        }

        // 이벤트 페이로드 생성 및 발행
        let payload = EventStreamPayload(
            id: eventId,
            eventType: eventType,
            data: eventData,
            timestamp: Date(),
            retry: retryInterval
        )

        debugLog("Received event: type=\(eventType.rawValue), id=\(eventId ?? "nil")")
        eventSubject.send(payload)
    }

    /// 연결 확립 처리
    private func handleConnectionEstablished() {
        debugLog("SSE connection established")
        connectionState = .connected
        reconnectAttempt = 0
    }

    /// HTTP 응답 처리
    private func handleHTTPResponse(statusCode: Int) {
        debugLog("HTTP response: \(statusCode)")

        if statusCode != 200 {
            connectionState = .failed(error: EventStreamError.serverError(statusCode: statusCode).localizedDescription)
        }
    }

    /// 연결 종료 처리
    private func handleConnectionClosed(error: Error?) async {
        if let error {
            debugLog("SSE connection closed with error: \(error.localizedDescription)")
        } else {
            debugLog("SSE connection closed")
        }

        // 자동 재연결 시도
        if autoReconnect && reconnectAttempt < maxReconnectAttempts {
            await scheduleReconnect()
        } else if reconnectAttempt >= maxReconnectAttempts {
            connectionState = .failed(error: EventStreamError.maxReconnectAttemptsReached.localizedDescription)
        } else {
            connectionState = .disconnected
        }
    }

    /// 재연결 스케줄링
    private func scheduleReconnect() async {
        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff 계산
        let delay: TimeInterval
        if let serverRetry = serverRetryInterval {
            delay = Double(serverRetry) / 1000.0
        } else {
            let exponentialDelay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
            delay = min(exponentialDelay, maxReconnectDelay)
        }

        debugLog("Scheduling reconnect attempt \(reconnectAttempt) in \(delay) seconds")

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                try await startConnection()
            } catch {
                debugLog("Reconnect attempt \(reconnectAttempt) failed: \(error)")
            }
        }
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EventStreamService] \(message)")
        #endif
    }
}

// MARK: - EventStreamConnectionState Extension

extension EventStreamConnectionState {
    var isFailedState: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - SSE Stream Delegate

/// URLSession Delegate for SSE streaming
/// @unchecked Sendable: URLSession delegate queue에서 순차 실행되므로 스레드 안전
private final class SSEStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    // MARK: - Callbacks

    nonisolated(unsafe) var onDataReceived: ((Data) -> Void)?
    nonisolated(unsafe) var onConnectionEstablished: (() -> Void)?
    nonisolated(unsafe) var onConnectionClosed: ((Error?) -> Void)?
    nonisolated(unsafe) var onHTTPResponse: ((Int) -> Void)?

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            onHTTPResponse?(httpResponse.statusCode)

            if httpResponse.statusCode == 200 {
                onConnectionEstablished?()
            }
        }

        // SSE는 스트리밍이므로 계속 수신
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onDataReceived?(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onConnectionClosed?(error)
    }
}
