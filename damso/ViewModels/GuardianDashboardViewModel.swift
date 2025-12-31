//
//  GuardianDashboardViewModel.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

/// 보호자 대시보드 뷰모델
@MainActor
final class GuardianDashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // 통계
    @Published var totalCalls = 0
    @Published var weeklyChange = 0
    @Published var averageDuration = 0
    @Published var positiveMoodPercent = 0

    // 알림
    @Published var alerts: [DashboardAlert] = []

    // 최근 통화
    @Published var recentCalls: [RecentCall] = []

    // MARK: - Dependencies

    private var authService: AuthService {
        AuthService.shared
    }

    // MARK: - Public Methods

    /// 대시보드 데이터 로드
    func fetchDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let dashboard = try await fetchDashboardFromServer()
            updateFromResponse(dashboard)
        } catch {
            errorMessage = "데이터를 불러오는데 실패했습니다"
            print("[GuardianDashboardViewModel] Error: \(error)")

            // 에러 시 Mock 데이터 사용 (개발용)
            #if DEBUG
            updateFromResponse(GuardianDashboardResponse.mock)
            #endif
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchDashboardFromServer() async throws -> GuardianDashboardResponse {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/guardian/dashboard") else {
            throw AuthError.networkError("Invalid dashboard URL")
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: Numbers.Timeout.networkRequest)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.httpStatus(code: httpResponse.statusCode, body: bodyText)
        }

        do {
            return try JSONDecoder.apiDecoder.decode(GuardianDashboardResponse.self, from: data)
        } catch {
            Log.auth.e("Dashboard decoding error: \(error)")
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    private func updateFromResponse(_ response: GuardianDashboardResponse) {
        totalCalls = response.statistics.totalCalls
        weeklyChange = response.statistics.weeklyChange
        averageDuration = response.statistics.averageDuration
        positiveMoodPercent = response.statistics.overallMood.positive

        alerts = response.alerts
        recentCalls = response.recentCalls
    }
}
