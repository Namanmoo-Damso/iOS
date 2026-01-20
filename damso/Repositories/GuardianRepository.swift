//
//  GuardianRepository.swift
//  damso
//
//  보호자 관련 데이터 저장소 (대시보드, 리포트 등)
//

import Foundation
import Combine
import Moya

protocol GuardianRepositoryProtocol {
    func fetchDashboard(wardId: String?, period: String?) async throws -> GuardianDashboardResponse
    func fetchReport(wardId: String?, startDate: String?, endDate: String?) async throws -> GuardianReportResponse
}

final class GuardianRepository: GuardianRepositoryProtocol {
    static let shared = GuardianRepository()
    private let provider: MoyaProvider<GuardianAPI>
    
    init(provider: MoyaProvider<GuardianAPI>? = nil) {
        self.provider = provider ?? MoyaProvider<GuardianAPI>()
    }
    
    func fetchDashboard(wardId: String? = nil, period: String? = nil) async throws -> GuardianDashboardResponse {
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(.dashboard(wardId: wardId, period: period)) { result in
                switch result {
                case .success(let response):
                    do {
                        let response = try response.filterSuccessfulStatusAndRedirectCodes()
                        let data = try response.map(GuardianDashboardResponse.self, using: JSONDecoder.apiDecoder)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchReport(wardId: String? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> GuardianReportResponse {
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(.report(wardId: wardId, startDate: startDate, endDate: endDate)) { result in
                switch result {
                case .success(let response):
                    do {
                        let response = try response.filterSuccessfulStatusAndRedirectCodes()
                        let data = try response.map(GuardianReportResponse.self, using: JSONDecoder.apiDecoder)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
