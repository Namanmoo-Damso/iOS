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

    private var authService: AuthService {
        AuthService.shared
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
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchReportFromServer() async throws -> GuardianReportResponse {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/guardian/report?period=week") else {
            throw AuthError.networkError("Invalid report URL")
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
            return try JSONDecoder.apiDecoder.decode(GuardianReportResponse.self, from: data)
        } catch {
            Log.auth.e("Report decoding error: \(error)")
            throw AuthError.decodingError(error.localizedDescription)
        }
    }

    private func updateFromResponse(_ response: GuardianReportResponse) {
        emotionTrend = response.emotionTrend
        healthKeywords = response.healthKeywords
        weeklySummary = response.weeklySummary
    }
}
