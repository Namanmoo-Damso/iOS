//
//  StatisticsDetailView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI
import Charts

/// 통계 상세 페이지
struct StatisticsDetailView: View {
    let statisticType: StatisticType
    let viewModel: GuardianDashboardViewModel

    enum StatisticType {
        case totalCalls
        case averageDuration
        case mood

        var title: String {
            switch self {
            case .totalCalls: return "총 대화 수"
            case .averageDuration: return "평균 대화 시간"
            case .mood: return "감정 분석"
            }
        }

        var icon: String {
            switch self {
            case .totalCalls: return "phone.fill"
            case .averageDuration: return "clock.fill"
            case .mood: return "face.smiling.fill"
            }
        }

        var color: Color {
            switch self {
            case .totalCalls: return .blue
            case .averageDuration: return .orange
            case .mood: return .green
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더
                headerCard

                // 타입별 상세 내용
                switch statisticType {
                case .totalCalls:
                    totalCallsContent
                case .averageDuration:
                    averageDurationContent
                case .mood:
                    moodContent
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(statisticType.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            Image(systemName: statisticType.icon)
                .font(.system(size: 48))
                .foregroundColor(statisticType.color)
                .frame(width: 80, height: 80)
                .background(statisticType.color.opacity(0.15))
                .clipShape(Circle())

            switch statisticType {
            case .totalCalls:
                Text("\(viewModel.totalCalls)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)

                if viewModel.weeklyChange > 0 {
                    Text("이번 주 +\(viewModel.weeklyChange)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }

            case .averageDuration:
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(viewModel.averageDuration)")
                        .font(.system(size: 48, weight: .bold))
                    Text("분")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                Text("대화당 평균")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .mood:
                Text("\(viewModel.positiveMoodPercent)%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)

                Text("긍정적 감정")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }

    // MARK: - Total Calls Content

    @ViewBuilder
    private var totalCallsContent: some View {
        // 주간 대화 차트
        weeklyCallsChart

        // 일별 통계
        dailyStatistics

        // 월간 비교
        monthlyComparison
    }

    private var weeklyCallsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "주간 대화 추이", icon: "chart.bar.fill")

            Chart {
                ForEach(weeklyData, id: \.day) { data in
                    BarMark(
                        x: .value("요일", data.day),
                        y: .value("대화 수", data.count)
                    )
                    .foregroundStyle(statisticType.color.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private var weeklyData: [(day: String, count: Int)] {
        [
            ("월", 3),
            ("화", 4),
            ("수", 2),
            ("목", 5),
            ("금", 4),
            ("토", 3),
            ("일", 3)
        ]
    }

    private var dailyStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "상세 통계", icon: "list.bullet")

            VStack(spacing: 12) {
                statisticRow(label: "이번 주 총 대화", value: "\(viewModel.totalCalls)회")
                statisticRow(label: "지난 주 대화", value: "\(viewModel.totalCalls - viewModel.weeklyChange)회")
                statisticRow(label: "주간 증감", value: viewModel.weeklyChange >= 0 ? "+\(viewModel.weeklyChange)회" : "\(viewModel.weeklyChange)회", color: viewModel.weeklyChange >= 0 ? .green : .red)
                statisticRow(label: "하루 평균", value: String(format: "%.1f회", Double(viewModel.totalCalls) / 7.0))
                statisticRow(label: "가장 활발한 요일", value: "목요일")
                statisticRow(label: "가장 조용한 요일", value: "수요일")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private var monthlyComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "월간 비교", icon: "calendar")

            HStack(spacing: 16) {
                monthCard(month: "11월", count: 85, isCurrentMonth: false)
                monthCard(month: "12월", count: viewModel.totalCalls, isCurrentMonth: true)
            }

            Text("12월 대화량이 11월 대비 \(abs(viewModel.totalCalls - 85))건 \(viewModel.totalCalls >= 85 ? "증가" : "감소")했습니다.")
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

    private func monthCard(month: String, count: Int, isCurrentMonth: Bool) -> some View {
        VStack(spacing: 8) {
            Text(month)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(isCurrentMonth ? statisticType.color : .primary)

            Text("대화")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentMonth ? statisticType.color.opacity(0.1) : Color(.systemGray6))
        )
    }

    // MARK: - Average Duration Content

    @ViewBuilder
    private var averageDurationContent: some View {
        // 시간대별 차트
        durationChart

        // 대화 시간 분포
        durationDistribution

        // 상세 통계
        durationStatistics
    }

    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "주간 대화 시간 추이", icon: "chart.line.uptrend.xyaxis")

            Chart {
                ForEach(durationData, id: \.day) { data in
                    LineMark(
                        x: .value("요일", data.day),
                        y: .value("시간", data.minutes)
                    )
                    .foregroundStyle(statisticType.color)
                    .symbol(Circle())

                    AreaMark(
                        x: .value("요일", data.day),
                        y: .value("시간", data.minutes)
                    )
                    .foregroundStyle(statisticType.color.opacity(0.1))
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private var durationData: [(day: String, minutes: Int)] {
        [
            ("월", 12),
            ("화", 15),
            ("수", 8),
            ("목", 18),
            ("금", 10),
            ("토", 14),
            ("일", 11)
        ]
    }

    private var durationDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "대화 시간 분포", icon: "chart.pie.fill")

            VStack(spacing: 12) {
                distributionBar(label: "5분 미만", percent: 15, color: .gray)
                distributionBar(label: "5-10분", percent: 35, color: .orange)
                distributionBar(label: "10-15분", percent: 30, color: .green)
                distributionBar(label: "15분 이상", percent: 20, color: .blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func distributionBar(label: String, percent: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * Double(percent) / 100.0)
                }
            }
            .frame(height: 12)

            Text("\(percent)%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var durationStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "상세 통계", icon: "list.bullet")

            VStack(spacing: 12) {
                statisticRow(label: "총 대화 시간", value: "\(viewModel.totalCalls * viewModel.averageDuration)분")
                statisticRow(label: "평균 대화 시간", value: "\(viewModel.averageDuration)분")
                statisticRow(label: "최장 대화", value: "25분", color: .blue)
                statisticRow(label: "최단 대화", value: "3분", color: .orange)
                statisticRow(label: "권장 대화 시간", value: "10-15분")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Mood Content

    @ViewBuilder
    private var moodContent: some View {
        // 감정 분포
        moodDistribution

        // 주간 감정 추이
        moodTrend

        // 자주 감지된 감정
        frequentEmotions

        // AI 분석
        moodAnalysis
    }

    private var moodDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "감정 분포", icon: "chart.pie.fill")

            HStack(spacing: 24) {
                moodCircle(label: "긍정적", percent: viewModel.positiveMoodPercent, color: .green)
                moodCircle(label: "중립", percent: 100 - viewModel.positiveMoodPercent - 10, color: .gray)
                moodCircle(label: "부정적", percent: 10, color: .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func moodCircle(label: String, percent: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: Double(percent) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(percent)%")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var moodTrend: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "주간 감정 추이", icon: "chart.line.uptrend.xyaxis")

            Chart {
                ForEach(moodTrendData, id: \.day) { data in
                    LineMark(
                        x: .value("요일", data.day),
                        y: .value("긍정률", data.positive)
                    )
                    .foregroundStyle(.green)
                    .symbol(Circle())
                }
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private var moodTrendData: [(day: String, positive: Int)] {
        [
            ("월", 80),
            ("화", 85),
            ("수", 75),
            ("목", 90),
            ("금", 85),
            ("토", 88),
            ("일", 82)
        ]
    }

    private var frequentEmotions: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "자주 감지된 감정", icon: "heart.fill")

            VStack(spacing: 12) {
                emotionRow(emoji: "😊", label: "기쁨", count: 15, color: .green)
                emotionRow(emoji: "😌", label: "평온", count: 12, color: .blue)
                emotionRow(emoji: "🥰", label: "사랑", count: 8, color: .pink)
                emotionRow(emoji: "😢", label: "그리움", count: 5, color: .purple)
                emotionRow(emoji: "😟", label: "걱정", count: 3, color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func emotionRow(emoji: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)

            Text(label)
                .font(.subheadline)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * Double(count) / 15.0)
            }
            .frame(height: 8)

            Text("\(count)회")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var moodAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "AI 분석", icon: "sparkles")

            VStack(alignment: .leading, spacing: 12) {
                Text("전반적인 감정 상태 평가")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("어머니의 전반적인 감정 상태는 매우 양호합니다. 대화 중 긍정적인 감정 표현이 \(viewModel.positiveMoodPercent)%로 높게 나타났으며, 특히 가족과 일상에 대한 이야기를 할 때 기쁨과 만족감을 자주 표현하셨습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                Text("주요 관심사는 날씨, 가족, 건강 순으로 나타났으며, 사회적 교류에 대한 언급도 자주 있었습니다. 이는 정서적으로 안정된 상태를 나타냅니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)
        }
    }

    private func statisticRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}