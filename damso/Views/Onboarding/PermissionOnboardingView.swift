//
//  PermissionOnboardingView.swift
//  damso
//
//  권한 요청 온보딩 화면
//

import SwiftUI
import AVFoundation
import UserNotifications
import CoreLocation
import UIKit

struct PermissionOnboardingView: View {
    let userType: UserType
    let onComplete: () -> Void

    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // 배경
            Color.creamRice
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 20)

                    // 말풍선
                    speechBubble

                    // 캐릭터 이미지
                    Image("damso")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        )

                    // 타이틀
                    VStack(spacing: 8) {
                        Text("원활한 담소를 위해")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.deepMoss)

                        Text("필수 권한이 필요해요")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.damsoGreen)
                    }
                    .padding(.top, 8)

                    // 권한 카드들
                    VStack(spacing: 12) {
                        permissionCard(
                            icon: "phone.fill",
                            title: "전화 수신·발신",
                            description: "AI 안부 전화와 긴급 연락에 사용돼요"
                        )

                        permissionCard(
                            icon: "mic.fill",
                            title: "마이크",
                            description: "어르신의 음성을 정확히 듣기 위해 필요해요"
                        )

                        permissionCard(
                            icon: "camera.fill",
                            title: "카메라",
                            description: "영상 통화 및 보호자 확인에 사용돼요"
                        )

                        permissionCard(
                            icon: "bell.fill",
                            title: "알림",
                            description: "통화 수신 및 중요 알림을 받기 위해 필요해요"
                        )

                        if userType == .ward {
                            permissionCard(
                                icon: "location.fill",
                                title: "위치 정보",
                                description: "위급 상황 시 빠른 도움을 드리기 위해 필요해요"
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // 안내 문구
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.damsoGreen)

                        Text("모든 권한은 서비스 제공 목적에만 사용돼요")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)

                    Spacer()
                        .frame(height: 100)
                }
            }

            // 하단 버튼
            VStack {
                Spacer()

                Button(action: {
                    viewModel.requestAllPermissions(userType: userType, completion: onComplete)
                }) {
                    HStack {
                        if viewModel.isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text("동의하고 시작하기")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.damsoGreen)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isRequesting)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .background(
                    LinearGradient(
                        colors: [.creamRice.opacity(0), .creamRice],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
    }

    // MARK: - Components

    private var speechBubble: some View {
        Text("몇 가지만 허용해주세요 😊")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.deepMoss)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.softSprout.opacity(0.6))
            )
            .overlay(
                // 말풍선 꼬리
                Triangle()
                    .fill(Color.softSprout.opacity(0.6))
                    .frame(width: 12, height: 8)
                    .offset(y: 4),
                alignment: .bottom
            )
    }

    private func permissionCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(Color.softSprout.opacity(0.4))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.damsoGreen)
            }

            // 텍스트
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.deepMoss)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview