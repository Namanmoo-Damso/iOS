import Foundation

@MainActor
struct AppConfig {
    /// 현재 설정된 서버 도메인 (기본값은 1.sodam.store)
    static var serverDomain: String {
        get {
            UserDefaults.standard.selectedServerDomain ?? "1.sodam.store"
        }
        set {
            UserDefaults.standard.selectedServerDomain = newValue
        }
    }

    /// 선택된 개발자 이름 (개발용 테스트)
    static var selectedDeveloperName: String {
        get {
            UserDefaults.standard.string(forKey: "selectedDeveloperName") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedDeveloperName")
        }
    }

    /// HTTP API 기본 주소
    static var apiBaseURL: String {
        return "https://\(serverDomain)"
    }

    /// LiveKit WebSocket 주소
    static var liveKitServerURL: String {
        return "wss://\(serverDomain)"
    }

    /// 푸시 진단 로그 활성화 여부
    nonisolated static let enablePushDiagnostics = true

    // MARK: - 개발용 테스트 데이터

    /// 개발자별 테스트 어르신 이메일 매핑
    nonisolated static let devWardEmails: [String: String] = [
        "권동민": "1002dm@naver.com",
        "김상연": "vhxmwhkd@naver.com",
        "문성수": "seongsu0227@nate.com",
        "배재완": "antjw1999@gmail.com",
        "임익화": "kei1221@naver.com",
        "식스맨": "test@sodam.store"
    ]

    /// 선택된 개발자의 테스트 어르신 이메일 반환
    static var selectedDevWardEmail: String {
        devWardEmails[selectedDeveloperName] ?? ""
    }
}
