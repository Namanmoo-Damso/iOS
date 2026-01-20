//
//  WardTabView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 메인 탭 뷰
struct WardTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var callViewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @State private var selectedTab = 0
    @State private var showCallView = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 탭 1: 홈
            WardHomeTabContent(showCallView: $showCallView)
                .environmentObject(appState)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            // 탭 2: 설정
            WardSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tint(.damsoGreen)
        .tabViewStyle(.tabBarOnly)  // iPad에서도 하단 탭바 강제
        .fullScreenCover(isPresented: $showCallView) {
            FullScreenCallView(viewModel: callViewModel) {
                showCallView = false
            }
            .onAppear {
                // 통화 화면 표시 시 자동으로 통화 시작
                if !callViewModel.isConnected && !callViewModel.isBusy {
                    callViewModel.startCall()
                }
            }
        }
    }
}

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

    /// 시간대에 따른 메시지 선택 (이름 포함)
    static func randomMessage(name: String?) -> String {
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

        let message = pool.randomElement() ?? "안녕하세요!"

        // 이름이 있으면 "xxx 어르신! " 접두사 추가
        if let name = name, !name.isEmpty {
            return "\(name) 어르신!\n\(message)"
        }
        return message
    }
}

/// 어르신 홈 탭 컨텐츠
struct WardHomeTabContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var showCallView: Bool
    @State private var currentMessage: String = ""
    @AppStorage("locationTrackingEnabled") private var locationTrackingEnabled = true
    @AppStorage("todayCallDuration") private var todayCallDuration: Int = 0  // 초 단위
    @AppStorage("fontSizeScale") private var fontSizeScale = 1.0  // 글씨 크기 배율

    var body: some View {
        ZStack {
            // 배경
            Color.creamRice
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 바 (프로필 + SOS) - 숨김 처리
                // topBar
                //     .padding(.horizontal, 20)
                //     .padding(.top, 8)

                Spacer()

                // 말풍선
                speechBubble
                    .padding(.horizontal, 20)
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
        .onAppear {
            // 어르신 이름 포함하여 메시지 갱신
            currentMessage = SodamMessages.randomMessage(name: appState.currentUser?.nickname)
            // 위치 추적 자동 시작
            if locationTrackingEnabled {
                LocationService.shared.startTracking()
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
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            Spacer()

            // SOS 버튼
            EmergencyButton()
        }
    }

    // MARK: - 말풍선

    private var speechBubble: some View {
        VStack(spacing: 0) {
            Text(currentMessage)
                .font(.system(size: 24 * fontSizeScale, weight: .bold))
                .foregroundColor(.deepMoss)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.softSprout.opacity(0.6))
                )

            // 말풍선 꼬리
            Triangle()
                .fill(Color.softSprout.opacity(0.6))
                .frame(width: 24, height: 15)
                .rotationEffect(.degrees(180))
        }
    }

    // MARK: - 캐릭터 이미지

    private var characterImage: some View {
        Image("damso")
            .resizable()
            .scaledToFit()
            .frame(width: 320, height: 320)
            .clipShape(Circle())
            .background(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            )
    }

    // MARK: - 통화 버튼

    private var callButton: some View {
        Button(action: {
            showCallView = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 32 * fontSizeScale))
                Text("소담이와 담소하기")
                    .font(.system(size: 28 * fontSizeScale, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 80 * fontSizeScale)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.damsoGreen)
                    .shadow(color: Color.damsoGreen.opacity(0.3), radius: 12, y: 6)
            )
        }
    }

    // MARK: - 오늘 대화 시간 뱃지

    private var todayDurationBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 24 * fontSizeScale, weight: .bold))
                .foregroundColor(.gray)

            Text("오늘 대화 시간 : ")
                .font(.system(size: 24 * fontSizeScale, weight: .bold))
                .foregroundColor(.gray)

            Text("\(todayCallDuration / 60)분")
                .font(.system(size: 24 * fontSizeScale, weight: .bold))
                .foregroundColor(.deepMoss)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
        )
    }
}