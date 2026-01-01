//
//  InviteCompletionView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 가입 완료 후 초대 화면
struct InviteCompletionView: View {
    /// 보호자 정보
    let guardianId: String
    let guardianName: String
    let wardEmail: String

    /// 완료 콜백 (메인 화면으로 이동)
    let onComplete: () -> Void

    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var showSuccessAnimation = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 성공 아이콘
            successIcon

            // 메시지
            messageSection

            Spacer()

            // 버튼 영역
            buttonSection

            Spacer()
                .frame(height: 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSuccessAnimation = true
            }
        }
    }

    // MARK: - View Components

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 120, height: 120)

            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 90, height: 90)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
        }
        .scaleEffect(showSuccessAnimation ? 1 : 0.5)
        .opacity(showSuccessAnimation ? 1 : 0)
    }

    private var messageSection: some View {
        VStack(spacing: 12) {
            Text("가입이 완료되었습니다!")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("어르신에게 앱 초대 링크를\n보내주세요.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .opacity(showSuccessAnimation ? 1 : 0)
        .offset(y: showSuccessAnimation ? 0 : 20)
    }

    private var buttonSection: some View {
        VStack(spacing: 16) {
            // 에러 메시지
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // 카카오톡으로 초대하기 버튼
            Button(action: shareViaKakao) {
                HStack(spacing: 12) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "message.fill")
                            .font(.title3)
                    }
                    Text("카카오톡으로 초대하기")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 254/255, green: 229/255, blue: 0/255)) // 카카오 노란색
                )
            }
            .disabled(isSharing)

            // 나중에 하기 버튼
            Button(action: onComplete) {
                Text("나중에 하기")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .opacity(showSuccessAnimation ? 1 : 0)
        .offset(y: showSuccessAnimation ? 0 : 20)
    }

    // MARK: - Actions

    private func shareViaKakao() {
        isSharing = true
        errorMessage = nil

        Task {
            do {
                try await KakaoLinkService.shared.shareInviteLink(
                    guardianId: guardianId,
                    guardianName: guardianName,
                    wardEmail: wardEmail
                )
                // 공유 성공 - 메인 화면으로 이동하지 않고 사용자가 선택하도록 함
            } catch {
                errorMessage = error.localizedDescription
            }
            isSharing = false
        }
    }
}

#Preview {
    InviteCompletionView(
        guardianId: "guardian-123",
        guardianName: "홍길동",
        wardEmail: "elder@email.com",
        onComplete: { print("Complete") }
    )
}
