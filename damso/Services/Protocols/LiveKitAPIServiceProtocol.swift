//
//  LiveKitAPIServiceProtocol.swift
//  damso
//
//  Created by Claude Code on 2025-01-16.
//

import Foundation

/// LiveKit 관리 API 서비스 프로토콜
/// LiveKit Room 및 Agent 제어를 위한 HTTP API 호출 담당
@MainActor
protocol LiveKitAPIServiceProtocol {

    /// Bot 생성 및 Agent 시작
    /// - Returns: Bot 생성 응답 (roomName, botIdentity 등)
    func createBot() async throws -> CreateBotResponse

    /// Agent 음소거 설정
    /// - Parameters:
    ///   - roomName: LiveKit Room 이름
    ///   - muted: 음소거 여부
    /// - Returns: 음소거 설정 결과
    func muteAgent(roomName: String, muted: Bool) async throws -> MuteAgentResponse

    /// 위험 상태 설정 (긴급 상황 알림)
    /// - Parameters:
    ///   - roomName: LiveKit Room 이름
    ///   - dangerType: 위험 유형 (예: "fall", "emergency", "health")
    ///   - message: 추가 메시지 (선택)
    /// - Returns: 위험 상태 설정 결과
    func setDangerState(roomName: String, dangerType: String, message: String?) async throws -> DangerStateResponse
}
