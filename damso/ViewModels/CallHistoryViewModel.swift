//
//  CallHistoryViewModel.swift
//  damso
//
//  통화 기록 목록 ViewModel
//

import Foundation
import Combine

@MainActor
final class CallHistoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var calls: [RecentCall] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: CallFilter = .all
    
    // MARK: - Filter Types
    
    enum CallFilter: String, CaseIterable {
        case all = "전체"
        case incoming = "수신"
        case outgoing = "발신"
        case missed = "부재중"
    }
    
    // MARK: - Dependencies
    
    private let callService: CallService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(callService: CallService) {
        self.callService = callService
    }
    
    // MARK: - Public Methods
    
    func loadCalls() async {
        isLoading = true
        errorMessage = nil

        // TODO: API 연동 시 실제 호출로 변경
        // calls = try await callService.fetchCallHistory()

        // 현재는 빈 배열 (API 연동 전)
        calls = []

        isLoading = false
    }
    
    func refreshCalls() async {
        await loadCalls()
    }
    
    var filteredCalls: [RecentCall] {
        // TODO: RecentCall 모델에 isIncoming/isMissed 필드 추가 시 필터링 구현
        // 현재는 mood 기반으로 간단히 필터링
        switch selectedFilter {
        case .all:
            return calls
        case .incoming, .outgoing, .missed:
            // 현재 RecentCall 모델에 해당 필드가 없으므로 전체 반환
            return calls
        }
    }
    
    func setFilter(_ filter: CallFilter) {
        selectedFilter = filter
    }
}

