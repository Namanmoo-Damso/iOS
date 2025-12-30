//
//  GuardianReportViewModel.swift
//  damsoTests
//
//  테스트용 ViewModel (AuthService 의존성 제거)
//

import Foundation

/// 보호자 분석 보고서 뷰모델
@MainActor
final class TestGuardianReportViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // 감정 추이
    @Published var emotionTrend: [EmotionDataPoint] = []

    // 건강 키워드
    @Published var healthKeywords: HealthKeywords?

    // 주간 요약
    @Published var weeklySummary: String = ""

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
        #if DEBUG
        try await Task.sleep(nanoseconds: 500_000_000)
        return GuardianReportResponse.mock
        #else
        throw NSError(domain: "TestError", code: 1, userInfo: nil)
        #endif
    }

    private func updateFromResponse(_ response: GuardianReportResponse) {
        emotionTrend = response.emotionTrend
        healthKeywords = response.healthKeywords
        weeklySummary = response.weeklySummary
    }
}
