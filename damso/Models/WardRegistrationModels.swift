//
//  WardRegistrationModels.swift
//  damso
//
//  어르신 등록 관련 모델
//

import Foundation

// MARK: - 관계 타입

/// 보호자와 어르신의 관계
enum WardRelationType: String, Codable, CaseIterable, Identifiable {
    case parent = "parent"           // 부모님
    case grandparent = "grandparent" // 조부모님
    case spouse = "spouse"           // 배우자
    case relative = "relative"       // 친척
    case other = "other"             // 기타

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parent: return "부모님"
        case .grandparent: return "조부모님"
        case .spouse: return "배우자"
        case .relative: return "친척"
        case .other: return "기타"
        }
    }
}

// MARK: - 성별

/// 성별
enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"

    var displayName: String {
        switch self {
        case .male: return "남성"
        case .female: return "여성"
        }
    }
}

// MARK: - 어르신 기본 정보

/// 어르신 등록 기본 정보
struct WardBasicInfo: Codable, Equatable {
    var name: String               // 성함
    var relation: WardRelationType // 관계
    var phoneNumber: String        // 휴대폰 번호 (연동용)
    var birthDate: String          // 생년월일 (YYYYMMDD)
    var gender: Gender             // 성별
    var address: String            // 거주지 주소

    init(
        name: String = "",
        relation: WardRelationType = .parent,
        phoneNumber: String = "",
        birthDate: String = "",
        gender: Gender = .male,
        address: String = ""
    ) {
        self.name = name
        self.relation = relation
        self.phoneNumber = phoneNumber
        self.birthDate = birthDate
        self.gender = gender
        self.address = address
    }
}

// MARK: - AI 케어 정보

/// AI 케어를 위한 부가 정보 (선택)
struct AICarInfo: Codable, Equatable {
    var medicalConditions: String  // 기저질환 / 앓고 계신 병
    var medications: String        // 복용 중인 약

    init(
        medicalConditions: String = "",
        medications: String = ""
    ) {
        self.medicalConditions = medicalConditions
        self.medications = medications
    }
}

// MARK: - AI 전화 스케줄

/// 요일
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 0
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "일"
        case .monday: return "월"
        case .tuesday: return "화"
        case .wednesday: return "수"
        case .thursday: return "목"
        case .friday: return "금"
        case .saturday: return "토"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "일요일"
        case .monday: return "월요일"
        case .tuesday: return "화요일"
        case .wednesday: return "수요일"
        case .thursday: return "목요일"
        case .friday: return "금요일"
        case .saturday: return "토요일"
        }
    }
}

/// AI 전화 스케줄 항목 (슬롯 기반)
struct AICallScheduleItem: Codable, Identifiable, Equatable {
    let id: String
    var slotStartHour: Int      // 슬롯 시작 시 (0-23)
    var slotStartMinute: Int    // 슬롯 시작 분 (0, 10, 20, 30, 40, 50)
    var weekdays: Set<Weekday>  // 요일들
    var isEnabled: Bool         // 활성화 여부

    /// 슬롯 설정 (10분 단위)
    static let slotDurationMinutes = 10
    static let maxCallDurationMinutes = 8
    static let validMinutes = [0, 10, 20, 30, 40, 50]

    // MARK: - CodingKeys (camelCase for API)
    enum CodingKeys: String, CodingKey {
        case id
        case slotStartHour  // camelCase
        case slotStartMinute  // camelCase
        case weekdays
        case isEnabled  // camelCase
    }

    init(
        id: String = UUID().uuidString,
        slotStartHour: Int = 10,
        slotStartMinute: Int = 0,
        weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.slotStartHour = slotStartHour
        // 10분 단위로 정규화
        self.slotStartMinute = Self.validMinutes.min(by: { abs($0 - slotStartMinute) < abs($1 - slotStartMinute) }) ?? 0
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }

    /// 레거시 호환: Date에서 생성
    init(id: String = UUID().uuidString, time: Date, weekdays: Set<Weekday>, isEnabled: Bool = true) {
        self.id = id
        let calendar = Calendar.current
        self.slotStartHour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        self.slotStartMinute = Self.validMinutes.min(by: { abs($0 - minute) < abs($1 - minute) }) ?? 0
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }

