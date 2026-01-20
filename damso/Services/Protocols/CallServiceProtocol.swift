//
//  CallServiceProtocol.swift
//  damso
//
//  통화 API 서비스 프로토콜 정의
//

import Foundation

/// 통화 API 서비스 프로토콜
/// - POST /v1/calls/invite: 통화 초대
/// - POST /v1/calls/:callId/analyze: 통화 분석
/// - GET /v1/calls/room/:roomName/context: 방 컨텍스트 조회
/// - GET /v1/calls/room/:roomName/transcripts: 방 전사 내역 조회
protocol CallServiceProtocol {
    /// 통화 초대
    /// - Parameter wardId: 어르신 ID
    /// - Returns: 초대 응답 (callId, roomName 등)
    func inviteCall(wardId: String) async throws -> InviteCallResponse

    /// 통화 분석 요청
    /// - Parameter callId: 통화 ID
    /// - Returns: 분석 결과
    func analyzeCall(callId: String) async throws -> CallAnalyzeResponse

    /// 방 컨텍스트 조회
    /// - Parameter roomName: 방 이름
    /// - Returns: 방 컨텍스트 정보
    func getRoomContext(roomName: String) async throws -> RoomContextResponse

    /// 방 전사 내역 조회
    /// - Parameter roomName: 방 이름
    /// - Returns: 전사 내역 목록
    func getRoomTranscripts(roomName: String) async throws -> RoomTranscriptsResponse
}
