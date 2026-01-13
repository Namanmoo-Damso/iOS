//
//  GuardianSettingsView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 설정 화면
struct GuardianSettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var showAddWard = false
    @State private var showLogoutAlert = false
    @State private var showWithdrawAlert = false
    @State private var showUnlinkAlert = false
    @State private var isWithdrawing = false
    @State private var withdrawError: String?
    @State private var showScheduleSheet = false

    var body: some View {
        NavigationStack {
            List {
                // 내 어르신 정보
                wardInfoSection

                // 설정 메뉴
                settingsSection

                // 계정 관리
                accountSection
            }
            .navigationTitle("설정")
            .tint(.damsoGreen)
            .sheet(isPresented: $showAddWard) {
                AddWardDetailedView()
                    .environmentObject(appState)
            }
        }
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                Task {
                    await appState.logout()
                }
            }
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
        .alert("회원탈퇴", isPresented: $showWithdrawAlert) {
            Button("취소", role: .cancel) {}
            Button("탈퇴", role: .destructive) {
                Task {
                    isWithdrawing = true
                    do {
                        try await appState.withdraw()
                    } catch {
                        withdrawError = "탈퇴에 실패했습니다. 다시 시도해주세요."
                    }
                    isWithdrawing = false
                }
            }
        } message: {
            Text("정말 탈퇴 하시겠습니까?\n모든 데이터가 삭제됩니다.")
        }
        .alert("오류", isPresented: .init(
            get: { withdrawError != nil },
            set: { if !$0 { withdrawError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(withdrawError ?? "")
        }
        .overlay {
            if isWithdrawing {
                ProgressView("탈퇴 처리 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("연결 해제", isPresented: $showUnlinkAlert) {
            Button("취소", role: .cancel) {}
            Button("연결 해제", role: .destructive) {
                // TODO: 연결 해제 API 호출
            }
        } message: {
            Text("정말 어르신과의 연결을 해제하시겠습니까?")
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleManagementView()
        }
    }

    // MARK: - 내 어르신 정보 섹션

    private var wardInfoSection: some View {
        Section("내 어르신 정보") {
            if let guardianInfo = appState.currentUser?.guardianInfo {
                // 등록된 어르신 목록
                ForEach(guardianInfo.wards) { ward in
                    WardInfoCard(
                        nickname: ward.wardNickname,
                        email: ward.wardEmail,
                        phoneNumber: ward.wardPhoneNumber,
                        isLinked: ward.isLinked,
                        onUnlink: {
                            showUnlinkAlert = true
                        }
                    )
                }

                // 어르신 추가 버튼
                Button {
                    showAddWard = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.damsoGreen)

                        Text("어르신 추가하기")
                            .foregroundColor(.damsoGreen)
                    }
                }
            } else {
                // 어르신 등록 안 됨
                Button {
                    showAddWard = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.damsoGreen)

                        Text("어르신 추가하기")
                            .foregroundColor(.damsoGreen)
                    }
                }
            }
        }
    }

    // MARK: - 설정 메뉴 섹션

    private var settingsSection: some View {
        Section {
            // AI 안부 전화 스케줄 관리
            Button {
                showScheduleSheet = true
            } label: {
                HStack {
                    Label("AI 안부 전화 스케줄", systemImage: "clock.badge")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("알림 설정", systemImage: "bell")
            }

            NavigationLink {
                GuardianProfileView()
                    .environmentObject(appState)
            } label: {
                Label("나의 정보", systemImage: "person")
            }
        }
    }

    // MARK: - 계정 관리 섹션

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutAlert = true
            } label: {
                Text("로그아웃")
            }

            Button(role: .destructive) {
                showWithdrawAlert = true
            } label: {
                Text("회원탈퇴")
            }
        }
    }
}

// MARK: - Ward Info Card

struct WardInfoCard: View {
    let nickname: String?
    let email: String
    let phoneNumber: String
    let isLinked: Bool
    let onUnlink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 4) {
                    if let nickname = nickname {
                        Text(nickname)
                            .font(.headline)
                    } else {
                        Text("연결 대기 중")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }

                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLinked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.damsoGreen)
                } else {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.damsoWarning)
                }
            }

            HStack {
                Spacer()

                Button("연결 해제", role: .destructive) {
                    onUnlink()
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    GuardianSettingsView()
        .environmentObject(AppState())
}
