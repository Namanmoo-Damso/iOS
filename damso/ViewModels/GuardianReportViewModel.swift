//
//  GuardianReportViewModel.swift
//  damso
//
//  보호자 리포트 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class GuardianReportViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var reportData: GuardianReportResponse?
    @Published var selectedDate: Date = Date()
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let guardianRepository: GuardianRepositoryProtocol
    
    // MARK: - Initialization
    
    init(guardianRepository: GuardianRepositoryProtocol = GuardianRepository.shared) {
        self.guardianRepository = guardianRepository
        // 초기 로딩은 View에서 task로 실행하는 것이 좋음 (init에서 호출하면 테스팅 어려움)
    }
    
    // MARK: - Public Methods
    
    func fetchReport() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 날짜 포맷팅 등은 필요 시 추가 (현재는 API가 처리한다고 가정하거나 파라미터 없음)
            let response = try await guardianRepository.fetchReport(wardId: nil, startDate: nil, endDate: nil)
            reportData = response
            
        } catch {
            errorMessage = "리포트를 불러오는데 실패했습니다: \(error.localizedDescription)"
            
            // TODO: 개발 중에는 Mock Data라도 보여줄지 결정
            // loadMockData()
        }
        
        isLoading = false
    }
    
    // 개발용 Mock Data
    private func loadMockData() {
        // ...
    }
}
