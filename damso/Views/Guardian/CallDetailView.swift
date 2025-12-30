//
//  CallDetailView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 대화 상세 페이지
struct CallDetailView: View {
    let call: RecentCall

    private var moodColor: Color {
        switch call.mood {
        case .positive:
            return .green
        case .neutral:
            return .gray
        case .negative:
            return .red
        }
    }

    private var moodText: String {
        switch call.mood {
        case .positive:
            return "긍정적"
        case .neutral:
            return "보통"
        case .negative:
            return "부정적"
        }
    }

    private var moodIcon: String {
        switch call.mood {
        case .positive:
            return "face.smiling.fill"
        case .neutral:
            return "face.smiling"
        case .negative:
            return "face.dashed"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: call.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h시 mm분"
        return formatter.string(from: call.date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더 카드
                headerCard

                // 대화 요약
                summarySection

                // 감정 분석
                emotionAnalysisSection

                // 주요 키워드
                keywordsSection

                // 대화 상세 내용
                conversationDetailSection

                // AI 인사이트
                aiInsightSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("대화 상세")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // 날짜 및 시간
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 기분 배지
                VStack(spacing: 4) {
                    Image(systemName: moodIcon)
                        .font(.system(size: 32))
                        .foregroundColor(moodColor)

                    Text(moodText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(moodColor)
                }
            }

            Divider()

            // 통화 정보
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(call.duration)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("분")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(call.tags.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("주제")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("87%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("참여도")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "대화 요약", icon: "text.alignleft")

            Text(call.summary)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)

            // 추가 요약 정보
            Text("어머니께서는 오늘 아침에 일어나시자마자 창문을 열어 바깥 공기를 마셨다고 하셨습니다. 날씨가 맑아서 기분이 좋으셨고, 아침 식사 후 동네 공원에서 30분 정도 산책을 하셨다고 합니다. 산책 중에 이웃 할머니를 만나 잠시 이야기를 나누셨고, 함께 벤치에 앉아 따뜻한 햇볕을 쬐셨다고 합니다.")
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Emotion Analysis Section

    private var emotionAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "감정 분석", icon: "heart.fill")

            VStack(spacing: 12) {
                emotionBar(label: "기쁨", value: 0.75, color: .green)
                emotionBar(label: "평온", value: 0.60, color: .blue)
                emotionBar(label: "그리움", value: 0.30, color: .purple)
                emotionBar(label: "걱정", value: 0.15, color: .orange)
                emotionBar(label: "슬픔", value: 0.05, color: .gray)
            }

            Text("전반적으로 밝고 긍정적인 감정 상태를 보이셨습니다. 특히 산책과 이웃과의 만남에서 기쁨을 느끼신 것으로 분석됩니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func emotionBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Keywords Section

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "주요 키워드", icon: "tag.fill")

            FlowLayout(spacing: 8) {
                ForEach(call.tags + ["아침 산책", "이웃", "햇볕", "공원"], id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // 키워드 빈도
            VStack(alignment: .leading, spacing: 8) {
                Text("자주 언급된 단어")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    keywordFrequency(word: "날씨", count: 5)
                    keywordFrequency(word: "산책", count: 4)
                    keywordFrequency(word: "기분", count: 3)
                    keywordFrequency(word: "이웃", count: 2)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func keywordFrequency(word: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(word)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Conversation Detail Section

    private var conversationDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "대화 하이라이트", icon: "quote.bubble.fill")

            VStack(spacing: 16) {
                conversationBubble(
                    speaker: "어머니",
                    text: "오늘 날씨가 정말 좋더라고. 아침에 일어나서 창문 열었는데 공기가 너무 상쾌했어.",
                    isWard: true,
                    time: "10:32"
                )

                conversationBubble(
                    speaker: "다미",
                    text: "날씨가 좋으니 기분도 좋으시겠어요! 오늘 특별히 하신 일이 있으세요?",
                    isWard: false,
                    time: "10:33"
                )

                conversationBubble(
                    speaker: "어머니",
                    text: "응, 아침 먹고 공원에 산책 다녀왔어. 거기서 옆집 순자 할머니 만났는데, 한참 얘기했지.",
                    isWard: true,
                    time: "10:35"
                )

                conversationBubble(
                    speaker: "다미",
                    text: "좋은 시간 보내셨네요! 순자 할머니와는 무슨 이야기를 나누셨어요?",
                    isWard: false,
                    time: "10:36"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func conversationBubble(speaker: String, text: String, isWard: Bool, time: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if isWard {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(speaker.prefix(1)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    )
            }

            VStack(alignment: isWard ? .leading : .trailing, spacing: 4) {
                HStack {
                    Text(speaker)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isWard ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
            }

            if !isWard {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "sparkle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: isWard ? .leading : .trailing)
    }

    // MARK: - AI Insight Section

    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "AI 인사이트", icon: "sparkles")

            VStack(alignment: .leading, spacing: 16) {
                insightItem(
                    icon: "heart.fill",
                    color: .pink,
                    title: "건강 상태",
                    description: "산책을 즐기시는 등 활동적인 모습을 보이셨습니다. 신체 건강에 대한 특별한 불편함은 언급되지 않았습니다."
                )

                insightItem(
                    icon: "person.2.fill",
                    color: .blue,
                    title: "사회적 활동",
                    description: "이웃과의 대화를 즐기시며 사회적 교류를 활발히 하고 계십니다. 외로움에 대한 언급은 없었습니다."
                )

                insightItem(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "인지 상태",
                    description: "대화 흐름을 잘 따라가시며, 구체적인 일상을 기억하고 전달하셨습니다. 인지 기능이 양호한 것으로 판단됩니다."
                )

                insightItem(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "주의사항",
                    description: "특별한 주의사항은 발견되지 않았습니다. 현재 상태를 잘 유지하고 계십니다."
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func insightItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Helper

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - Flow Layout (키워드 래핑용)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        CallDetailView(call: RecentCall(
            id: "1",
            date: Date(),
            duration: 12,
            summary: "어머니께서 오늘 날씨가 좋다고 말씀하시며 산책을 다녀오셨다고 하셨습니다.",
            tags: ["날씨", "산책", "긍정적"],
            mood: .positive
        ))
    }
}
