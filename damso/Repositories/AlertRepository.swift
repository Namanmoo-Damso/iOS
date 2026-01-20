//
//  AlertRepository.swift
//  damso
//
//  알림 Repository - Moya + Combine 기반
//

import Foundation
import Combine
import Moya
import CombineMoya

// MARK: - Alert Repository Protocol

protocol AlertRepositoryProtocol {
    func fetchAlerts(wardId: String?, page: Int, limit: Int) -> AnyPublisher<[DashboardAlert], NetworkError>
    func fetchDetail(alertId: String) -> AnyPublisher<AlertDTO, NetworkError>
    func acknowledge(alertId: String) -> AnyPublisher<Void, NetworkError>
    
    // async/await 버전
    func fetchAlerts(wardId: String?, page: Int, limit: Int) async throws -> [DashboardAlert]
    func acknowledge(alertId: String) async throws
}

// MARK: - Alert Repository Implementation

@MainActor
final class AlertRepository: AlertRepositoryProtocol {
    
    static let shared = AlertRepository()
    
    private let provider: MoyaProvider<AlertAPI>
    
    init(provider: MoyaProvider<AlertAPI> = NetworkProviders.shared.alert) {
        self.provider = provider
    }
    
    // MARK: - Combine Publishers
    
    func fetchAlerts(wardId: String?, page: Int, limit: Int) -> AnyPublisher<[DashboardAlert], NetworkError> {
        return provider.requestPublisher(.list(wardId: wardId, page: page, limit: limit), type: AlertListResponse.self)
            .map { $0.alerts.map { $0.toDashboardAlert() } }
            .eraseToAnyPublisher()
    }
    
    func fetchDetail(alertId: String) -> AnyPublisher<AlertDTO, NetworkError> {
        return provider.requestPublisher(.detail(alertId: alertId), type: AlertDTO.self)
    }
    
    func acknowledge(alertId: String) -> AnyPublisher<Void, NetworkError> {
        return provider.requestVoidPublisher(.acknowledge(alertId: alertId))
    }
    
    // MARK: - Async/Await
    
    func fetchAlerts(wardId: String?, page: Int, limit: Int) async throws -> [DashboardAlert] {
        let response = try await provider.request(.list(wardId: wardId, page: page, limit: limit), type: AlertListResponse.self)
        return response.alerts.map { $0.toDashboardAlert() }
    }
    
    func acknowledge(alertId: String) async throws {
        try await provider.requestVoid(.acknowledge(alertId: alertId))
    }
}

// MARK: - Mock Alert Repository (for Testing)

#if DEBUG
final class MockAlertRepository: AlertRepositoryProtocol {
    
    var alerts: [DashboardAlert] = []
    var fetchCalled = false
    var acknowledgeCalled = false
    
    func fetchAlerts(wardId: String?, page: Int, limit: Int) -> AnyPublisher<[DashboardAlert], NetworkError> {
        fetchCalled = true
        return Just(alerts).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchDetail(alertId: String) -> AnyPublisher<AlertDTO, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock", code: -1))).eraseToAnyPublisher()
    }
    
    func acknowledge(alertId: String) -> AnyPublisher<Void, NetworkError> {
        acknowledgeCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchAlerts(wardId: String?, page: Int, limit: Int) async throws -> [DashboardAlert] {
        fetchCalled = true
        return alerts
    }
    
    func acknowledge(alertId: String) async throws {
        acknowledgeCalled = true
    }
}
#endif
