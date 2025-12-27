import Foundation

struct AppConfig {
    /// 변경할 서버 도메인 주소 (이곳만 수정하면 앱 전체에 적용됩니다)
    static let serverDomain = "damsokj.duckdns.org"
    
    /// HTTP API 기본 주소 (예: https://damsokj.duckdns.org)
    static var apiBaseURL: String {
        return "https://\(serverDomain)"
    }
    
    /// LiveKit WebSocket 주소 (예: wss://damsokj.duckdns.org:7880)
    static var liveKitServerURL: String {
        return "wss://\(serverDomain):7880"
    }
}
