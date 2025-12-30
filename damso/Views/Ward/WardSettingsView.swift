//
//  WardSettingsView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI
import CoreLocation

/// 어르신 설정 화면
struct WardSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("aiPersona") private var aiPersonaRaw = AIPersona.dami.rawValue
    @AppStorage("callVolume") private var callVolume = 0.7
    @AppStorage("weeklyCallCount") private var weeklyCallCount = 3
    @AppStorage("callDuration") private var callDuration = 15
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true

    @StateObject private var locationService = LocationService.shared

    @State private var showLogoutAlert = false
    @State private var showWithdrawAlert = false
    @State private var isWithdrawing = false
    @State private var withdrawError: String?

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

                // 위치 설정
                locationSection

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

    // MARK: - 위치 설정 섹션

    private var locationSection: some View {
        Section {
            Toggle(isOn: $locationTrackingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("위치 공유")
                        .font(.body)

                    Text("보호자에게 현재 위치를 공유합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: locationTrackingEnabled) { _, newValue in
                if newValue {
                    locationService.startTracking()
                } else {
                    locationService.stopTracking()
                }
            }

            // 위치 권한 상태 표시
            HStack {
                Text("위치 권한")
                Spacer()
                locationAuthStatusText
            }
        } header: {
            Text("위치 설정")
        } footer: {
            Text("위치 정보는 보호자에게만 공유되며, 안전을 위해 사용됩니다.")
        }
    }

    private var locationAuthStatusText: some View {
        Group {
            switch locationService.authorizationStatus {
            case .authorizedAlways:
                Text("항상 허용")
                    .foregroundColor(.green)
            case .authorizedWhenInUse:
                Text("앱 사용 중 허용")
                    .foregroundColor(.orange)
            case .denied, .restricted:
                Text("거부됨")
                    .foregroundColor(.red)
            case .notDetermined:
                Text("설정 필요")
                    .foregroundColor(.secondary)
            @unknown default:
                Text("알 수 없음")
                    .foregroundColor(.secondary)
            }
        }
        .font(.subheadline)
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
                        Text(user.nickname ?? "")
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
