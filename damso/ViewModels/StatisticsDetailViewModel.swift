//
//  StatisticsDetailViewModel.swift
//  damso
//
//  통계 상세 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class StatisticsDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var period: StatPeriod = .week
    @Published var isLoading: Bool = false
    @Published var callDurationData: [StatDataPoint] = []
    @Published var activityLevelData: [StatDataPoint] = []
    @Published var fallCount: Int = 0
    @Published var avgCallDuration: Int = 0
    
    // MARK: - Dependencies
    
    private let callService: CallService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(callService: CallService = .shared) {
        self.callService = callService
        // 초기 데이터 로드
        loadStatistics()
    }
    
    // MARK: - Public Methods
    
    func loadStatistics() {
        isLoading = true
        
        // Mock Data Generation
        generateMockData()
        
        isLoading = false
    }
    
    func changePeriod(_ newPeriod: StatPeriod) {
        period = newPeriod
        loadStatistics()
    }
    
    // MARK: - Private Methods
    
    private func generateMockData() {
        // 실제 API 연동 전 가짜 데이터
        var data: [StatDataPoint] = []
        let calendar = Calendar.current
        let today = Date()
        
        let count = period == .week ? 7 : 30
        
        for i in 0..<count {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let duration = Int.random(in: 10...60)
                data.append(StatDataPoint(date: date, value: Double(duration)))
            }
        }
        
        callDurationData = data.reversed()
        avgCallDuration = Int(data.map { $0.value }.reduce(0, +)) / max(1, count)
    }
}

enum StatPeriod: String, CaseIterable {
    case week = "주간"
    case month = "월간"
}

struct StatDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
