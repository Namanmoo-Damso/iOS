//
//  LiveKitAPIModels.swift
//  damso
//
//  Created by Claude Code on 2025-01-16.
//

import Foundation

// MARK: - LiveKit API 응답 모델

/// POST /v1/livekit/create-bot 응답
struct CreateBotResponse: Codable {
    let roomName: String
    let botIdentity: String
    let agentId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case roomName
        case botIdentity
        case agentId
        case createdAt
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
        case botIdentity = "bot_identity"
        case agentId = "agent_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        // camelCase 우선 시도
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let rn = try? container.decode(String.self, forKey: .roomName) {
            roomName = rn
            botIdentity = (try? container.decode(String.self, forKey: .botIdentity)) ?? ""
            agentId = try? container.decode(String.self, forKey: .agentId)
            createdAt = try? container.decode(String.self, forKey: .createdAt)
        } else {
            // snake_case fallback
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            roomName = try snakeContainer.decode(String.self, forKey: .roomName)
            botIdentity = (try? snakeContainer.decode(String.self, forKey: .botIdentity)) ?? ""
            agentId = try? snakeContainer.decode(String.self, forKey: .agentId)
            createdAt = try? snakeContainer.decode(String.self, forKey: .createdAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(botIdentity, forKey: .botIdentity)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    // 코드에서 직접 생성용
    init(roomName: String, botIdentity: String, agentId: String? = nil, createdAt: String? = nil) {
        self.roomName = roomName
        self.botIdentity = botIdentity
        self.agentId = agentId
        self.createdAt = createdAt
    }
}

/// POST /v1/livekit/rooms/:roomName/mute-agent 응답
struct MuteAgentResponse: Codable {
    let success: Bool
    let roomName: String
    let muted: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case roomName
        case muted
        case message
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        success = (try? container.decode(Bool.self, forKey: .success)) ?? true
        muted = (try? container.decode(Bool.self, forKey: .muted)) ?? false
        message = try? container.decode(String.self, forKey: .message)

        // roomName: camelCase와 snake_case 둘 다 지원
        if let rn = try? container.decode(String.self, forKey: .roomName) {
            roomName = rn
        } else {
            let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
            roomName = (try? snakeContainer.decode(String.self, forKey: .roomName)) ?? ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(muted, forKey: .muted)
        try container.encodeIfPresent(message, forKey: .message)
    }

    // 코드에서 직접 생성용
    init(success: Bool, roomName: String, muted: Bool, message: String? = nil) {
        self.success = success
        self.roomName = roomName
        self.muted = muted
        self.message = message
    }
}

/// POST /v1/livekit/rooms/:roomName/danger 응답
struct DangerStateResponse: Codable {
    let success: Bool
    let roomName: String
    let dangerType: String
    let acknowledged: Bool
    let message: String?
    let notifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case roomName
        case dangerType
        case acknowledged
        case message
        case notifiedAt
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case roomName = "room_name"
        case dangerType = "danger_type"
        case notifiedAt = "notified_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)

        success = (try? container.decode(Bool.self, forKey: .success)) ?? true
        acknowledged = (try? container.decode(Bool.self, forKey: .acknowledged)) ?? false
        message = try? container.decode(String.self, forKey: .message)

        // roomName
        if let rn = try? container.decode(String.self, forKey: .roomName) {
            roomName = rn
        } else {
            roomName = (try? snakeContainer.decode(String.self, forKey: .roomName)) ?? ""
        }

        // dangerType
        if let dt = try? container.decode(String.self, forKey: .dangerType) {
            dangerType = dt
        } else {
            dangerType = (try? snakeContainer.decode(String.self, forKey: .dangerType)) ?? ""
        }

        // notifiedAt
        if let na = try? container.decode(String.self, forKey: .notifiedAt) {
            notifiedAt = na
        } else {
            notifiedAt = try? snakeContainer.decode(String.self, forKey: .notifiedAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(roomName, forKey: .roomName)
        try container.encode(dangerType, forKey: .dangerType)
        try container.encode(acknowledged, forKey: .acknowledged)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(notifiedAt, forKey: .notifiedAt)
    }

    // 코드에서 직접 생성용
    init(
        success: Bool,
        roomName: String,
        dangerType: String,
        acknowledged: Bool,
        message: String? = nil,
        notifiedAt: String? = nil
    ) {
        self.success = success
        self.roomName = roomName
        self.dangerType = dangerType
        self.acknowledged = acknowledged
        self.message = message
        self.notifiedAt = notifiedAt
    }
}

// MARK: - LiveKit API 에러

/// LiveKit API 관련 에러
enum LiveKitAPIError: LocalizedError {
    case missingAuthToken
    case invalidURL
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case networkError(String)
    case decodingError(String)
    case roomNotFound
    case agentNotFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "인증 토큰이 없습니다. 로그인이 필요합니다."
        case .invalidURL:
            return "잘못된 API URL입니다."
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "API 요청 실패 (상태 코드: \(code))"
            }
            return "API 요청 실패 (\(code)): \(body)"
        case let .networkError(msg):
            return "네트워크 오류: \(msg)"
        case let .decodingError(msg):
            return "응답 파싱 오류: \(msg)"
        case .roomNotFound:
            return "Room을 찾을 수 없습니다."
        case .agentNotFound:
            return "Agent를 찾을 수 없습니다."
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        }
    }

    /// 재시도 가능한 에러인지 확인
    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .httpStatus(let code, _):
            return code >= 500 && code < 600
        default:
            return false
        }
    }
}
