import SwiftUI

/// 스크롤 가능한 자막 히스토리 뷰
struct SubtitleHistoryView: View {
    let messages: [SubtitleMessage]
    let currentAgentText: String
    let currentUserText: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    // 확정된 메시지 히스토리
                    ForEach(messages) { message in
                        SubtitleBubble(
                            text: message.text,
                            isFinal: message.isFinal,
                            isAgent: message.isAgent
                        )
                        .id(message.id)
                    }

                    // 현재 진행 중인 Agent 자막
                    if !currentAgentText.isEmpty {
                        SubtitleBubble(
                            text: currentAgentText,
                            isFinal: false,
                            isAgent: true
                        )
                        .id("currentAgent")
                    }

                    // 현재 진행 중인 사용자 자막
                    if !currentUserText.isEmpty {
                        SubtitleBubble(
                            text: currentUserText,
                            isFinal: false,
                            isAgent: false
                        )
                        .id("currentUser")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)  // 양옆 여백 추가
            }
            .onChange(of: messages.count) { _, _ in
                // 새 메시지가 추가되면 맨 아래로 스크롤
                withAnimation(.easeOut(duration: 0.2)) {
                    if !currentUserText.isEmpty {
                        proxy.scrollTo("currentUser", anchor: .bottom)
                    } else if !currentAgentText.isEmpty {
                        proxy.scrollTo("currentAgent", anchor: .bottom)
                    } else if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: currentAgentText) { _, _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    if !currentAgentText.isEmpty {
                        proxy.scrollTo("currentAgent", anchor: .bottom)
                    }
                }
            }
            .onChange(of: currentUserText) { _, _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    if !currentUserText.isEmpty {
                        proxy.scrollTo("currentUser", anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// 실시간 자막 뷰 (하위 호환성)
struct SubtitleView: View {
    let agentText: String
    let userText: String
    let isAgentFinal: Bool
    let isUserFinal: Bool

    var body: some View {
        VStack(spacing: 12) {
            if !agentText.isEmpty {
                SubtitleBubble(
                    text: agentText,
                    isFinal: isAgentFinal,
                    isAgent: true
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !userText.isEmpty {
                SubtitleBubble(
                    text: userText,
                    isFinal: isUserFinal,
                    isAgent: false
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: agentText)
        .animation(.easeInOut(duration: 0.2), value: userText)
    }
}

/// 자막 말풍선
struct SubtitleBubble: View {
    let text: String
    let isFinal: Bool
    let isAgent: Bool

    var body: some View {
        HStack {
            if !isAgent { Spacer(minLength: 40) }

            Text(displayText)
                .font(.system(size: 22, weight: .semibold))  // 노인 대상 큰 폰트
                .foregroundColor(.white)
                .multilineTextAlignment(isAgent ? .leading : .trailing)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(isFinal ? 1.0 : 0.8)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            if isAgent { Spacer(minLength: 40) }
        }
    }

    private var displayText: String {
        isFinal ? text : text + "..."
    }

    private var backgroundColor: Color {
        if isAgent {
            return Color(hex: "7B61FF").opacity(0.9)  // 보라색 (AI)
        } else {
            return Color(hex: "3A3A3C").opacity(0.9)  // 다크 그레이 (사용자)
        }
    }
}

/// 컴팩트 자막 뷰 (단일 라인)
struct CompactSubtitleView: View {
    let text: String
    let isFinal: Bool

    var body: some View {
        if !text.isEmpty {
            Text(isFinal ? text : text + "...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(isFinal ? 1.0 : 0.7)
                .animation(.easeInOut(duration: 0.15), value: text)
        }
    }
}