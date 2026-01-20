//
//  ScheduleDTOs.swift
//  damso
//
//  스케줄 관련 DTO (Data Transfer Objects)
//

import Foundation

// MARK: - Schedule Request DTOs

/// 스케줄 생성/수정 요청 (슬롯 기반 API)
struct ScheduleRequest: Codable {
    let wardId: String
    let slotStartHour: Int      // 0-23
    let slotStartMinute: Int    // 0, 10, 20, 30, 40, 50
    let weekdays: [Int]         // 0-6 (일-토)
    let isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case slotStartHour
        case slotStartMinute
        case weekdays
        case isEnabled
    }
}

/// 스케줄 일괄 저장 요청 (RegistrationService 호환)
struct ScheduleSaveRequest: Codable {
    let wardId: String?
    let schedules: [ScheduleItemRequest]
    
    init(schedule: AICallSchedule, wardId: String? = nil) {
        self.wardId = wardId
        self.schedules = schedule.items.map { item in
            ScheduleItemRequest(
                id: item.id,
                slotStartHour: item.slotStartHour,
                slotStartMinute: item.slotStartMinute,
                weekdays: item.weekdays.map { $0.rawValue }.sorted(),
                isEnabled: item.isEnabled
            )
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case schedules
    }
}

/// 개별 스케줄 아이템 요청
struct ScheduleItemRequest: Codable {
    let id: String
    let slotStartHour: Int
    let slotStartMinute: Int
    let weekdays: [Int]
    let isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case slotStartHour
        case slotStartMinute
        case weekdays
        case isEnabled
    }
}

/// 스케줄 상태 업데이트 요청
struct ScheduleStatusUpdateRequest: Codable {
    let isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case isEnabled
    }
}

// MARK: - Schedule Response DTOs

/// 스케줄 목록 응답
struct ScheduleListResponse: Codable {
    let schedules: [ScheduleDTO]
}

/// 단일 스케줄 DTO
struct ScheduleDTO: Codable, Identifiable {
    let id: String
    let wardId: String
    let slotStartHour: Int
    let slotStartMinute: Int
    let weekdays: [Int]
    let isEnabled: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case wardId = "ward_id"
        case slotStartHour
        case slotStartMinute
        case weekdays
        case isEnabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Domain AICallScheduleItem 모델로 변환
    func toAICallScheduleItem() -> AICallScheduleItem {
        AICallScheduleItem(
            id: id,
            slotStartHour: slotStartHour,
            slotStartMinute: slotStartMinute,
            weekdays: Set(weekdays.compactMap { Weekday(rawValue: $0) }),
            isEnabled: isEnabled
        )
    }
}

// MARK: - Helper Extension

extension AICallScheduleItem {
    /// DTO로 변환 (API 전송용)
    func toRequest(wardId: String) -> ScheduleRequest {
        ScheduleRequest(
            wardId: wardId,
            slotStartHour: slotStartHour,
            slotStartMinute: slotStartMinute,
            weekdays: weekdays.map { $0.rawValue }.sorted(),
            isEnabled: isEnabled
        )
    }
}
