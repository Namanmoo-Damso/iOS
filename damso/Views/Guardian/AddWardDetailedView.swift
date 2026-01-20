//
//  AddWardDetailedView.swift
//  damso
//
//  기존 보호자가 추가 어르신을 등록하는 화면
//  GuardianRegistrationView를 재사용
//

import SwiftUI

/// 어르신 추가 화면 (GuardianRegistrationView 래퍼)
struct AddWardDetailedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GuardianRegistrationView(
            kakaoUserInfo: KakaoUserInfo(
                id: 0,
                nickname: nil,
                email: nil,
                profileImageUrl: nil
            ),
            onRegistrationComplete: { _, _ in
                // 등록 완료 후 사용자 정보 새로고침
                Task {
                    await appState.checkAuthStatus()
                }
                dismiss()
            },
            onBack: {
                dismiss()
            },
            isAddingWard: true
        )
        .environmentObject(appState)
    }
}