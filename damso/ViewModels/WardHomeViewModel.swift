//
//  WardHomeViewModel.swift
//  damso
//
//  어르신 홈 화면 ViewModel
//

import Foundation
import Combine

@MainActor
final class WardHomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var showCallView: Bool = false
    @Published var todayCallDuration: Int = 0  // 초 단위
    @Published var locationTrackingEnabled: Bool = true
    
    // MARK: - Dependencies
    
    private let locationService: LocationService
    private let callService: CallService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(locationService: LocationService, callService: CallService) {
        self.locationService = locationService
        self.callService = callService
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    func onAppear() {
        refreshMessage()
        startLocationTrackingIfNeeded()
        loadTodayCallDuration()
    }
    
    func refreshMessage() {
        currentMessage = SodamMessagesProvider.randomMessage()
    }
    
    func startCall() {
        showCallView = true
    }
    
    func dismissCall() {
        showCallView = false
    }
    
    func startLocationTrackingIfNeeded() {
        if locationTrackingEnabled {
            locationService.startTracking()
        }
    }
    
    func stopLocationTracking() {
        locationService.stopTracking()
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() {
        locationTrackingEnabled = UserDefaults.standard.bool(forKey: "locationTrackingEnabled")
        todayCallDuration = UserDefaults.standard.integer(forKey: "todayCallDuration")
    }
    
    private func loadTodayCallDuration() {
        todayCallDuration = UserDefaults.standard.integer(forKey: "todayCallDuration")
    }
}

// MARK: - Sodam Messages Provider

/// 소담이 말풍선 메시지 제공자
enum SodamMessagesProvider {
    static let greetings: [String] = [
        "안녕하세요!",
        "오늘 하루도 좋은 하루 되세요!",
        "반가워요!",
        "오늘 기분은 어떠세요?",
        "좋은 아침이에요!",
        "좋은 하루 보내고 계신가요?",
    ]

    static let mealRelated: [String] = [
        "식사는 맛있게 하셨나요?",
        "오늘 뭐 드셨어요?",
        "맛있는 거 드셨나요?",
        "식사하셨어요?",
    ]

    static let healthRelated: [String] = [
        "오늘 건강은 어떠세요?",
        "몸은 괜찮으신가요?",
        "푹 주무셨어요?",
        "잠은 잘 주무셨나요?",
    ]

    static let activityRelated: [String] = [
        "오늘은 뭐 하셨어요?",
        "산책은 하셨나요?",
        "오늘 재미있는 일 있으셨어요?",
        "심심하지 않으셨어요?",
    ]

    static let caring: [String] = [
        "오늘도 함께해요!",
        "이야기 들려주세요!",
        "심심하면 저한테 말 걸어주세요!",
        "궁금한 거 있으면 물어보세요!",
        "오늘도 힘내세요!",
    ]

    /// 시간대에 따른 메시지 선택
    static func randomMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        let pool: [String]
        switch hour {
        case 6..<10:
            pool = greetings + healthRelated
        case 10..<14:
            pool = mealRelated + greetings
        case 14..<18:
            pool = activityRelated + caring
        case 18..<21:
            pool = mealRelated + caring
        default:
            pool = greetings + caring
        }

        return pool.randomElement() ?? "안녕하세요!"
    }
}
