//
//  MyProfileView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 나의 정보 화면
struct MyProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false
    @AppStorage("fontSizeScale") private var fontSizeScale = 1.0

    // MARK: - 스케일 적용 폰트 크기

    private var scaledBodySize: CGFloat { 17 * fontSizeScale }
    private var scaledCaptionSize: CGFloat { 13 * fontSizeScale }
    private var scaledTitleSize: CGFloat { 22 * fontSizeScale }
    private var scaledSubheadSize: CGFloat { 15 * fontSizeScale }

    var body: some View {
        ZStack {
            Color.creamRice
                .ignoresSafeArea()

            List {
                // 프로필 헤더
                profileHeaderSection

                // 기본 정보
                basicInfoSection

                // 연결된 보호자/기관
                linkedInfoSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("나의 정보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.creamRice, for: .navigationBar)
        .tint(.damsoGreen)
        .refreshable {
            await refreshUserInfo()
        }
        .task {
            // 화면 진입 시 자동 새로고침
            await refreshUserInfo()
        }
    }

    private func refreshUserInfo() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await appState.refreshCurrentUser()
        } catch {
            print("[MyProfileView] Failed to refresh user info: \(error)")
        }
    }

    // MARK: - 프로필 헤더

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                // 프로필 이미지
                AsyncImage(url: URL(string: appState.currentUser?.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                // 닉네임
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.nickname ?? "사용자")
                        .font(.system(size: scaledTitleSize, weight: .semibold))
                        .foregroundColor(.deepMoss)

                    Text(appState.currentUser?.userType?.displayName ?? "어르신")
                        .font(.system(size: scaledSubheadSize))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.white)
    }

    // MARK: - 기본 정보

    private var basicInfoSection: some View {
        Section {
            InfoRow(label: "이메일", value: appState.currentUser?.email ?? "-", fontSize: scaledBodySize)

            if let wardInfo = appState.currentUser?.wardInfo {
                InfoRow(label: "전화번호", value: wardInfo.phoneNumber.isEmpty ? "-" : wardInfo.phoneNumber, fontSize: scaledBodySize)
            } else {
                InfoRow(label: "전화번호", value: "-", fontSize: scaledBodySize)
            }
        } header: {
            Text("기본 정보")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        }
        .listRowBackground(Color.white)
    }

    // MARK: - 연결된 보호자/기관

    private var linkedInfoSection: some View {
        Section {
            if let guardian = appState.currentUser?.wardInfo?.linkedGuardian {
                HStack {
                    // 보호자 프로필
                    AsyncImage(url: URL(string: guardian.profileImageUrl ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(guardian.nickname)
                            .font(.system(size: scaledBodySize, weight: .medium))
                            .foregroundColor(.deepMoss)

                        Text("보호자")
                            .font(.system(size: scaledCaptionSize))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.damsoSafe)
                }
            } else if let org = appState.currentUser?.wardInfo?.linkedOrganization {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: scaledTitleSize))
                        .foregroundColor(.damsoGreen)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(org.name)
                            .font(.system(size: scaledBodySize, weight: .medium))
                            .foregroundColor(.deepMoss)

                        Text("돌봄 기관")
                            .font(.system(size: scaledCaptionSize))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.damsoSafe)
                }
            } else {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.gray)

                    Text("연결된 보호자가 없습니다")
                        .font(.system(size: scaledBodySize))
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("연결된 보호자")
                .font(.system(size: scaledCaptionSize, weight: .semibold))
                .foregroundColor(.damsoGreen)
        }
        .listRowBackground(Color.white)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var fontSize: CGFloat = 17

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fontSize))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: fontSize))
                .foregroundColor(.deepMoss)
        }
    }
}