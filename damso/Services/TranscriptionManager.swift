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

    /// AI가 현재 말하고 있는지 (LiveKit VAD 기반)
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

    /// LiveKit VAD가 활성화되었는지 여부 (한 번이라도 호출되면 true)
    private var isLiveKitVADActive: Bool = false


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

    /// AI 발화 상태 설정 (LiveKit VAD에서 호출 - 우선순위 높음)
    func setAISpeaking(_ speaking: Bool) {
        // LiveKit VAD가 동작함을 표시
        isLiveKitVADActive = true

        guard isAISpeaking != speaking else { return }
        isAISpeaking = speaking
        #if DEBUG
        print("🎙️ [Transcription] AI \(speaking ? "Speaking" : "Listening") (from LiveKit VAD)")
        #endif
    }

    /// Agent 자막 업데이트
    func updateAgentSubtitle(text: String, isFinal: Bool) {
        guard isActive else { return }

        // LiveKit VAD가 없을 때 자막 기반으로 발화 상태 추정 (즉시 전환)
        if !isLiveKitVADActive {
            if !text.isEmpty && !isAISpeaking {
                // 명시적으로 objectWillChange 트리거
                objectWillChange.send()
                isAISpeaking = true
                #if DEBUG
                print("🎙️ [Transcription] AI Speaking (subtitle fallback) → isAISpeaking=\(isAISpeaking)")
                #endif
            }
        }

        if isFinal && !text.isEmpty {
            // 확정된 자막은 히스토리에 추가
            let message = SubtitleMessage(text: text, isAgent: true, timestamp: Date(), isFinal: true)
            addMessage(message)
            currentAgentText = ""

            if !isLiveKitVADActive && isAISpeaking {
                // 자막 종료 시 즉시 듣기 상태로 전환
                objectWillChange.send()
                isAISpeaking = false
                #if DEBUG
                print("🎙️ [Transcription] AI Listening (subtitle fallback) → isAISpeaking=\(isAISpeaking)")
                #endif
            }
        } else {
            // 진행 중인 자막은 현재 텍스트로 표시
            currentAgentText = text
        }
    }

    /// 사용자 자막 업데이트 (STT 결과)
    func updateUserSubtitle(text: String, isFinal: Bool) {
        guard isActive else { return }

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
        isLiveKitVADActive = false

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
        #if DEBUG
        print("🎙️ [Transcription] processTranscriptionSegments called - isActive=\(isActive), segments=\(segments.count), identity=\(participantIdentity ?? "nil")")
        #endif

        guard isActive, !segments.isEmpty else {
            #if DEBUG
            print("🎙️ [Transcription] Skipped - isActive=\(isActive), isEmpty=\(segments.isEmpty)")
            #endif
            return
        }

        let combinedText = segments.map { $0.text }.joined(separator: " ")
        let isFinal = segments.last?.isFinal ?? false

        #if DEBUG
        print("🎙️ [Transcription] Text: \"\(combinedText)\", isFinal=\(isFinal)")
        #endif

        // Agent인지 사용자인지 구분
        // agent-, sodam, 또는 LocalParticipant가 아닌 경우 Agent로 처리
        let isAgent = isAgentParticipant(identity: participantIdentity)

        #if DEBUG
        print("🎙️ [Transcription] isAgent=\(isAgent)")
        #endif

        if isAgent {
            updateAgentSubtitle(text: combinedText, isFinal: isFinal)
        } else {
            updateUserSubtitle(text: combinedText, isFinal: isFinal)
        }
    }

    /// Agent participant인지 확인
    private func isAgentParticipant(identity: String?) -> Bool {
        guard let identity = identity else { return false }

        // Agent identity 패턴들
        let agentPatterns = ["agent-", "sodam", "ai-", "assistant"]
        for pattern in agentPatterns {
            if identity.lowercased().contains(pattern) {
                return true
            }
        }

        return false
    }
}

#endif