    // MARK: - Custom Codable (camelCase 사용)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.slotStartHour = (try? container.decode(Int.self, forKey: .slotStartHour)) ?? 10
        self.slotStartMinute = (try? container.decode(Int.self, forKey: .slotStartMinute)) ?? 0
        self.weekdays = (try? container.decode(Set<Weekday>.self, forKey: .weekdays)) ?? []
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
    }

    func encode(to encoder: Encoder) throws {
        // API로 보낼 때 camelCase 사용
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slotStartHour, forKey: .slotStartHour)
        try container.encode(slotStartMinute, forKey: .slotStartMinute)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    /// Date 객체로 변환 (UI 호환용)
    var time: Date {
        get {
            Calendar.current.date(bySettingHour: slotStartHour, minute: slotStartMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let calendar = Calendar.current
            slotStartHour = calendar.component(.hour, from: newValue)
            let minute = calendar.component(.minute, from: newValue)
            slotStartMinute = Self.validMinutes.min(by: { abs($0 - minute) < abs($1 - minute) }) ?? 0
        }
    }

    /// 슬롯 시간 문자열 (예: "10:00 ~ 10:10")
    var slotTimeString: String {
        let endHour: Int
        let endMinute: Int
        if slotStartMinute + Self.slotDurationMinutes >= 60 {
            endHour = slotStartHour + 1
            endMinute = (slotStartMinute + Self.slotDurationMinutes) % 60
        } else {
            endHour = slotStartHour
            endMinute = slotStartMinute + Self.slotDurationMinutes
        }
        return String(format: "%02d:%02d ~ %02d:%02d", slotStartHour, slotStartMinute, endHour, endMinute)
    }

    /// 시간 문자열 (예: "10:00") - 레거시 호환
    var timeString: String {
        String(format: "%02d:%02d", slotStartHour, slotStartMinute)
    }

    /// 요일 요약 문자열 (예: "월, 화, 수, 목, 금")
    var weekdaysSummary: String {
        if weekdays.count == 7 {
            return "매일"
        }
        if weekdays == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
            return "평일"
        }
        if weekdays == Set([.saturday, .sunday]) {
            return "주말"
        }
        return weekdays.sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
    }
}

/// AI 전화 스케줄 전체
struct AICallSchedule: Codable, Equatable {
    var items: [AICallScheduleItem]
    var isEnabled: Bool  // 전체 스케줄 활성화 여부

    // MARK: - CodingKeys (camelCase for API)
    enum CodingKeys: String, CodingKey {
        case items
        case isEnabled  // camelCase
    }

    init(items: [AICallScheduleItem] = [], isEnabled: Bool = true) {
        self.items = items
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = (try? container.decode([AICallScheduleItem].self, forKey: .items)) ?? []
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
    }

    func encode(to encoder: Encoder) throws {
        // API로 보낼 때 camelCase 사용
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    static var `default`: AICallSchedule {
        AICallSchedule(
            items: [AICallScheduleItem()],
            isEnabled: true
        )
    }
}

// MARK: - 어르신 등록 전체 요청

/// 어르신 등록 요청 (보호자가 제출) - 온보딩용
struct WardOnboardingRequest: Codable {
    let basicInfo: WardBasicInfo
    let aiCareInfo: AICarInfo?
    let callSchedule: AICallSchedule?

    enum CodingKeys: String, CodingKey {
        case basicInfo = "basic_info"
        case aiCareInfo = "ai_care_info"
        case callSchedule = "call_schedule"
    }
}

// MARK: - 스케줄 API 모델

/// 스케줄 API 응답
struct ScheduleResponse: Codable {
    let items: [ScheduleItemResponse]
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case isEnabled  // camelCase
    }

    /// AICallSchedule로 변환
    func toSchedule() -> AICallSchedule {
        AICallSchedule(
            items: items.map { $0.toScheduleItem() },
            isEnabled: isEnabled
        )
    }
}

/// 스케줄 항목 API 응답 (슬롯 기반)
struct ScheduleItemResponse: Codable {
    let id: String
    let slotStartHour: Int      // 0-23
    let slotStartMinute: Int    // 0, 10, 20, 30, 40, 50
    let weekdays: [Int]         // 요일 rawValue 배열
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case slotStartHour  // camelCase
        case slotStartMinute  // camelCase
        case weekdays
        case isEnabled  // camelCase
    }

    /// AICallScheduleItem으로 변환
    func toScheduleItem() -> AICallScheduleItem {
        let weekdaySet = Set(weekdays.compactMap { Weekday(rawValue: $0) })

        return AICallScheduleItem(
            id: id,
            slotStartHour: slotStartHour,
            slotStartMinute: slotStartMinute,
            weekdays: weekdaySet,
            isEnabled: isEnabled
        )
    }
}

/// AI 스케줄 저장 요청 (슌롯 기반)
struct AIScheduleRequest: Codable {
    let wardId: String?         // 다중 어르신 지원: 대상 어르신 ID
    let items: [AIScheduleItemRequest]
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case wardId  // camelCase
        case items
        case isEnabled  // camelCase
    }

    init(schedule: AICallSchedule, wardId: String? = nil) {
        self.wardId = wardId
        self.items = schedule.items.map { AIScheduleItemRequest(item: $0) }
        self.isEnabled = schedule.isEnabled
    }
}

/// AI 스케줄 항목 저장 요청 (슬롯 기반)
struct AIScheduleItemRequest: Codable {
    let id: String
    let slotStartHour: Int      // 0-23
    let slotStartMinute: Int    // 0, 10, 20, 30, 40, 50
    let weekdays: [Int]         // 요일 rawValue 배열
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case slotStartHour  // camelCase
        case slotStartMinute  // camelCase
        case weekdays
        case isEnabled  // camelCase
    }

    init(item: AICallScheduleItem) {
        self.id = item.id
        self.slotStartHour = item.slotStartHour
        self.slotStartMinute = item.slotStartMinute
        self.weekdays = item.weekdays.map { $0.rawValue }.sorted()
        self.isEnabled = item.isEnabled
    }
}

// MARK: - 스케줄 업데이트 요청 (레거시)

/// AI 전화 스케줄 업데이트 요청
struct UpdateScheduleRequest: Codable {
    let wardId: String
    let schedule: AICallSchedule

    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case schedule
    }
}
