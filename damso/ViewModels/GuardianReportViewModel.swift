//
//  GuardianReportViewModel.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

/// 보호자 분석 보고서 뷰모델
@MainActor
final class GuardianReportViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // 감정 추이
    @Published var emotionTrend: [EmotionDataPoint] = []

    // 건강 키워드
    @Published var healthKeywords: HealthKeywords?

    // 주간 요약
    @Published var weeklySummary: String = ""

    // MARK: - Dependencies

    private let authService: AuthService

    // MARK: - Initialization

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    // MARK: - Public Methods

    /// 보고서 데이터 로드
    func fetchReport() async {
        isLoading = true
        errorMessage = nil

        do {
            let report = try await fetchReportFromServer()
            updateFromResponse(report)
        } catch {
            errorMessage = "보고서를 불러오는데 실패했습니다"
            print("[GuardianReportViewModel] Error: \(error)")

            // 에러 시 Mock 데이터 사용 (개발용)
            #if DEBUG
            updateFromResponse(GuardianReportResponse.mock)
            #endif
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchReportFromServer() async throws -> GuardianReportResponse {
        // TODO: 실제 API 구현
        #if DEBUG
        try await Task.sleep(nanoseconds: 500_000_000)
        return GuardianReportResponse.mock
        #else
        throw AuthError.unknown
        #endif
    }

    private func updateFromResponse(_ response: GuardianReportResponse) {
        emotionTrend = response.emotionTrend
        healthKeywords = response.healthKeywords
        weeklySummary = response.weeklySummary
    }
}
