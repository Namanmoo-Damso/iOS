import SwiftUI

struct KakaoLoginView: View {
    @ObservedObject var kakaoAuth = KakaoAuthService.shared
    let onLoginSuccess: (KakaoLoginResult) -> Void

    /// Universal Link에서 진입 시 자동으로 카카오 로그인 트리거
    var autoTriggerLogin: Bool = false

    @State private var hasCalledLoginSuccess = false
    @State private var hasTriggeredAutoLogin = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo area
            VStack(spacing: 12) {
                // damso 이미지 사용 (Assets.xcassets/damso.imageset)
                Image("damso")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("소중한 사람과의 대화")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            // Login section
            VStack(spacing: 20) {
                if kakaoAuth.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    // Kakao login button
                    Button(action: {
                        print("[KakaoLoginView] 🔵 로그인 버튼 클릭")
                        triggerKakaoLogin()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.title3)
                            Text("카카오로 시작하기")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 254/255, green: 229/255, blue: 0/255))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }

                if let error = kakaoAuth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()
                .frame(height: 60)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Universal Link로 진입 시 자동 로그인 트리거
            if autoTriggerLogin && !hasTriggeredAutoLogin && !kakaoAuth.isLoading {
                hasTriggeredAutoLogin = true
                print("[KakaoLoginView] 🔗 Universal Link - 자동 로그인 트리거")
                triggerKakaoLogin()
            }
        }
    }

    /// 카카오 로그인 실행
    private func triggerKakaoLogin() {
        guard !hasCalledLoginSuccess else {
            print("[KakaoLoginView] 🚫 이미 로그인 처리 중 - 중복 호출 무시")
            return
        }

        Task {
            do {
                print("[KakaoLoginView] 🔵 kakaoAuth.login() 호출 시작")
                let result = try await kakaoAuth.login()
                print("[KakaoLoginView] ✅ 카카오 로그인 성공: \(result.userInfo.nickname ?? "unknown")")

                guard !hasCalledLoginSuccess else {
                    print("[KakaoLoginView] 🚫 이미 onLoginSuccess 호출됨 - 스킵")
                    return
                }
                hasCalledLoginSuccess = true
                print("[KakaoLoginView] 🔵 onLoginSuccess 콜백 호출")
                onLoginSuccess(result)
            } catch {
                print("[KakaoLoginView] ❌ 카카오 로그인 실패: \(error)")
            }
        }
    }
}

// MARK: - User Profile Header (for logged in state)
struct UserProfileHeader: View {
    let user: KakaoUserInfo
    let onLogout: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let imageUrl = user.profileImageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.nickname ?? "사용자")
                    .font(.headline)
                if let email = user.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onLogout) {
                Text("로그아웃")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    KakaoLoginView { _ in }
}
