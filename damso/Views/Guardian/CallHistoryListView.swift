//
//  CallHistoryListView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 전체 대화 기록 목록
struct CallHistoryListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: CallFilter = .all
    @State private var searchText = ""
    @State private var calls: [RecentCall] = []
    @State private var isLoading = false

    enum CallFilter: String, CaseIterable {
        case all = "전체"
        case positive = "긍정적"
        case neutral = "보통"
        case negative = "부정적"

        var mood: RecentCall.CallMood? {
            switch self {
            case .all: return nil
            case .positive: return .positive
            case .neutral: return .neutral
            case .negative: return .negative
            }
        }
    }

    private var filteredCalls: [RecentCall] {
        var result = calls

        // 기분 필터
        if let mood = selectedFilter.mood {
            result = result.filter { $0.mood == mood }
        }

        // 검색어 필터
        if !searchText.isEmpty {
            result = result.filter {
                $0.summary.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    private var groupedCalls: [(String, [RecentCall])] {
        let grouped = Dictionary(grouping: filteredCalls) { call -> String in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy년 M월"
            return formatter.string(from: call.date)
        }

        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 필터
            filterSection

            // 통계 요약
            statisticsSummary

            // 목록
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredCalls.isEmpty {
                emptyState
            } else {
                callsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("대화 기록")
        .searchable(text: $searchText, prompt: "대화 내용, 키워드 검색")
        .task {
            await loadCalls()
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CallFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: chipColor(for: filter)
                    ) {
                        withAnimation {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private func chipColor(for filter: CallFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }

    // MARK: - Statistics Summary

    private var statisticsSummary: some View {
        HStack(spacing: 16) {
            summaryItem(
                value: "\(filteredCalls.count)",
                label: "총 대화",
                icon: "phone.fill",
                color: .blue
            )

            Divider()
                .frame(height: 40)

            summaryItem(
                value: "\(totalDuration)분",
                label: "총 시간",
                icon: "clock.fill",
                color: .orange
            )

            Divider()
                .frame(height: 40)

            summaryItem(
                value: "\(positivePercent)%",
                label: "긍정률",
                icon: "face.smiling.fill",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var totalDuration: Int {
        filteredCalls.reduce(0) { $0 + $1.duration }
    }

    private var positivePercent: Int {
        guard !filteredCalls.isEmpty else { return 0 }
        let positiveCount = filteredCalls.filter { $0.mood == .positive }.count
        return Int(Double(positiveCount) / Double(filteredCalls.count) * 100)
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calls List

    private var callsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedCalls, id: \.0) { month, monthCalls in
                    Section {
                        ForEach(monthCalls) { call in
                            NavigationLink(destination: CallDetailView(call: call)) {
                                CallHistoryRow(call: call)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(month)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(monthCalls.count)건")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("대화 기록이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)

            if !searchText.isEmpty || selectedFilter != .all {
                Text("검색 조건을 변경해 보세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("필터 초기화") {
                    searchText = ""
                    selectedFilter = .all
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Data Loading

    private func loadCalls() async {
        isLoading = true

        // TODO: API 연동 필요 - GET /v1/guardian/calls
        // 현재는 빈 배열로 초기화
        calls = []
        
        isLoading = false
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.1))
                )
        }
    }
}

// MARK: - Call History Row

struct CallHistoryRow: View {
    let call: RecentCall

    private var moodColor: Color {
        switch call.mood {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: call.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: call.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 기분 인디케이터
            Circle()
                .fill(moodColor)
                .frame(width: 12, height: 12)

            // 내용
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formattedDate)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(call.duration)분")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(call.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if !call.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(call.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if call.tags.count > 3 {
                            Text("+\(call.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}