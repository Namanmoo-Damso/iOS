//
//  WardSettingsServiceProtocol.swift
//  damso
//
//  어르신 설정 서비스 프로토콜
//

import Foundation

/// 어르신 설정 관리 프로토콜
protocol WardSettingsServiceProtocol {
    /// 어르신 설정 조회
    /// - Returns: 어르신 설정 정보
    func fetchSettings() async throws -> WardSettings

    /// 어르신 설정 수정
    /// - Parameter settings: 수정할 설정 정보
    /// - Returns: 수정된 설정 정보
    func updateSettings(_ settings: WardSettingsUpdateRequest) async throws -> WardSettings
}
