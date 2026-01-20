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

    // 선택된 어르신 (다중 어르신 지원)
    @Published var selectedWardId: String?

    // 통계
    @Published var totalCalls = 0
    @Published var weeklyChange = 0
    @Published var averageDuration = 0
    @Published var totalDuration = 0  // 총 대화 시간 (분)
    @Published var positiveMoodPercent = 0

    // AI 요약 메시지
    @Published var aiSummaryMessage = "보호자님! 아직 대화 기록이 없습니다."

    // 알림
    @Published var alerts: [DashboardAlert] = []

    // 최근 통화
    @Published var recentCalls: [RecentCall] = []

    // MARK: - Ward Selection

    /// 어르신 선택
    func selectWard(_ ward: WardRegistrationInfo) {
        selectedWardId = ward.linkedWardId ?? ward.registrationId
        Task {
            await fetchDashboard(wardId: selectedWardId)
        }
    }

    /// 특정 어르신의 대시보드 로드
    func fetchDashboard(for ward: WardRegistrationInfo) async {
        let wardId = ward.linkedWardId ?? ward.registrationId
        await fetchDashboard(wardId: wardId)
    }

    // MARK: - Dependencies

    private var authService: AuthService {
        AuthService.shared
    }

    // MARK: - Public Methods

    /// 대시보드 데이터 로드
    /// - Parameters:
    ///   - wardId: 조회할 어르신 ID (없으면 첫 번째 연동된 어르신)
    ///   - period: 기간 필터 (today, week, month)
    func fetchDashboard(wardId: String? = nil, period: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let dashboard = try await fetchDashboardFromServer(wardId: wardId, period: period)
            updateFromResponse(dashboard)
        } catch {
            errorMessage = "데이터를 불러오는데 실패했습니다"
            print("[GuardianDashboardViewModel] Error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchDashboardFromServer(wardId: String? = nil, period: String? = nil) async throws -> GuardianDashboardResponse {
        guard let accessToken = TokenManager.shared.accessToken else {
            throw AuthError.missingAuthToken
        }

        // URL 구성 (ward_id, period 쿼리 파라미터 지원)
        var urlComponents = URLComponents(string: "\(AppConfig.apiBaseURL)/v1/guardian/dashboard")
        var queryItems: [URLQueryItem] = []
        if let wardId { queryItems.append(URLQueryItem(name: "ward_id", value: wardId)) }
        if let period { queryItems.append(URLQueryItem(name: "period", value: period)) }
        if !queryItems.isEmpty { urlComponents?.queryItems = queryItems }
        
        guard let url = urlComponents?.url else {
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

        // 총 대화 시간 계산
        totalDuration = response.recentCalls.reduce(0) { $0 + $1.duration }

        // AI 요약 메시지 (서버 응답 우선, fallback으로 클라이언트 생성)
        if let serverSummary = response.aiSummary, !serverSummary.isEmpty {
            aiSummaryMessage = serverSummary
        } else if let latestCall = response.recentCalls.first {
            let moodText = latestCall.mood == .positive ? "컨디션이 아주 좋으세요" :
                          latestCall.mood == .negative ? "조금 힘들어하시는 것 같아요" :
                          "평소와 비슷하세요"
            aiSummaryMessage = "보호자님! 어르신이 오늘 \(moodText). \(latestCall.summary.prefix(30))..."
        } else {
            aiSummaryMessage = "보호자님! 아직 대화 기록이 없습니다."
        }

        alerts = response.alerts
        recentCalls = response.recentCalls
    }
}
