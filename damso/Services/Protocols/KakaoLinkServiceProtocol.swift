//
//  KakaoLinkServiceProtocol.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

/// 카카오 링크 서비스 프로토콜
protocol KakaoLinkServiceProtocol {
    /// 카카오톡으로 초대 링크 공유
    /// - Parameters:
    ///   - guardianId: 보호자 ID
    ///   - guardianName: 보호자 닉네임
    ///   - wardEmail: 피보호자 이메일
    func shareInviteLink(
        guardianId: String,
        guardianName: String,
        wardEmail: String
    ) async throws

    /// 카카오톡 공유 가능 여부
    var isShareAvailable: Bool { get }
}
