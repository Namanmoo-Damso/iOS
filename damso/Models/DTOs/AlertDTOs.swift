//
//  AlertDTOs.swift
//  damso
//
//  알림/알럿 관련 DTO (Data Transfer Objects)
//

import Foundation

// MARK: - Alert Request DTOs

/// 알림 확인 요청
struct AcknowledgeAlertRequest: Codable {
    let alertId: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case alertId = "alert_id"
        case timestamp
    }
}

/// 알림 목록 조회 요청
struct AlertListRequest: Codable {
    let wardId: String?
    let page: Int
    let limit: Int
    let alertType: String?  // "fall", "emergency", "health"
    
    enum CodingKeys: String, CodingKey {
        case wardId = "ward_id"
        case page
        case limit
        case alertType = "alert_type"
    }
}

// MARK: - Alert Response DTOs

/// 알림 목록 응답
struct AlertListResponse: Codable {
    let alerts: [AlertDTO]
    let totalCount: Int
    let page: Int
    
    enum CodingKeys: String, CodingKey {
        case alerts
        case totalCount = "total_count"
        case page
    }
}

/// 단일 알림 DTO
struct AlertDTO: Codable, Identifiable {
    let id: String
    let wardId: String
    let alertType: String  // "fall", "emergency", "health"
    let severity: String   // "critical", "warning", "info"
    let message: String
    let timestamp: Date
    let isAcknowledged: Bool
    let sensorData: SensorDataDTO?
    let locationData: LocationDataDTO?
    
    enum CodingKeys: String, CodingKey {
        case id
        case wardId = "ward_id"
        case alertType = "alert_type"
        case severity
        case message
        case timestamp
        case isAcknowledged = "is_acknowledged"
        case sensorData = "sensor_data"
        case locationData = "location_data"
    }
    
    /// Domain DashboardAlert 모델로 변환
    /// Note: DashboardAlert에는 severity가 없으므로 alertType으로 type 매핑
    func toDashboardAlert() -> DashboardAlert {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        
        // alertType을 DashboardAlert.AlertType으로 매핑
        let dashboardAlertType: DashboardAlert.AlertType
        switch alertType {
        case "fall", "emergency":
            dashboardAlertType = .warning
        default:
            dashboardAlertType = .info
        }
        
        return DashboardAlert(
            id: id,
            type: dashboardAlertType,
            message: message,
            date: formatter.string(from: timestamp)
        )
    }
}

/// 센서 데이터 DTO
struct SensorDataDTO: Codable {
    let fallRisk: Float
    let accelerationMagnitude: Float
    let rotationMagnitude: Float
    let isFreefalling: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case fallRisk = "fall_risk"
        case accelerationMagnitude = "acceleration_magnitude"
        case rotationMagnitude = "rotation_magnitude"
        case isFreefalling = "is_freefalling"
        case timestamp
    }
}

/// 위치 데이터 DTO
struct LocationDataDTO: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let address: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case accuracy
        case address
        case timestamp
    }
}

// MARK: - Alert Types

/// 알림 타입 (API 응답용)
enum AlertType: String, Codable {
    case fall
    case emergency
    case health
}

/// 알림 심각도 (API 응답 및 EventStreamModels에서 공용 사용)
enum AlertSeverity: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical
    case warning
    case info
    
    /// 우선순위 (높을수록 긴급)
    var priority: Int {
        switch self {
        case .low:
            return 1
        case .medium, .info:
            return 2
        case .high, .warning:
            return 3
        case .critical:
            return 4
        }
    }
    
    /// 표시용 문자열
    var displayName: String {
        switch self {
        case .low:
            return "낮음"
        case .medium:
            return "보통"
        case .high:
            return "높음"
        case .critical:
            return "긴급"
        case .warning:
            return "경고"
        case .info:
            return "정보"
        }
    }
}
