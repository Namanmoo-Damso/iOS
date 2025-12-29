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

    private let authService: AuthService

    // MARK: - Initialization

    init(authService: AuthService = AuthService()) {
        self.authService = authService
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
        // TODO: 실제 API 구현
        // 현재는 Mock 데이터 반환
        #if DEBUG
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5초 지연
        return GuardianDashboardResponse.mock
        #else
        throw AuthError.unknown
        #endif
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
