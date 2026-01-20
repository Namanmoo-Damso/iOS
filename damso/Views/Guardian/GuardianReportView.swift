//
//  GuardianReportView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI
import Charts

/// 보호자 분석 보고서 화면
struct GuardianReportView: View {
    @StateObject private var viewModel = GuardianReportViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 감정 추이 차트
                    EmotionTrendChart(data: viewModel.emotionTrend)

                    // 건강 키워드
                    if let keywords = viewModel.healthKeywords {
                        HealthKeywordsCard(keywords: keywords)
                    }

                    // 주간 요약
                    if !viewModel.weeklySummary.isEmpty {
                        WeeklySummaryCard(summary: viewModel.weeklySummary)
                    }
                }
                .padding()
            }
            .background(Color.creamRice)
            .navigationTitle("분석 보고서")
            .refreshable {
                await viewModel.fetchReport()
            }
        }
        .task {
            await viewModel.fetchReport()
        }
    }
}

// MARK: - Emotion Trend Chart

struct EmotionTrendChart: View {
    let data: [EmotionDataPoint]

    private var chartData: [(date: Date, score: Double, mood: EmotionDataPoint.EmotionMood)] {
        data.map { ($0.dateValue, $0.score, $0.mood) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("감정 상태 추이", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            if data.isEmpty {
                Text("데이터가 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData, id: \.date) { item in
                    LineMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("감정", item.score)
                    )
                    .foregroundStyle(Color.damsoGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("감정", item.score)
                    )
                    .foregroundStyle(moodColor(item.mood))
                    .symbolSize(100)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let score = value.as(Double.self) {
                                Text(moodEmoji(for: score))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func moodColor(_ mood: EmotionDataPoint.EmotionMood) -> Color {
        switch mood {
        case .positive: return .damsoSafe
        case .neutral: return .damsoWarning
        case .negative: return .damsoDanger
        }
    }

    private func moodEmoji(for score: Double) -> String {
        if score >= 0.7 { return "😊" }
        if score >= 0.4 { return "😐" }
        return "😢"
    }
}

// MARK: - Health Keywords Card

struct HealthKeywordsCard: View {
    let keywords: HealthKeywords

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("건강 키워드", systemImage: "heart.text.square")
                .font(.headline)

            VStack(spacing: 12) {
                // 통증 언급
                HStack {
                    Image(systemName: "bandage")
                        .foregroundColor(.damsoDanger)
                        .frame(width: 24)

                    Text("통증 언급")
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(keywords.pain.count)회")
                        .fontWeight(.semibold)
                        .foregroundColor(keywords.pain.count > 0 ? .damsoDanger : .damsoSafe)

                    if keywords.pain.trend == "increasing" {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.damsoDanger)
                            .font(.caption)
                    }
                }

                Divider()

                // 수면
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(.purple)
                        .frame(width: 24)

                    Text("수면")
                        .foregroundColor(.primary)

                    Spacer()

                    Text(statusText(keywords.sleep.status))
                        .fontWeight(.medium)
                        .foregroundColor(statusColor(keywords.sleep.status))
                }

                Divider()

                // 식사
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Text("식사")
                        .foregroundColor(.primary)

                    Spacer()

                    Text(statusText(keywords.meal.status))
                        .fontWeight(.medium)
                        .foregroundColor(statusColor(keywords.meal.status))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "good": return "양호"
        case "regular": return "규칙적"
        case "poor": return "불량"
        case "irregular": return "불규칙"
        default: return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "good", "regular": return .damsoSafe
        case "poor", "irregular": return .damsoDanger
        default: return .secondary
        }
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 요약", systemImage: "doc.text")
                .font(.headline)

            Text(summary)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}