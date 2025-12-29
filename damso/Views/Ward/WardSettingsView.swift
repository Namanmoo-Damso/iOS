//
//  WardSettingsView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 설정 화면
struct WardSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("aiPersona") private var aiPersonaRaw = AIPersona.dami.rawValue
    @AppStorage("callVolume") private var callVolume = 0.7
    @AppStorage("weeklyCallCount") private var weeklyCallCount = 3
    @AppStorage("callDuration") private var callDuration = 15

    @State private var showLogoutAlert = false
    @State private var showWithdrawAlert = false

    private var aiPersona: AIPersona {
        AIPersona(rawValue: aiPersonaRaw) ?? .dami
    }

    var body: some View {
        NavigationStack {
            List {
                // AI 친구 선택
                aiPersonaSection

                // 통화 설정
                callSettingsSection

                // 나의 정보
                myInfoSection

                // 계정 관리
                accountSection
            }
            .navigationTitle("설정")
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
                // TODO: 회원탈퇴 API 호출
            }
        } message: {
            Text("정말 탈퇴 하시겠습니까?\n모든 데이터가 삭제됩니다.")
        }
    }

    // MARK: - AI 친구 선택 섹션

    private var aiPersonaSection: some View {
        Section("AI 친구 선택") {
            ForEach(AIPersona.allCases) { persona in
                Button {
                    aiPersonaRaw = persona.rawValue
                } label: {
                    HStack {
                        Text(persona.emoji)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(persona.displayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(persona.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if aiPersona == persona {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 통화 설정 섹션

    private var callSettingsSection: some View {
        Section("통화 설정") {
            // 통화 음량
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("통화 음량")
                    Spacer()
                    Text("\(Int(callVolume * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(value: $callVolume, in: 0...1)
                    .tint(.blue)
            }
            .padding(.vertical, 4)

            // 주간 통화 횟수
            Picker("주간 통화 횟수", selection: $weeklyCallCount) {
                ForEach(1...7, id: \.self) { count in
                    Text("\(count)회").tag(count)
                }
            }

            // 1회 통화 시간
            Picker("1회 통화 시간", selection: $callDuration) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { duration in
                    Text("\(duration)분").tag(duration)
                }
            }
        }
    }

    // MARK: - 나의 정보 섹션

    private var myInfoSection: some View {
        Section {
            NavigationLink {
                MyProfileView()
                    .environmentObject(appState)
            } label: {
                HStack {
                    Text("나의 정보")
                    Spacer()

                    if let user = appState.currentUser {
                        Text(user.nickname)
                            .foregroundColor(.secondary)
                    }
                }
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

#Preview {
    WardSettingsView()
        .environmentObject(AppState())
}
