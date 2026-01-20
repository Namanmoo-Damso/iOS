//
//  CallDetailViewModel.swift
//  damso
//
//  통화 상세 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class CallDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var call: RecentCall
    @Published var isLoading: Bool = false
    @Published var transcription: String = ""
    @Published var emotionAnalysis: EmotionAnalysisResult?
    @Published var keywords: [KeywordItem] = []
    @Published var highlights: [HighlightItem] = []
    @Published var aiInsight: String = ""
    
    // MARK: - Dependencies
    
    private let callService: CallService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(call: RecentCall, callService: CallService) {
        self.call = call
        self.callService = callService
    }
    
    // MARK: - Public Methods
    
    func loadCallDetails() async {
        isLoading = true
        
        do {
            // TODO: API 연동 시 실제 호출로 변경
            // let details = try await callService.fetchCallDetail(callId: call.id)
            
            // 현재는 기본값 사용
            transcription = call.summary
            aiInsight = generateAIInsight()
        } catch {
            // 오류 처리
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func generateAIInsight() -> String {
        switch call.mood {
        case .positive:
            return "대화가 전반적으로 긍정적이었습니다. 어르신이 밝은 기분으로 대화에 참여하셨습니다."
        case .negative:
            return "대화 중 어르신이 우울하거나 힘들어하는 모습이 감지되었습니다. 추가적인 확인이 필요할 수 있습니다."
        case .neutral:
            return "평소와 비슷한 대화가 이루어졌습니다. 특별히 걱정되는 부분은 없습니다."
        }
    }
}

// MARK: - Supporting Types

// Note: EmotionAnalysisResult is defined in CallServiceModels.swift

struct KeywordItem: Identifiable {
    let id = UUID()
    let keyword: String
    let frequency: Int
}

struct HighlightItem: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let timestamp: Date
}
