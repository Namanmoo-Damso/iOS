//
//  FaceDetectionDataChannel.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

/// Face detection 데이터 송수신 프로토콜
protocol FaceDetectionDataChannelProtocol {
    /// 수신된 face detection 데이터 스트림
    var receivedData: AnyPublisher<FaceDetectionData, Never> { get }

    /// 현재 연결된 Room 설정
    func setRoom(_ room: Room?)

    /// Face detection 데이터 전송
    func send(_ data: FaceDetectionData) async throws

    /// Face detection 데이터 전송 (배열)
    func send(faces: [DetectedFace], frameSize: FrameSize) async throws
}

/// Face detection 데이터를 LiveKit Data Channel을 통해 송수신하는 서비스
@MainActor
final class FaceDetectionDataChannel: NSObject, ObservableObject, FaceDetectionDataChannelProtocol {

    // MARK: - Singleton

    static let shared = FaceDetectionDataChannel()

    // MARK: - Published Properties

    /// 마지막으로 수신된 face detection 데이터
    @Published private(set) var lastReceivedData: FaceDetectionData?

    /// 전송 활성화 상태 (현재 비활성화 - 수집만 함)
    @Published var isSendingEnabled: Bool = false

    /// 전송 빈도 제한 (초당 최대 전송 횟수)
    @Published var maxSendRate: Int = 30

    // MARK: - Private Properties

    private weak var room: Room?
    private let receivedDataSubject = PassthroughSubject<FaceDetectionData, Never>()
    private var lastSendTime: Date = .distantPast
    private var sendQueue: [FaceDetectionData] = []
    private var isSending: Bool = false

    /// 전송 간격 (초)
    private var sendInterval: TimeInterval {
        1.0 / Double(maxSendRate)
    }

    // MARK: - Public Properties

    var receivedData: AnyPublisher<FaceDetectionData, Never> {
        receivedDataSubject.eraseToAnyPublisher()
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Room 설정 (LiveKitService에서 연결 시 호출)
    func setRoom(_ room: Room?) {
        self.room = room
        debugLog("Room set: \(room != nil ? "connected" : "disconnected")")
    }

    /// Face detection 데이터 전송
    func send(_ data: FaceDetectionData) async throws {
        guard isSendingEnabled else {
            debugLog("Sending disabled, skipping")
            return
        }

        guard let room, room.connectionState == .connected else {
            debugLog("Room not connected, skipping send")
            return
        }

        // Rate limiting
        let now = Date()
        let timeSinceLastSend = now.timeIntervalSince(lastSendTime)
        if timeSinceLastSend < sendInterval {
            debugLog("Rate limited, skipping")
            return
        }

        // JSON 인코딩
        let jsonData: Data
        do {
            jsonData = try data.toJSONData()
        } catch {
            debugLog("JSON encoding failed: \(error)")
            throw FaceDetectionDataError.encodingFailed(error)
        }

        // 페이로드 크기 검증
        guard jsonData.count <= FaceDetectionData.maxPayloadSize else {
            debugLog("Payload too large: \(jsonData.count) bytes")
            throw FaceDetectionDataError.payloadTooLarge(jsonData.count)
        }

        // 전송 옵션: lossy (낮은 지연, 패킷 손실 허용)
        let options = DataPublishOptions(
            topic: FaceDetectionData.topic,
            reliable: false // Face detection은 실시간성이 중요하므로 lossy 사용
        )

        do {
            try await room.localParticipant.publish(data: jsonData, options: options)
            lastSendTime = now
            debugLog("Sent face detection data: \(data.faces.count) faces, \(jsonData.count) bytes")
        } catch {
            debugLog("Failed to send: \(error)")
            throw FaceDetectionDataError.sendFailed(error)
        }
    }

    /// 간편한 전송 메서드
    func send(faces: [DetectedFace], frameSize: FrameSize) async throws {
        let data = FaceDetectionData(faces: faces, frameSize: frameSize)
        try await send(data)
    }

    /// 수신된 데이터 처리 (RoomDelegate에서 호출)
    func handleReceivedData(_ data: Data, from participant: String?) {
        do {
            let faceData = try FaceDetectionData.from(jsonData: data)
            lastReceivedData = faceData
            receivedDataSubject.send(faceData)
            debugLog("Received face detection data from \(participant ?? "unknown"): \(faceData.faces.count) faces")
        } catch {
            debugLog("Failed to decode received data: \(error)")
        }
    }

    /// Raw 데이터 전송 (SensorDataAggregator에서 사용)
    /// - Parameters:
    ///   - data: 전송할 JSON 데이터
    ///   - topic: 데이터 토픽
    func sendRaw(data: Data, topic: String) async throws {
        guard isSendingEnabled else {
            debugLog("Sending disabled, skipping")
            return
        }

        guard let room, room.connectionState == .connected else {
            debugLog("Room not connected, skipping send")
            return
        }

        guard data.count <= FaceDetectionData.maxPayloadSize else {
            debugLog("Payload too large: \(data.count) bytes")
            throw FaceDetectionDataError.payloadTooLarge(data.count)
        }

        let options = DataPublishOptions(
            topic: topic,
            reliable: false
        )

        do {
            try await room.localParticipant.publish(data: data, options: options)
            debugLog("Sent raw data to topic '\(topic)': \(data.count) bytes")
        } catch {
            debugLog("Failed to send raw data: \(error)")
            throw FaceDetectionDataError.sendFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[FaceDetectionDataChannel] \(message)")
        #endif
    }
}

// MARK: - Errors

enum FaceDetectionDataError: LocalizedError {
    case roomNotConnected
    case encodingFailed(Error)
    case payloadTooLarge(Int)
    case sendFailed(Error)

    var errorDescription: String? {
        switch self {
        case .roomNotConnected:
            return "Room이 연결되지 않았습니다"
        case .encodingFailed(let error):
            return "데이터 인코딩 실패: \(error.localizedDescription)"
        case .payloadTooLarge(let size):
            return "페이로드가 너무 큽니다: \(size) bytes (최대: 15KB)"
        case .sendFailed(let error):
            return "전송 실패: \(error.localizedDescription)"
        }
    }
}
#endif
