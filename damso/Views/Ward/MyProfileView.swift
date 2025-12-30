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

    var body: some View {
        List {
            // 프로필 헤더
            profileHeaderSection

            // 기본 정보
            basicInfoSection

            // 연결된 보호자/기관
            linkedInfoSection
        }
        .navigationTitle("나의 정보")
        .navigationBarTitleDisplayMode(.inline)
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
                        .foregroundColor(.gray)
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())

                // 닉네임
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.nickname ?? "사용자")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(appState.currentUser?.userType?.displayName ?? "어르신")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 기본 정보

    private var basicInfoSection: some View {
        Section("기본 정보") {
            InfoRow(label: "이메일", value: appState.currentUser?.email ?? "-")
            InfoRow(label: "카카오 ID", value: appState.currentUser?.kakaoId ?? "-")

            if let wardInfo = appState.currentUser?.wardInfo {
                InfoRow(label: "전화번호", value: wardInfo.phoneNumber)
            }
        }
    }

    // MARK: - 연결된 보호자/기관

    private var linkedInfoSection: some View {
        Section("연결된 보호자") {
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
                            .foregroundColor(.gray)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(guardian.nickname)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("보호자")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else if let org = appState.currentUser?.wardInfo?.linkedOrganization {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(org.name)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("돌봄 기관")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundColor(.gray)

                    Text("연결된 보호자가 없습니다")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        MyProfileView()
            .environmentObject(AppState())
    }
}
