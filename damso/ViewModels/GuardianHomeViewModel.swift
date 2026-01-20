//
//  GuardianHomeViewModel.swift
//  damso
//
//  보호자 홈 화면 ViewModel
//

import Foundation
import Combine

/// 기간 필터 타입
enum PeriodFilter: String, CaseIterable {
    case today = "오늘"
    case week = "이번 주"
    case month = "이번 달"
    
    /// 서버 API에 전달할 값
    var apiValue: String {
        switch self {
        case .today: return "today"
        case .week: return "week"
        case .month: return "month"
        }
    }
}

@MainActor
final class GuardianHomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 선택된 어르신 (다중 어르신 지원)
    @Published var selectedWardId: String?
    
    // 통계
    @Published var totalCalls = 0
    @Published var weeklyChange = 0
    @Published var averageDuration = 0
    @Published var totalDuration = 0
    @Published var positiveMoodPercent = 0
    
    // AI 요약 메시지
    @Published var aiSummaryMessage = "보호자님! 아직 대화 기록이 없습니다."
    
    // 데이터
    @Published var alerts: [DashboardAlert] = []
    @Published var recentCalls: [RecentCall] = []
    
    // MARK: - Dependencies
    
    private let guardianRepository: GuardianRepositoryProtocol
    
    // MARK: - Initialization
    
    init(guardianRepository: GuardianRepositoryProtocol = GuardianRepository.shared) {
        self.guardianRepository = guardianRepository
    }
    
    // MARK: - Public Methods
    
    /// 어르신 선택
    func selectWard(_ ward: WardRegistrationInfo) {
        selectedWardId = ward.linkedWardId ?? ward.registrationId
        Task {
            await fetchDashboard(wardId: selectedWardId)
        }
    }
    
    /// 대시보드 데이터 로드
    func fetchDashboard(wardId: String? = nil, period: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        // wardId가 없으면 선택된 ID 사용, 그래도 없으면 nil (API가 알아서 처리하거나 첫번째 ward 사용)
        let targetWardId = wardId ?? selectedWardId
        
        do {
            let response = try await guardianRepository.fetchDashboard(wardId: targetWardId, period: period)
            updateFromResponse(response)
        } catch {
            errorMessage = "데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func updateFromResponse(_ response: GuardianDashboardResponse) {
        totalCalls = response.statistics.totalCalls
        weeklyChange = response.statistics.weeklyChange
        averageDuration = response.statistics.averageDuration
        positiveMoodPercent = response.statistics.overallMood.positive
        
        // 총 대화 시간 계산 (recentCalls 기반이 아니라 통계에서 올 수도 있지만, 현재는 recentCalls 합산 방식 유지 또는 Response에 totalDuration 필드 추가 권장)
        // 일단 Response의 averageDuration * totalCalls로 추정하거나 recentCalls 합산해야 함.
        // 기존 ViewModel 로직: response.recentCalls.reduce(0) { $0 + $1.duration }
        totalDuration = response.recentCalls.reduce(0) { $0 + $1.duration }
        
        // AI 요약 메시지
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
