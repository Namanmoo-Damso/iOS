import Foundation

@MainActor
struct AppConfig {
    /// 현재 설정된 서버 도메인 (기본값은 damsokj)
    static var serverDomain: String {
        get {
            UserDefaults.standard.string(forKey: "selectedServerDomain") ?? "damsokj.duckdns.org"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedServerDomain")
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
}
