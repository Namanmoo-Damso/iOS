import Foundation
#if canImport(LiveKit)
import LiveKit

/// 자막 메시지 모델
struct SubtitleMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isAgent: Bool  // true: AI, false: 사용자
    let timestamp: Date
    var isFinal: Bool

    static func == (lhs: SubtitleMessage, rhs: SubtitleMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// 실시간 자막 관리자
/// Agent 발화 및 사용자 발화 자막을 히스토리로 관리
@MainActor
final class TranscriptionManager: ObservableObject {
    static let shared = TranscriptionManager()

    // MARK: - Published Properties

    /// 자막 히스토리 (스크롤 가능)
    @Published private(set) var messages: [SubtitleMessage] = []

    /// 현재 진행 중인 Agent 자막 (아직 확정되지 않은)
    @Published private(set) var currentAgentText: String = ""

    /// 현재 진행 중인 사용자 자막 (아직 확정되지 않은)
    @Published private(set) var currentUserText: String = ""

    /// 자막 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// AI가 현재 말하고 있는지 (자막 기반)
    @Published private(set) var isAISpeaking: Bool = false

    // MARK: - Legacy Properties (하위 호환성)

    var agentSubtitle: String {
        currentAgentText.isEmpty ? messages.last(where: { $0.isAgent })?.text ?? "" : currentAgentText
    }

    var userSubtitle: String {
        currentUserText.isEmpty ? messages.last(where: { !$0.isAgent })?.text ?? "" : currentUserText
    }

    var isAgentSubtitleFinal: Bool {
        currentAgentText.isEmpty
    }

    var isUserSubtitleFinal: Bool {
        currentUserText.isEmpty
    }

    // MARK: - Private Properties

    private let maxHistoryCount = 50  // 최대 히스토리 개수

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 자막 기능 시작
    func start() {
        isActive = true
        clearAll()
    }

    /// 자막 기능 중지
    func stop() {
        isActive = false
        clearAll()
    }

    /// Agent 자막 업데이트
    func updateAgentSubtitle(text: String, isFinal: Bool) {
        guard isActive else { return }

        // AI가 말하고 있음 (자막이 오면 말하는 중)
        if !text.isEmpty {
            isAISpeaking = true
            #if DEBUG
            print("🎙️ [Transcription] AI Speaking (agent subtitle received)")
            #endif
        }

        if isFinal && !text.isEmpty {
            // 확정된 자막은 히스토리에 추가
            let message = SubtitleMessage(text: text, isAgent: true, timestamp: Date(), isFinal: true)
            addMessage(message)
            currentAgentText = ""

            // 잠시 후 말하기 종료 (다음 자막이 오지 않으면)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if self?.currentAgentText.isEmpty == true {
                    self?.isAISpeaking = false
                    #if DEBUG
                    print("🎙️ [Transcription] AI Silent (no more agent subtitle)")
                    #endif
                }
            }
        } else {
            // 진행 중인 자막은 현재 텍스트로 표시
            currentAgentText = text
        }
    }

    /// 사용자 자막 업데이트 (STT 결과)
    func updateUserSubtitle(text: String, isFinal: Bool) {
        guard isActive else { return }

        // 사용자가 말하면 AI는 듣는 중
        if !text.isEmpty {
            isAISpeaking = false
            #if DEBUG
            print("🎙️ [Transcription] User Speaking → AI Listening")
            #endif
        }

        if isFinal && !text.isEmpty {
            // 확정된 자막은 히스토리에 추가
            let message = SubtitleMessage(text: text, isAgent: false, timestamp: Date(), isFinal: true)
            addMessage(message)
            currentUserText = ""
        } else {
            // 진행 중인 자막은 현재 텍스트로 표시
            currentUserText = text
        }
    }

    /// 모든 자막 초기화
    func clearAll() {
        messages = []
        currentAgentText = ""
        currentUserText = ""
        isAISpeaking = false
    }

    // MARK: - Private Methods

    private func addMessage(_ message: SubtitleMessage) {
        messages.append(message)

        // 최대 개수 초과 시 오래된 메시지 삭제
        if messages.count > maxHistoryCount {
            messages.removeFirst(messages.count - maxHistoryCount)
        }
    }

    // MARK: - Transcription Segment Processing

    /// TranscriptionSegment 배열 처리
    func processTranscriptionSegments(_ segments: [TranscriptionSegment], participantIdentity: String?) {
        guard isActive, !segments.isEmpty else { return }

        let combinedText = segments.map { $0.text }.joined(separator: " ")
        let isFinal = segments.last?.isFinal ?? false

        // Agent인지 사용자인지 구분
        if let identity = participantIdentity, identity.hasPrefix("agent-") {
            updateAgentSubtitle(text: combinedText, isFinal: isFinal)
        } else {
            updateUserSubtitle(text: combinedText, isFinal: isFinal)
        }
    }
}

#endif
