//
//  GuardianHomeView.swift
//  damso
//
//  보호자 홈 화면 (대시보드)
//

import SwiftUI

/// 기간 필터 타입
enum PeriodFilter: String, CaseIterable {
    case today = "오늘"
    case week = "이번 주"
    case month = "이번 달"
    
    /// 서버 API에 전달할 값
    var apiValue: String {
        switch self {
        case .today: return "today"
        case .week: return "week"
        case .month: return "month"
        }
    }
}

/// 보호자 홈 화면 (대시보드)
struct GuardianHomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GuardianDashboardViewModel()
    @State private var selectedPeriod: PeriodFilter = .today

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 상단 헤더 (연결 상태, 설정)
                    headerSection
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 어르신 선택 카드 (다중 어르신 지원)
                    if let guardianInfo = appState.currentUser?.guardianInfo,
                       !guardianInfo.wards.isEmpty {
                        wardSelectionSection(wards: guardianInfo.wards)
                            .padding(.top, 16)
                    }

                    // AI 요약 말풍선
                    aiSummarySection
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 메인 컨텐츠 영역 (흰색 카드)
                    VStack(spacing: 20) {
                        // 기간 필터
                        periodFilterSection

                        // 통계 카드
                        statisticsSection

                        // 건강 알림
                        if !viewModel.alerts.isEmpty {
                            healthAlertsSection
                        }

                        // 최근 대화 요약
                        recentConversationsSection
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.9))
                    )
                    .padding(.top, 16)
                }
            }
            .background(Color.creamRice)
            .refreshable {
                await viewModel.fetchDashboard()
            }
            .task {
                await viewModel.fetchDashboard()
            }
        }
    }

    // MARK: - 상단 헤더

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 연결 상태
                if let guardianInfo = appState.currentUser?.guardianInfo,
                   guardianInfo.hasLinkedWard {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.damsoGreen)
                            .frame(width: 8, height: 8)
                        Text("연결됨")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.damsoGreen)
                    }
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("연결 대기")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }

                // 타이틀
                Text("케어 대시보드")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()

            // 설정 버튼
            NavigationLink {
                GuardianSettingsView()
                    .environmentObject(appState)
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 어르신 선택 섹션

    private func wardSelectionSection(wards: [WardRegistrationInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("어르신")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(wards) { ward in
                        WardSelectionCard(
                            ward: ward,
                            isSelected: isWardSelected(ward),
                            onSelect: {
                                viewModel.selectWard(ward)
                            }
                        )
                    }

                    // 어르신 추가 버튼
                    AddWardCard()
                }
                .padding(.horizontal)
            }
        }
    }

    /// 어르신 선택 여부 확인
    private func isWardSelected(_ ward: WardRegistrationInfo) -> Bool {
        let wardId = ward.linkedWardId ?? ward.registrationId
        // 선택된 것이 없으면 첫 번째 연결된 어르신 자동 선택
        if viewModel.selectedWardId == nil {
            if let firstLinked = appState.currentUser?.guardianInfo?.wards.first(where: { $0.isLinked }) {
                return ward.id == firstLinked.id
            }
            return ward.id == appState.currentUser?.guardianInfo?.wards.first?.id
        }
        return viewModel.selectedWardId == wardId
    }

    // MARK: - AI 요약 말풍선

    private var aiSummarySection: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI 아바타
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.damsoGreen)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                )

            // 말풍선
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.aiSummaryMessage)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )

            Spacer()
        }
    }

    // MARK: - 기간 필터

    private var periodFilterSection: some View {
        HStack(spacing: 8) {
            ForEach(PeriodFilter.allCases, id: \.rawValue) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                    // 기간별 데이터 로드
                    Task {
                        await viewModel.fetchDashboard(wardId: viewModel.selectedWardId, period: period.apiValue)
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .foregroundColor(selectedPeriod == period ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period
                                      ? Color(.systemGray6)
                                      : Color.clear)
                        )
                }
            }
            Spacer()
        }
    }

    // MARK: - 통계 카드

    private var statisticsSection: some View {
        HStack(spacing: 12) {
            // 통화 횟수
            StatisticCard(
                icon: "phone.fill",
                iconColor: .blue,
                title: "통화 횟수",
                value: "\(viewModel.totalCalls)회"
            )

            // 총 대화 시간
            StatisticCard(
                icon: "clock.fill",
                iconColor: .orange,
                title: "총 대화 시간",
                value: "\(viewModel.totalDuration)분"
            )
        }
    }

    // MARK: - 건강 알림

    private var healthAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("건강 알림")
                    .font(.headline)
            }

            ForEach(viewModel.alerts) { alert in
                NavigationLink {
                    AlertDetailView(alert: alert)
                } label: {
                    HealthAlertCard(alert: alert)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 최근 대화 요약

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text("최근 대화 요약")
                    .font(.headline)

                Spacer()

                NavigationLink("전체보기") {
                    CallHistoryListView()
                        .environmentObject(appState)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            if viewModel.recentCalls.isEmpty {
                Text("아직 대화 기록이 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.recentCalls) { call in
                    NavigationLink {
                        CallDetailView(call: call)
                    } label: {
                        ConversationSummaryCard(call: call)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

// MARK: - 어르신 선택 카드

struct WardSelectionCard: View {
    let ward: WardRegistrationInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // 프로필 이미지
                ZStack {
                    Circle()
                        .fill(ward.isLinked ? Color.damsoGreen.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: ward.isLinked ? "person.fill" : "person.badge.clock")
                        .font(.title2)
                        .foregroundColor(ward.isLinked ? .damsoGreen : .gray)
                }

                // 이름
                Text(ward.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 연결 상태
                Text(ward.isLinked ? "연결됨" : "대기중")
                    .font(.caption2)
                    .foregroundColor(ward.isLinked ? .damsoGreen : .orange)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.damsoGreen.opacity(0.3) : Color.clear, radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.damsoGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 어르신 추가 카드

struct AddWardCard: View {
    var body: some View {
        NavigationLink {
            AddWardDetailedView()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 56, height: 56)

                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                Text("추가")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(" ")
                    .font(.caption2)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 통계 카드

struct StatisticCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - 건강 알림 카드

struct HealthAlertCard: View {
    let alert: DashboardAlert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.damsoWarning)

                Text(alert.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.softSprout.opacity(0.3))
        )
    }
}

// MARK: - 대화 요약 카드

struct ConversationSummaryCard: View {
    let call: RecentCall

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // 통화 시간 배지
                Text("\(call.duration)분")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.damsoGreen)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    // 날짜/시간
                    Text(formatDate(call.date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 요약
                    Text(call.summary)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Spacer()

                // 중요 표시 (부정적 기분일 경우)
                if call.mood == .negative {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }

            // 자세히 보기 버튼
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("자세히 보기")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'오늘' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'어제' HH:mm"
        } else {
            formatter.dateFormat = "M월 d일 HH:mm"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GuardianHomeView()
            .environmentObject(AppState())
    }
}
