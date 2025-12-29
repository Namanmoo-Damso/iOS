import Foundation
import Combine
import KakaoSDKUser
import KakaoSDKAuth

/// 카카오 사용자 정보
struct KakaoUserInfo {
    let id: Int64
    let nickname: String?
    let email: String?
    let profileImageUrl: URL?
}

/// 카카오 로그인 결과
struct KakaoLoginResult {
    let accessToken: String
    let refreshToken: String?
    let userInfo: KakaoUserInfo
}

/// 카카오 토큰 정보 (Sendable 준수)
struct KakaoTokenInfo: Sendable {
    let accessToken: String
    let refreshToken: String?
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

    /// 카카오 로그인 수행 (토큰 반환 버전)
    /// - Returns: 카카오 로그인 결과 (access token, user info)
    func login() async throws -> KakaoLoginResult {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let tokenInfo: KakaoTokenInfo
            if UserApi.isKakaoTalkLoginAvailable() {
                tokenInfo = try await loginWithKakaoTalk()
            } else {
                tokenInfo = try await loginWithKakaoAccount()
            }

            isLoggedIn = true
            let userInfo = try await fetchUserInfoAndReturn()
            currentUser = userInfo

            return KakaoLoginResult(
                accessToken: tokenInfo.accessToken,
                refreshToken: tokenInfo.refreshToken,
                userInfo: userInfo
            )
        } catch {
            debugLog("Login failed: \(error.localizedDescription)")
            errorMessage = "로그인에 실패했습니다: \(error.localizedDescription)"
            isLoggedIn = false
            throw error
        }
    }

    private func loginWithKakaoTalk() async throws -> KakaoTokenInfo {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<KakaoTokenInfo, Error>) in
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let oauthToken = oauthToken {
                    let tokenInfo = KakaoTokenInfo(
                        accessToken: oauthToken.accessToken,
                        refreshToken: oauthToken.refreshToken
                    )
                    continuation.resume(returning: tokenInfo)
                } else {
                    continuation.resume(throwing: NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token received"]))
                }
            }
        }
    }

    private func loginWithKakaoAccount() async throws -> KakaoTokenInfo {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<KakaoTokenInfo, Error>) in
            UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let oauthToken = oauthToken {
                    let tokenInfo = KakaoTokenInfo(
                        accessToken: oauthToken.accessToken,
                        refreshToken: oauthToken.refreshToken
                    )
                    continuation.resume(returning: tokenInfo)
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
        if let userInfo = try? await fetchUserInfoAndReturn() {
            currentUser = userInfo
        }
    }

    private func fetchUserInfoAndReturn() async throws -> KakaoUserInfo {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<KakaoUserInfo, Error>) in
            UserApi.shared.me { [weak self] user, error in
                Task { @MainActor in
                    if let error = error {
                        self?.debugLog("Failed to fetch user info: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let user = user {
                        let userInfo = KakaoUserInfo(
                            id: user.id ?? 0,
                            nickname: user.kakaoAccount?.profile?.nickname,
                            email: user.kakaoAccount?.email,
                            profileImageUrl: user.kakaoAccount?.profile?.profileImageUrl
                        )
                        self?.debugLog("User info fetched: \(userInfo.nickname ?? "Unknown")")

                        if let userId = user.id {
                            UserDefaults.standard.set(userId, forKey: self?.userKey ?? "")
                        }
                        continuation.resume(returning: userInfo)
                    } else {
                        continuation.resume(throwing: NSError(domain: "KakaoAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "User info not available"]))
                    }
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
