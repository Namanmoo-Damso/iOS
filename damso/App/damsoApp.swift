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
                // Universal Link 처리 (SwiftUI 방식)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    print("[damsoApp] 🔗 onContinueUserActivity 호출됨")
                    guard let url = userActivity.webpageURL else { return }
                    print("[damsoApp] 🔗 Universal Link URL: \(url)")
                    deeplinkManager.handleUniversalLink(url: url)
                }
        }
    }
}

// MARK: - Deeplink Manager

@MainActor
final class DeeplinkManager: ObservableObject {
    static let shared = DeeplinkManager()

    /// Universal Link 도메인
    private static let universalLinkHost = "1.sodam.store"

    /// 딥링크로 요청된 사용자 타입
    @Published var requestedUserType: UserType?

    /// 딥링크 처리 완료 여부
    @Published var hasUnhandledDeeplink = false

    /// 자동 로그인 진행 여부 (Universal Link로 진입 시 true)
    @Published var shouldAutoTriggerLogin = false

    private init() {}

    /// Custom Scheme Deeplink URL 처리 (damso://)
    func handleDeeplink(url: URL) {
        guard url.scheme == "damso" else { return }

        let host = url.host
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        print("[DeeplinkManager] Custom Scheme - host: \(host ?? "nil")")
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
            print("[DeeplinkManager] 초대 링크 (Custom Scheme)")
            requestedUserType = .ward
            hasUnhandledDeeplink = true

        default:
            print("[DeeplinkManager] 알 수 없는 deeplink: \(host ?? "nil")")
        }
    }

    /// Universal Link URL 처리 (https://1.sodam.store/)
    func handleUniversalLink(url: URL) {
        guard let host = url.host, host == Self.universalLinkHost else {
            print("[DeeplinkManager] Universal Link 도메인 불일치: \(url.host ?? "nil")")
            return
        }

        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        print("[DeeplinkManager] Universal Link - path: \(path)")
        print("[DeeplinkManager] queryItems: \(queryItems ?? [])")

        switch path {
        case "/invite":
            // https://1.sodam.store/invite?guardian_id=xxx
            // 어르신 초대 링크 - 자동으로 카카오 로그인까지 진행
            print("[DeeplinkManager] 🔗 어르신 초대 링크 수신")
            requestedUserType = .ward
            shouldAutoTriggerLogin = true  // 자동 로그인 트리거
            hasUnhandledDeeplink = true

        default:
            print("[DeeplinkManager] 알 수 없는 Universal Link path: \(path)")
        }
    }

    /// 딥링크 처리 완료
    func clearDeeplink() {
        requestedUserType = nil
        hasUnhandledDeeplink = false
        shouldAutoTriggerLogin = false
    }
}
