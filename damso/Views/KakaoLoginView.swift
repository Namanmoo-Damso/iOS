import SwiftUI

struct KakaoLoginView: View {
    @ObservedObject var kakaoAuth = KakaoAuthService.shared
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo area
            VStack(spacing: 16) {
                Image(systemName: "video.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("damso")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("영상통화 서비스")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                        Task {
                            do {
                                let _ = try await kakaoAuth.login()
                                // 로그인 성공 - isLoggedIn이 자동으로 true로 변경됨
                            } catch {
                                // 에러는 kakaoAuth.errorMessage에 이미 저장됨
                            }
                        }
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
        .onChange(of: kakaoAuth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                isLoggedIn = true
            }
        }
        .onAppear {
            // Already logged in
            if kakaoAuth.isLoggedIn {
                isLoggedIn = true
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
    KakaoLoginView(isLoggedIn: .constant(false))
}
