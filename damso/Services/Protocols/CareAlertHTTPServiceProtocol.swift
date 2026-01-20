//
//  CareAlertHTTPServiceProtocol.swift
//  damso
//
//  Care Alert HTTP API 서비스 프로토콜
//

import Foundation

/// Care Alert HTTP API 서비스 프로토콜
/// DataChannel 기반 CareAlertService와 분리된 HTTP API 통신 담당
protocol CareAlertHTTPServiceProtocol {

    // MARK: - 알림 생성

    /// 새로운 케어 알림 생성
    /// - Parameter request: 알림 생성 요청 데이터
    /// - Returns: 생성된 알림 정보
    func createAlert(_ request: CreateCareAlertRequest) async throws -> CareAlertResponse

    // MARK: - 알림 조회

    /// 특정 Ward의 알림 목록 조회
    /// - Parameters:
    ///   - wardId: Ward UUID
    ///   - page: 페이지 번호 (기본값: 1)
    ///   - limit: 페이지당 항목 수 (기본값: 20)
    /// - Returns: 페이지네이션된 알림 목록
    func getAlerts(wardId: String, page: Int, limit: Int) async throws -> CareAlertListResponse

    // MARK: - 감정 리포트

    /// 특정 Ward의 감정 분석 리포트 조회
    /// - Parameters:
    ///   - wardId: Ward UUID
    ///   - startDate: 조회 시작일 (선택)
    ///   - endDate: 조회 종료일 (선택)
    /// - Returns: 감정 분석 리포트
    func getEmotionReport(wardId: String, startDate: Date?, endDate: Date?) async throws -> EmotionReportResponse

    // MARK: - 알림 확인 처리

    /// 알림 확인 처리 (acknowledge)
    /// - Parameter alertId: 알림 ID
    /// - Returns: 업데이트된 알림 정보
    func acknowledgeAlert(alertId: String) async throws -> CareAlertResponse

    // MARK: - 버퍼 상태

    /// 케어 알림 버퍼 상태 조회
    /// - Returns: 버퍼 상태 정보
    func getBufferStatus() async throws -> BufferStatusResponse
}
