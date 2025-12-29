import Foundation
import Combine
import KakaoSDKUser
import KakaoSDKAuth

struct KakaoUserInfo {
    let id: Int64
    let nickname: String?
    let email: String?
    let profileImageUrl: URL?
}

@MainActor
final class KakaoAuthService: ObservableObject {
    static let shared = KakaoAuthService()

    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var currentUser: KakaoUserInfo?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let userKey = "kakao_user_id"

    private init() {
        checkLoginStatus()
    }

    // MARK: - Login Status Check

    func checkLoginStatus() {
        if AuthApi.hasToken() {
            UserApi.shared.accessTokenInfo { [weak self] _, error in
                Task { @MainActor in
                    if let error = error {
                        self?.debugLog("Token invalid: \(error.localizedDescription)")
                        self?.isLoggedIn = false
                        self?.currentUser = nil
                    } else {
                        self?.debugLog("Token valid")
                        self?.isLoggedIn = true
                        await self?.fetchUserInfo()
                    }
                }
            }
        } else {
            isLoggedIn = false
            currentUser = nil
        }
    }

    // MARK: - Login

    func login() async {
        isLoading = true
        errorMessage = nil

        do {
            if UserApi.isKakaoTalkLoginAvailable() {
                try await loginWithKakaoTalk()
            } else {
                try await loginWithKakaoAccount()
            }
            isLoggedIn = true
            await fetchUserInfo()
        } catch {
            debugLog("Login failed: \(error.localizedDescription)")
            errorMessage = "로그인에 실패했습니다: \(error.localizedDescription)"
            isLoggedIn = false
        }

        isLoading = false
    }

    private func loginWithKakaoTalk() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if oauthToken != nil {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token received"]))
                }
            }
        }
    }

    private func loginWithKakaoAccount() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if oauthToken != nil {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token received"]))
                }
            }
        }
    }

    // MARK: - Logout

    func logout() async {
        isLoading = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UserApi.shared.logout { [weak self] error in
                Task { @MainActor in
                    if let error = error {
                        self?.debugLog("Logout error: \(error.localizedDescription)")
                    }
                    self?.isLoggedIn = false
                    self?.currentUser = nil
                    UserDefaults.standard.removeObject(forKey: self?.userKey ?? "")
                    continuation.resume(returning: ())
                }
            }
        }

        isLoading = false
    }

    // MARK: - Unlink (회원탈퇴)

    func unlink() async {
        isLoading = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UserApi.shared.unlink { [weak self] error in
                Task { @MainActor in
                    if let error = error {
                        self?.debugLog("Unlink error: \(error.localizedDescription)")
                        self?.errorMessage = "연결 해제에 실패했습니다"
                    }
                    self?.isLoggedIn = false
                    self?.currentUser = nil
                    UserDefaults.standard.removeObject(forKey: self?.userKey ?? "")
                    continuation.resume(returning: ())
                }
            }
        }

        isLoading = false
    }

    // MARK: - Fetch User Info

    private func fetchUserInfo() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UserApi.shared.me { [weak self] user, error in
                Task { @MainActor in
                    if let error = error {
                        self?.debugLog("Failed to fetch user info: \(error.localizedDescription)")
                    } else if let user = user {
                        let userInfo = KakaoUserInfo(
                            id: user.id ?? 0,
                            nickname: user.kakaoAccount?.profile?.nickname,
                            email: user.kakaoAccount?.email,
                            profileImageUrl: user.kakaoAccount?.profile?.profileImageUrl
                        )
                        self?.currentUser = userInfo
                        self?.debugLog("User info fetched: \(userInfo.nickname ?? "Unknown")")

                        if let userId = user.id {
                            UserDefaults.standard.set(userId, forKey: self?.userKey ?? "")
                        }
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[KakaoAuthService] \(message)")
        #endif
    }
}
