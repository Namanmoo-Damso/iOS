//
//  UserTypeSelectionView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 사용자 타입(보호자/어르신) 선택 화면
struct UserTypeSelectionView: View {
    @ObservedObject private var kakaoAuth = KakaoAuthService.shared

    @State private var selectedType: UserType?
    @State private var isAnimating = false
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    /// 카카오 로그인 성공 콜백 (userType, loginResult)
    let onLoginSuccess: (UserType, KakaoLoginResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 헤더
            VStack(spacing: 12) {
                Image("damso")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text(Strings.Auth.welcomeTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(Strings.Auth.selectUserTypeMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)

            // 타입 선택 버튼
            HStack(spacing: 16) {
                UserTypeButton(
                    type: .guardian,
                    title: Strings.UserType.guardian,
                    icon: "person.badge.shield.checkmark",
                    subtitle: Strings.UserType.guardianDescription,
                    isSelected: selectedType == .guardian
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedType = .guardian
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)

                UserTypeButton(
                    type: .ward,
                    title: Strings.UserType.ward,
                    icon: "person.fill",
                    subtitle: Strings.UserType.wardDescription,
                    isSelected: selectedType == .ward
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedType = .ward
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
            }
            .padding(.horizontal, 24)

            Spacer()

            // 에러 메시지
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // 카카오 로그인 버튼
            Button(action: performKakaoLogin) {
                HStack(spacing: 12) {
                    if isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "message.fill")
                            .font(.title3)
                        Text(Strings.Auth.loginWithKakao)
                            .font(.headline)
                    }
                }
                .foregroundColor(selectedType != nil ? .black : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedType != nil
                            ? Color(red: 254/255, green: 229/255, blue: 0/255)
                            : Color(.systemGray5))
                )
            }
            .disabled(selectedType == nil || isLoggingIn)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn.delay(0.3), value: isAnimating)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isAnimating = true
        }
    }

    private func performKakaoLogin() {
        guard let type = selectedType else { return }

        isLoggingIn = true
        errorMessage = nil

        Task {
            do {
                let result = try await kakaoAuth.login()
                onLoginSuccess(type, result)
            } catch {
                errorMessage = Strings.Auth.loginFailed
            }
            isLoggingIn = false
        }
    }
}

#Preview {
    UserTypeSelectionView { type, result in
        print("Selected: \(type.displayName), User: \(result.userInfo.nickname ?? "unknown")")
    }
}
