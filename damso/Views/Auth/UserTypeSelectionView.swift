//
//  UserTypeSelectionView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 사용자 타입(보호자/어르신) 선택 화면
struct UserTypeSelectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = UserTypeSelectionViewModel()
    
    @State private var isAnimating = false
    
    /// 카카오 로그인 성공 콜백 (userType, loginResult)
    let onLoginSuccess: (UserType, KakaoLoginResult) -> Void
    
    var body: some View {
        ZStack {
            // 배경
            Color.creamRice
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)
                
                // DAMSO 로고 텍스트
                Text("DAMSO")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.damsoGreen)
                    .tracking(2)
                    .padding(.bottom, 16)
                
                // 캐릭터 + 말풍선
                ZStack(alignment: .topTrailing) {
                    Image("damso")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        )
                    
                    // 말풍선
                    Text("안녕하세요!")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.deepMoss)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.softSprout.opacity(0.7))
                        )
                        .offset(x: 24, y: 12)
                }
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5), value: isAnimating)
                .padding(.bottom, 28)
                
                // 타이틀
                VStack(spacing: 6) {
                    Text("매일매일")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.deepMoss)
                    
                    Text("즐거운 담소")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.damsoGreen)
                }
                .padding(.bottom, 36)
                
                // 타입 선택 카드
                HStack(spacing: 12) {
                    TypeSelectionCard(
                        icon: "person.fill",
                        title: Strings.UserType.ward,
                        isSelected: viewModel.selectedType == .ward
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectType(.ward)
                        }
                    }
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
                    
                    TypeSelectionCard(
                        icon: "checkmark.shield.fill",
                        title: Strings.UserType.guardian,
                        isSelected: viewModel.selectedType == .guardian
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectType(.guardian)
                        }
                    }
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // 에러 메시지
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.damsoDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
                
                // 안내 문구
                if let type = viewModel.selectedType {
                    Text(type == .guardian
                         ? "보호자님, 카카오로 간편하게 시작하세요."
                         : "어르신, 카카오로 간편하게 시작하세요.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
                
                // 카카오 로그인 버튼
                Button(action: { viewModel.performKakaoLogin() }) {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "message.fill")
                                .font(.system(size: 18))
                            Text("카카오톡으로 시작하기")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(viewModel.selectedType != nil ? .black.opacity(0.85) : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedType != nil
                                  ? Color(red: 254/255, green: 229/255, blue: 0/255)
                                  : Color(.systemGray5))
                    )
                }
                .disabled(viewModel.selectedType == nil || viewModel.isLoading)
                .padding(.horizontal, 24)
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeIn.delay(0.3), value: isAnimating)
                
                // 보호자 테스트 버튼 (dev API 사용)
                Button {
                    Task { @MainActor in
                        viewModel.performDevLogin(appState: appState)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isDevLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        } else {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14))
                            Text("보호자 테스트 (더미 데이터)")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.1))
                            )
                    )
                }
                .disabled(viewModel.isDevLoggingIn)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onReceive(viewModel.loginSuccessSubject) { (type, result) in
            onLoginSuccess(type, result)
        }
        .fullScreenCover(isPresented: $viewModel.showDevGuardianRegistration) {
            GuardianRegistrationView(
                kakaoUserInfo: KakaoUserInfo(
                    id: 9999999,
                    nickname: "테스트보호자",
                    email: "test@guardian.dev",
                    profileImageUrl: nil
                ),
                onRegistrationComplete: { _, _ in
                    viewModel.showDevGuardianRegistration = false
                },
                onBack: {
                    viewModel.showDevGuardianRegistration = false
                },
                useDummyData: true
            )
            .environmentObject(appState)
        }
    }
}

// MARK: - Type Selection Card

private struct TypeSelectionCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.softSprout.opacity(0.5) : Color.gray.opacity(0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .damsoGreen : .gray)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSelected ? .deepMoss : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.damsoGreen : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}