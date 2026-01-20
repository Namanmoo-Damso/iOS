//
//  AlertDetailViewModel.swift
//  damso
//
//  알림 상세 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class AlertDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var alert: DashboardAlert
    @Published var isLoading: Bool = false
    @Published var isAcknowledged: Bool = false
    @Published var relatedSensorData: SensorSnapshot?
    @Published var locationInfo: LocationInfo?
    
    // MARK: - Dependencies
    
    private let careAlertService: CareAlertService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(alert: DashboardAlert, careAlertService: CareAlertService) {
        self.alert = alert
        self.careAlertService = careAlertService
    }
    
    // MARK: - Public Methods
    
    func loadAlertDetails() async {
        isLoading = true
        
        // TODO: API 연동 시 상세 정보 로드
        // let details = try await careAlertService.fetchAlertDetail(alertId: alert.id)
        
        isLoading = false
    }
    
    func acknowledgeAlert() async {
        guard !isAcknowledged else { return }
        
        do {
            // TODO: API 연동
            // try await careAlertService.acknowledgeAlert(alertId: alert.id)
            isAcknowledged = true
        } catch {
            // 오류 처리
        }
    }
    
    func callWard() {
        // 어르신에게 전화하기 기능
        // CallManager를 통해 통화 시작
    }
}

// MARK: - Supporting Types

struct SensorSnapshot {
    let timestamp: Date
    let fallRisk: Float
    let accelerationMagnitude: Float
    let rotationMagnitude: Float
    let isFreefalling: Bool
}

struct LocationInfo {
    let latitude: Double
    let longitude: Double
    let address: String?
    let timestamp: Date
}
