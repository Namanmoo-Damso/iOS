//
//  WardSettingsModels.swift
//  damso
//
//  어르신 설정 관련 모델
//

import Foundation

// MARK: - 어르신 설정 모델

/// 어르신 설정 정보
struct WardSettings: Codable, Equatable {
    /// 알림 설정
    let notificationEnabled: Bool

    /// 자동 응답 설정
    let autoAnswerEnabled: Bool

    /// 자동 응답 대기 시간 (초)
    let autoAnswerDelay: Int

    /// 긴급 연락처
    let emergencyContact: String?

    /// 음성 안내 설정
    let voiceGuideEnabled: Bool

    /// 글자 크기 설정 (small, medium, large)
    let fontSize: String

    /// 고대비 모드
    let highContrastEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case notificationEnabled = "notification_enabled"
        case autoAnswerEnabled = "auto_answer_enabled"
        case autoAnswerDelay = "auto_answer_delay"
        case emergencyContact = "emergency_contact"
        case voiceGuideEnabled = "voice_guide_enabled"
        case fontSize = "font_size"
        case highContrastEnabled = "high_contrast_enabled"
    }
}

// MARK: - 설정 업데이트 요청

/// 어르신 설정 수정 요청
struct WardSettingsUpdateRequest: Codable {
    /// 알림 설정
    var notificationEnabled: Bool?

    /// 자동 응답 설정
    var autoAnswerEnabled: Bool?

    /// 자동 응답 대기 시간 (초)
    var autoAnswerDelay: Int?

    /// 긴급 연락처
    var emergencyContact: String?

    /// 음성 안내 설정
    var voiceGuideEnabled: Bool?

    /// 글자 크기 설정
    var fontSize: String?

    /// 고대비 모드
    var highContrastEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case notificationEnabled = "notification_enabled"
        case autoAnswerEnabled = "auto_answer_enabled"
        case autoAnswerDelay = "auto_answer_delay"
        case emergencyContact = "emergency_contact"
        case voiceGuideEnabled = "voice_guide_enabled"
        case fontSize = "font_size"
        case highContrastEnabled = "high_contrast_enabled"
    }

    /// 기본 생성자
    init(
        notificationEnabled: Bool? = nil,
        autoAnswerEnabled: Bool? = nil,
        autoAnswerDelay: Int? = nil,
        emergencyContact: String? = nil,
        voiceGuideEnabled: Bool? = nil,
        fontSize: String? = nil,
        highContrastEnabled: Bool? = nil
    ) {
        self.notificationEnabled = notificationEnabled
        self.autoAnswerEnabled = autoAnswerEnabled
        self.autoAnswerDelay = autoAnswerDelay
        self.emergencyContact = emergencyContact
        self.voiceGuideEnabled = voiceGuideEnabled
        self.fontSize = fontSize
        self.highContrastEnabled = highContrastEnabled
    }
}

// MARK: - API 응답 래퍼

/// 어르신 설정 API 응답
struct WardSettingsResponse: Codable {
    let success: Bool
    let data: WardSettings?
    let error: APIError?
}

// MARK: - 기본값 확장

extension WardSettings {
    /// 기본 설정값
    static let `default` = WardSettings(
        notificationEnabled: true,
        autoAnswerEnabled: false,
        autoAnswerDelay: 10,
        emergencyContact: nil,
        voiceGuideEnabled: true,
        fontSize: "medium",
        highContrastEnabled: false
    )
}

// MARK: - 글자 크기 열거형

/// 글자 크기 옵션
enum FontSizeOption: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var displayName: String {
        switch self {
        case .small: return "작게"
        case .medium: return "보통"
        case .large: return "크게"
        }
    }
}
