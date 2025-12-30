//
//  damsoApp.swift
//  damso
//
//  Created by ilim on 2025-12-26.
//

import SwiftUI
import KakaoSDKAuth

@main
struct damsoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var deeplinkManager = DeeplinkManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deeplinkManager)
                .onOpenURL { url in
                    print("[damsoApp] 🔵 onOpenURL 호출됨: \(url)")

                    // 카카오 로그인 URL 처리
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        print("[damsoApp] 🔵 카카오 로그인 URL - handleOpenUrl 호출")
                        _ = AuthController.handleOpenUrl(url: url)
                        return
                    }

                    // damso:// deeplink 처리
                    if url.scheme == "damso" {
                        print("[damsoApp] 🔵 Deeplink 감지: \(url)")
                        deeplinkManager.handleDeeplink(url: url)
                    }
                }
        }
    }
}

// MARK: - Deeplink Manager

@MainActor
final class DeeplinkManager: ObservableObject {
    static let shared = DeeplinkManager()

    /// 딥링크로 요청된 사용자 타입
    @Published var requestedUserType: UserType?

    /// 딥링크 처리 완료 여부
    @Published var hasUnhandledDeeplink = false

    private init() {}

    /// Deeplink URL 처리
    func handleDeeplink(url: URL) {
        guard url.scheme == "damso" else { return }

        let host = url.host
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        print("[DeeplinkManager] host: \(host ?? "nil")")
        print("[DeeplinkManager] queryItems: \(queryItems ?? [])")

        switch host {
        case "login":
            // damso://login?userType=ward
            if let userTypeString = queryItems?.first(where: { $0.name == "userType" })?.value,
               let userType = UserType(rawValue: userTypeString) {
                print("[DeeplinkManager] 로그인 요청 - userType: \(userType)")
                requestedUserType = userType
                hasUnhandledDeeplink = true
            }

        case "invite":
            // damso://invite (향후 확장용)
            print("[DeeplinkManager] 초대 링크")
            requestedUserType = .ward
            hasUnhandledDeeplink = true

        default:
            print("[DeeplinkManager] 알 수 없는 deeplink: \(host ?? "nil")")
        }
    }

    /// 딥링크 처리 완료
    func clearDeeplink() {
        requestedUserType = nil
        hasUnhandledDeeplink = false
    }
}
