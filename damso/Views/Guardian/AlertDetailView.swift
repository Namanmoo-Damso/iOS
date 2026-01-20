//
//  AlertDetailView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 건강 알림 상세 페이지
struct AlertDetailView: View {
    let alert: DashboardAlert

    private var alertColor: Color {
        switch alert.type {
        case .warning:
            return .red
        case .info:
            return .blue
        }
    }

    private var alertIcon: String {
        switch alert.type {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var alertTypeText: String {
        switch alert.type {
        case .warning:
            return "경고"
        case .info:
            return "정보"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더
                headerCard

                // 상세 분석
                analysisSection

                // 관련 대화
                relatedCallsSection

                // 트렌드
                trendSection

                // 권장 조치
                recommendationSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("알림 상세")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // 아이콘
            Image(systemName: alertIcon)
                .font(.system(size: 48))
                .foregroundColor(alertColor)
                .frame(width: 80, height: 80)
                .background(alertColor.opacity(0.15))
                .clipShape(Circle())

            // 타입 배지
            Text(alertTypeText)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(alertColor)
                .clipShape(Capsule())

            // 메시지
            Text(alert.message)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // 날짜
            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }

    private var formattedDate: String {
        // alert.date가 String이므로 그대로 표시
        return alert.date
    }

    // MARK: - Analysis Section

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "상세 분석", icon: "magnifyingglass")

            VStack(alignment: .leading, spacing: 12) {
                if alert.type == .warning {
                    analysisItem(
                        title: "감지된 키워드",
                        content: "\"허리가 아파\", \"다리가 쑤셔\", \"몸이 찌뿌둥해\""
                    )

                    analysisItem(
                        title: "발생 빈도",
                        content: "최근 3일간 총 5회 언급"
                    )

                    analysisItem(
                        title: "이전 대비",
                        content: "지난주 대비 150% 증가"
                    )

                    analysisItem(
                        title: "심각도 평가",
                        content: "중간 - 지속적인 모니터링 권장"
                    )
                } else {
                    analysisItem(
                        title: "분석 내용",
                        content: "이번 주 대화 횟수가 지난주 대비 20% 증가했습니다."
                    )

                    analysisItem(
                        title: "긍정적 변화",
                        content: "더 활발한 사회적 교류가 이루어지고 있습니다."
                    )

                    analysisItem(
                        title: "권장 사항",
                        content: "현재 긍정적인 변화를 유지해 주세요."
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func analysisItem(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Related Calls Section

    private var relatedCallsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "관련 대화", icon: "message.fill")

            ForEach(0..<3, id: \.self) { index in
                relatedCallItem(
                    date: "12월 \(24 - index)일",
                    time: "\(10 + index):30",
                    excerpt: getExcerpt(for: index),
                    keyword: getKeyword(for: index)
                )
            }

            NavigationLink {
                CallHistoryListView()
            } label: {
                HStack {
                    Text("모든 관련 대화 보기")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func getExcerpt(for index: Int) -> String {
        let excerpts = [
            "\"오늘 허리가 좀 아팠어. 아침에 일어나니까...\"",
            "\"어제부터 다리가 쑤시더라고. 비가 올려나...\"",
            "\"요즘 몸이 좀 찌뿌둥한 것 같아. 운동을 해야 하나...\"",
        ]
        return excerpts[index % excerpts.count]
    }

    private func getKeyword(for index: Int) -> String {
        let keywords = ["허리 통증", "다리 통증", "피로감"]
        return keywords[index % keywords.count]
    }

    private func relatedCallItem(date: String, time: String, excerpt: String, keyword: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(keyword)
                    .font(.caption)
                    .foregroundColor(alertColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(alertColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(excerpt)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "7일간 추이", icon: "chart.line.uptrend.xyaxis")

            // 간단한 트렌드 차트
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: index))
                            .frame(width: 32, height: barHeight(for: index))

                        Text(dayLabel(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // 요약
            HStack(spacing: 24) {
                trendSummaryItem(
                    label: "최다 언급일",
                    value: "12월 24일",
                    subvalue: "3회"
                )

                trendSummaryItem(
                    label: "주간 평균",
                    value: "1.4회",
                    subvalue: "일"
                )

                trendSummaryItem(
                    label: "전주 대비",
                    value: alert.type == .warning ? "+50%" : "+20%",
                    subvalue: alert.type == .warning ? "증가" : "증가"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [40, 60, 80, 100, 60, 40, 80]
        return heights[index % heights.count]
    }

    private func barColor(for index: Int) -> Color {
        let heights: [CGFloat] = [40, 60, 80, 100, 60, 40, 80]
        let height = heights[index % heights.count]
        if height >= 80 {
            return alertColor
        } else if height >= 60 {
            return alertColor.opacity(0.6)
        } else {
            return alertColor.opacity(0.3)
        }
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["월", "화", "수", "목", "금", "토", "일"]
        return days[index]
    }

    private func trendSummaryItem(label: String, value: String, subvalue: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(subvalue)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recommendation Section

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "권장 조치", icon: "lightbulb.fill")

            if alert.type == .warning {
                recommendationItem(
                    icon: "stethoscope",
                    color: .red,
                    title: "건강 확인",
                    description: "어르신께 직접 연락하여 건강 상태를 확인해 보세요. 지속적인 통증 호소가 있습니다."
                )

                recommendationItem(
                    icon: "calendar",
                    color: .orange,
                    title: "병원 방문 고려",
                    description: "통증이 3일 이상 지속되고 있습니다. 가까운 병원 방문을 권장합니다."
                )

                recommendationItem(
                    icon: "bell.fill",
                    color: .blue,
                    title: "모니터링 강화",
                    description: "향후 1주일간 건강 관련 키워드를 집중 모니터링합니다."
                )
            } else {
                recommendationItem(
                    icon: "hand.thumbsup.fill",
                    color: .green,
                    title: "긍정적 변화 유지",
                    description: "현재 좋은 변화가 나타나고 있습니다. 이 상태를 유지해 주세요."
                )

                recommendationItem(
                    icon: "message.fill",
                    color: .blue,
                    title: "격려 메시지",
                    description: "어르신께 긍정적인 피드백을 전해 보세요. 대화가 더욱 활발해질 수 있습니다."
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func recommendationItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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