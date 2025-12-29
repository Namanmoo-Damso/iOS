//
//  RecentCallCard.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 최근 통화 카드
struct RecentCallCard: View {
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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 a h시 mm분"
        return formatter.string(from: call.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 날짜, 시간
            HStack(spacing: 8) {
                // 기분 인디케이터
                Circle()
                    .fill(moodColor)
                    .frame(width: 10, height: 10)

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("•")
                    .foregroundColor(.secondary)

                Text("\(call.duration)분")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 요약
            Text(call.summary)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 태그
            if !call.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(call.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        RecentCallCard(call: RecentCall(
            id: "1",
            date: Date(),
            duration: 12,
            summary: "어머니께서 오늘 날씨가 좋다고 말씀하시며 산책을 다녀오셨다고 하셨습니다.",
            tags: ["날씨", "산책", "긍정적"],
            mood: .positive
        ))

        RecentCallCard(call: RecentCall(
            id: "2",
            date: Date().addingTimeInterval(-86400),
            duration: 8,
            summary: "평소와 같은 일상 대화를 나누셨습니다.",
            tags: ["일상"],
            mood: .neutral
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
