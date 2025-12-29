//
//  UserType.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 사용자 타입을 구분하는 열거형
/// - guardian: 보호자 (어르신을 돌보는 가족/담당자)
/// - ward: 어르신 (피보호자)
enum UserType: String, Codable, CaseIterable {
    case guardian  // 보호자
    case ward      // 어르신

    /// 화면에 표시할 한글 이름
    var displayName: String {
        switch self {
        case .guardian:
            return "보호자"
        case .ward:
            return "어르신"
        }
    }

    /// 타입 설명
    var description: String {
        switch self {
        case .guardian:
            return "어르신을 돌보는 보호자입니다"
        case .ward:
            return "보호자의 케어를 받는 어르신입니다"
        }
    }
}
