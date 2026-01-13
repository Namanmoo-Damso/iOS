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

    @AppStorage("callVolume") private var callVolume = 0.7
    @AppStorage("weeklyCallCount") private var weeklyCallCount = 3
    @AppStorage("callDuration") private var callDuration = 15
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true
    @AppStorage("fontSizeScale") private var fontSizeScale = 1.0  // 글씨 크기 배율 (0.8 ~ 1.5)

    @StateObject private var locationService = LocationService.shared

    @State private var showLogoutAlert = false
    @State private var showWithdrawAlert = false
    @State private var isWithdrawing = false
    @State private var withdrawError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                Color.creamRice
                    .ignoresSafeArea()

                List {
                    // 화면 설정 (글씨 크기)
                    displaySettingsSection

                    // 통화 설정
                    callSettingsSection

                    // 위치 설정
                    locationSection

                    // 나의 정보
                    myInfoSection

                    // 계정 관리
                    accountSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.creamRice, for: .navigationBar)
        }
        .tint(.damsoGreen)
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

    // MARK: - 스케일 적용 폰트 크기

    private var scaledBodySize: CGFloat { 17 * fontSizeScale }
    private var scaledCaptionSize: CGFloat { 13 * fontSizeScale }
    private var scaledSubheadSize: CGFloat { 15 * fontSizeScale }

    // MARK: - 화면 설정 섹션

    private var displaySettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("글씨 크기", systemImage: "textformat.size")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.deepMoss)
                    Spacer()
                    Text(fontSizeLabel)
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.gray)
                }

                HStack(spacing: 16) {
                    Text("가")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Slider(value: $fontSizeScale, in: 0.8...1.5, step: 0.1)
                        .tint(.damsoGreen)

                    Text("가")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.gray)
                }

                // 미리보기
                Text("미리보기 텍스트입니다")
                    .font(.system(size: 18 * fontSizeScale, weight: .medium))
                    .foregroundColor(.deepMoss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.softSprout.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding(.vertical, 4)
        } header: {
            Text("화면 설정")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        } footer: {
            Text("글씨 크기를 조절하면 앱 전체에 바로 적용됩니다.")
                .font(.system(size: scaledCaptionSize))
                .foregroundColor(.gray)
        }
        .listRowBackground(Color.white)
    }

    private var fontSizeLabel: String {
        "\(Int(fontSizeScale * 100))%"
    }

    // MARK: - 통화 설정 섹션

    private var callSettingsSection: some View {
        Section {
            // 통화 음량
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("통화 음량", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.deepMoss)
                    Spacer()
                    Text("\(Int(callVolume * 100))%")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.gray)
                }

                Slider(value: $callVolume, in: 0...1)
                    .tint(.damsoGreen)
            }
            .padding(.vertical, 4)

            // 주간 통화 횟수
            HStack {
                Label("주간 통화 횟수", systemImage: "calendar")
                    .font(.system(size: scaledBodySize))
                    .foregroundColor(.deepMoss)
                Spacer()
                Picker("", selection: $weeklyCallCount) {
                    ForEach(1...7, id: \.self) { count in
                        Text("\(count)회").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .tint(.damsoGreen)
            }

            // 1회 통화 시간
            HStack {
                Label("1회 통화 시간", systemImage: "clock")
                    .font(.system(size: scaledBodySize))
                    .foregroundColor(.deepMoss)
                Spacer()
                Picker("", selection: $callDuration) {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { duration in
                        Text("\(duration)분").tag(duration)
                    }
                }
                .pickerStyle(.menu)
                .tint(.damsoGreen)
            }
        } header: {
            Text("통화 설정")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        }
        .listRowBackground(Color.white)
    }

    // MARK: - 위치 설정 섹션

    private var locationSection: some View {
        Section {
            Toggle(isOn: $locationTrackingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("위치 공유", systemImage: "location.fill")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.deepMoss)

                    Text("보호자에게 현재 위치를 공유합니다")
                        .font(.system(size: scaledCaptionSize))
                        .foregroundColor(.gray)
                }
            }
            .tint(.damsoGreen)
            .onChange(of: locationTrackingEnabled) { _, newValue in
                if newValue {
                    locationService.startTracking()
                } else {
                    locationService.stopTracking()
                }
            }

            // 위치 권한 상태 표시
            HStack {
                Label("위치 권한", systemImage: "shield.checkered")
                    .font(.system(size: scaledBodySize))
                    .foregroundColor(.deepMoss)
                Spacer()
                locationAuthStatusText
            }
        } header: {
            Text("위치 설정")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        } footer: {
            Text("위치 정보는 보호자에게만 공유되며, 안전을 위해 사용됩니다.")
                .font(.system(size: scaledCaptionSize))
                .foregroundColor(.gray)
        }
        .listRowBackground(Color.white)
    }

    private var locationAuthStatusText: some View {
        Group {
            switch locationService.authorizationStatus {
            case .authorizedAlways:
                Text("항상 허용")
                    .foregroundColor(.damsoSafe)
            case .authorizedWhenInUse:
                Text("앱 사용 중 허용")
                    .foregroundColor(.damsoWarning)
            case .denied, .restricted:
                Text("거부됨")
                    .foregroundColor(.damsoDanger)
            case .notDetermined:
                Text("설정 필요")
                    .foregroundColor(.gray)
            @unknown default:
                Text("알 수 없음")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: scaledSubheadSize, weight: .medium))
    }

    // MARK: - 나의 정보 섹션

    private var myInfoSection: some View {
        Section {
            NavigationLink {
                MyProfileView()
                    .environmentObject(appState)
            } label: {
                HStack {
                    Label("나의 정보", systemImage: "person.fill")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.deepMoss)
                    Spacer()

                    if let user = appState.currentUser {
                        Text(user.nickname ?? "")
                            .font(.system(size: scaledBodySize))
                            .foregroundColor(.gray)
                    }
                }
            }
        } header: {
            Text("프로필")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        }
        .listRowBackground(Color.white)
    }

    // MARK: - 계정 관리 섹션

    private var accountSection: some View {
        Section {
            Button {
                showLogoutAlert = true
            } label: {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: scaledBodySize))
                    .foregroundColor(.damsoWarning)
            }

            Button {
                showWithdrawAlert = true
            } label: {
                Label("회원탈퇴", systemImage: "person.badge.minus")
                    .font(.system(size: scaledBodySize))
                    .foregroundColor(.damsoDanger)
            }
        } header: {
            Text("계정")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        }
        .listRowBackground(Color.white)
    }
}

#Preview {
    WardSettingsView()
        .environmentObject(AppState())
}
