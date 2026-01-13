//
//  WardHomeView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 소담이 말풍선 메시지 목록
private enum SodamMessages {
    static let greetings: [String] = [
        "안녕하세요!",
        "오늘 하루도 좋은 하루 되세요!",
        "반가워요!",
        "오늘 기분은 어떠세요?",
        "좋은 아침이에요!",
        "좋은 하루 보내고 계신가요?",
    ]

    static let mealRelated: [String] = [
        "식사는 맛있게 하셨나요?",
        "오늘 뭐 드셨어요?",
        "맛있는 거 드셨나요?",
        "식사하셨어요?",
    ]

    static let healthRelated: [String] = [
        "오늘 건강은 어떠세요?",
        "몸은 괜찮으신가요?",
        "푹 주무셨어요?",
        "잠은 잘 주무셨나요?",
    ]

    static let activityRelated: [String] = [
        "오늘은 뭐 하셨어요?",
        "산책은 하셨나요?",
        "오늘 재미있는 일 있으셨어요?",
        "심심하지 않으셨어요?",
    ]

    static let caring: [String] = [
        "오늘도 함께해요!",
        "이야기 들려주세요!",
        "심심하면 저한테 말 걸어주세요!",
        "궁금한 거 있으면 물어보세요!",
        "오늘도 힘내세요!",
    ]

    /// 시간대에 따른 메시지 선택
    static func randomMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        let pool: [String]
        switch hour {
        case 6..<10:
            // 아침: 인사 + 건강
            pool = greetings + healthRelated
        case 10..<14:
            // 점심 전후: 식사 관련
            pool = mealRelated + greetings
        case 14..<18:
            // 오후: 활동 관련
            pool = activityRelated + caring
        case 18..<21:
            // 저녁: 식사 + 케어
            pool = mealRelated + caring
        default:
            // 밤/새벽: 일반 인사
            pool = greetings + caring
        }

        return pool.randomElement() ?? "안녕하세요!"
    }
}

/// 어르신 홈 화면
struct WardHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCallView = false
    @State private var currentMessage: String = SodamMessages.randomMessage()
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true
    @AppStorage("todayCallDuration") private var todayCallDuration: Int = 0  // 초 단위

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                Color.creamRice
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 상단 바 (프로필 + SOS)
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer()

                    // 말풍선
                    speechBubble
                        .padding(.bottom, 16)

                    // 캐릭터 이미지
                    characterImage
                        .padding(.bottom, 32)

                    // 통화 버튼
                    callButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    // 오늘 대화 시간
                    todayDurationBadge
                        .padding(.bottom, 40)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCallView) {
                LiveKitRoomView(
                    viewModel: DependencyContainer.shared.makeLiveKitViewModel(),
                    dismissOnCallEnd: true
                )
                .environmentObject(appState)
            }
            .onAppear {
                // 메시지 갱신
                currentMessage = SodamMessages.randomMessage()
                // 위치 추적 자동 시작
                if locationTrackingEnabled {
                    LocationService.shared.startTracking()
                }
            }
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack {
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
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            Spacer()

            // SOS 버튼
            EmergencyButton()
        }
    }

    // MARK: - 말풍선

    private var speechBubble: some View {
        VStack(spacing: 0) {
            Text(currentMessage)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.deepMoss)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.softSprout.opacity(0.6))
                )

            // 말풍선 꼬리
            Triangle()
                .fill(Color.softSprout.opacity(0.6))
                .frame(width: 16, height: 10)
                .rotationEffect(.degrees(180))
        }
    }

    // MARK: - 캐릭터 이미지

    private var characterImage: some View {
        Image("damso")
            .resizable()
            .scaledToFit()
            .frame(width: 260, height: 260)
            .clipShape(Circle())
            .background(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 15, y: 5)
            )
    }

    // MARK: - 통화 버튼

    private var callButton: some View {
        Button(action: {
            showCallView = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 20))
                Text("소담이와 담소하기")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.damsoGreen)
                    .shadow(color: Color.damsoGreen.opacity(0.3), radius: 8, y: 4)
            )
        }
    }

    // MARK: - 오늘 대화 시간 뱃지

    private var todayDurationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Text("오늘 대화 시간 : ")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Text("\(todayCallDuration / 60)분")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.deepMoss)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    WardHomeView()
        .environmentObject(AppState())
}
