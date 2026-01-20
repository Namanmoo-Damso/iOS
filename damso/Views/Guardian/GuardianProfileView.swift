//
//  GuardianProfileView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 나의 정보 화면
struct GuardianProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            // 프로필 헤더
            profileHeaderSection

            // 기본 정보
            basicInfoSection

            // 연결된 어르신
            linkedWardSection
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
                    Text(appState.currentUser?.nickname ?? "보호자")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(appState.currentUser?.userType?.displayName ?? "보호자")
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
        }
    }

    // MARK: - 연결된 어르신

    private var linkedWardSection: some View {
        Section("연결된 어르신") {
            if let guardianInfo = appState.currentUser?.guardianInfo {
                if let linkedWard = guardianInfo.linkedWard {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(linkedWard.nickname)
                                .font(.body)
                                .fontWeight(.medium)

                            Text("연결됨")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Image(systemName: "person.badge.clock")
                            .font(.title3)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(guardianInfo.wardEmail)
                                .font(.body)

                            Text("연결 대기 중")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundColor(.gray)

                    Text("등록된 어르신이 없습니다")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}