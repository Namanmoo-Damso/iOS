//
//  ScheduleManagementView.swift
//  damso
//
//  AI 안부 전화 스케줄 관리 화면 (설정에서 사용)
//

import SwiftUI

/// AI 안부 전화 스케줄 관리 화면
struct ScheduleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ScheduleManagementViewModel()

    /// 어르신 목록
    private var wards: [WardRegistrationInfo] {
        appState.currentUser?.guardianInfo?.wards ?? []
    }

    /// 다중 어르신 여부
    private var hasMultipleWards: Bool {
        wards.count > 1
    }

    var body: some View {
        NavigationView {
            List {
                // 어르신 선택 (2명 이상인 경우)
                if hasMultipleWards {
                    Section("어르신 선택") {
                        ForEach(wards) { ward in
                            WardSelectionRow(
                                ward: ward,
                                isSelected: viewModel.selectedWardId == (ward.linkedWardId ?? ward.registrationId)
                            ) {
                                viewModel.selectWard(ward)
                            }
                        }
                    }
                }

                // 전체 활성화 토글
                Section {
                    Toggle("AI 안부 전화 활성화", isOn: $viewModel.isScheduleEnabled)
                        .onChange(of: viewModel.isScheduleEnabled) { _, newValue in
                            Task {
                                await viewModel.updateScheduleEnabled(newValue)
                            }
                        }
                } footer: {
                    if hasMultipleWards, let selectedWard = wards.first(where: { ($0.linkedWardId ?? $0.registrationId) == viewModel.selectedWardId }) {
                        Text("\(selectedWard.displayName) 님께 설정한 시간에 AI가 안부 전화를 드립니다.")
                    } else {
                        Text("활성화하면 설정한 시간에 AI가 어르신께 안부 전화를 드립니다.")
                    }
                }

                // 스케줄 목록
                if viewModel.isScheduleEnabled {
                    Section("스케줄 목록") {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            if viewModel.scheduleItems.isEmpty {
                                Text("등록된 스케줄이 없습니다")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach($viewModel.scheduleItems) { $item in
                                    ScheduleManagementRow(item: $item) {
                                        viewModel.editingItem = item
                                        viewModel.showEditSheet = true
                                    }
                                }
                                .onDelete { indexSet in
                                    Task {
                                        await viewModel.deleteSchedules(at: indexSet)
                                    }
                                }
                            }

                            // 스케줄 추가 버튼 (빈 상태에서도 항상 표시)
                            Button {
                                viewModel.addNewSchedule()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("스케줄 추가")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI 안부 전화 스케줄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        Task {
                            await viewModel.saveChanges()
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showEditSheet) {
                if let editingItem = viewModel.editingItem,
                   let index = viewModel.scheduleItems.firstIndex(where: { $0.id == editingItem.id }) {
                    ScheduleDetailEditView(item: $viewModel.scheduleItems[index])
                }
            }
            .task {
                // 첫 번째 어르신 자동 선택
                if viewModel.selectedWardId == nil, let firstWard = wards.first {
                    viewModel.selectedWardId = firstWard.linkedWardId ?? firstWard.registrationId
                }
                await viewModel.loadSchedules(wardId: viewModel.selectedWardId)
            }
            .alert("오류", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Ward Selection Row

struct WardSelectionRow: View {
    let ward: WardRegistrationInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // 프로필 아이콘
                ZStack {
                    Circle()
                        .fill(ward.isLinked ? Color.damsoGreen.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: ward.isLinked ? "person.fill" : "person.badge.clock")
                        .foregroundColor(ward.isLinked ? .damsoGreen : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ward.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(ward.isLinked ? "연결됨" : "연결 대기중")
                        .font(.caption)
                        .foregroundColor(ward.isLinked ? .damsoGreen : .orange)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.damsoGreen)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Management Row

struct ScheduleManagementRow: View {
    @Binding var item: AICallScheduleItem
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.slotTimeString)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(item.weekdaysSummary)
                    Text("·")
                    Text("최대 \(AICallScheduleItem.maxCallDurationMinutes)분 통화")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $item.isEnabled)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ScheduleManagementViewModel: ObservableObject {
    @Published var scheduleItems: [AICallScheduleItem] = []
    @Published var isScheduleEnabled = true
    @Published var isLoading = false
    @Published var showEditSheet = false
    @Published var editingItem: AICallScheduleItem?
    @Published var errorMessage: String?

    /// 선택된 어르신 ID (다중 어르신 지원)
    @Published var selectedWardId: String?

    /// 프로그래매틱 변경 시 onChange 무시 플래그 (무한 루프 방지)
    var isSuppressingOnChange = false

    private let registrationService = RegistrationService.shared

    /// 어르신 선택
    func selectWard(_ ward: WardRegistrationInfo) {
        selectedWardId = ward.linkedWardId ?? ward.registrationId
        Task {
            await loadSchedules(wardId: selectedWardId)
        }
    }

    /// 서버에서 스케줄 로드 (wardId 옵션)
    func loadSchedules(wardId: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let schedule = try await registrationService.fetchSchedules(wardId: wardId ?? selectedWardId)
            scheduleItems = schedule.items
            // 초기 로드 시 onChange가 트리거되지 않도록 플래그 설정
            isSuppressingOnChange = true
            isScheduleEnabled = schedule.isEnabled
            isSuppressingOnChange = false
        } catch let error as ScheduleError {
            Log.app.e("스케줄 로드 실패: \(error)")
            errorMessage = error.localizedDescription
            // 로드 실패 시 기본 스케줄 설정
            if scheduleItems.isEmpty {
                scheduleItems = [AICallScheduleItem()]
            }
        } catch {
            Log.app.e("스케줄 로드 실패: \(error)")
            // 로드 실패 시 기본 스케줄 설정
            if scheduleItems.isEmpty {
                scheduleItems = [AICallScheduleItem()]
            }
        }

        isLoading = false
    }

    /// 변경사항 저장
    func saveChanges() async {
        let schedule = AICallSchedule(items: scheduleItems, isEnabled: isScheduleEnabled)

        do {
            try await registrationService.saveSchedules(schedule, wardId: selectedWardId)
            Log.app.i("스케줄 저장 완료 (wardId: \(selectedWardId ?? "없음"))")
        } catch let error as ScheduleError {
            Log.app.e("스케줄 저장 실패: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            Log.app.e("스케줄 저장 실패: \(error)")
            errorMessage = "저장에 실패했습니다. 다시 시도해주세요."
        }
    }

    /// 스케줄 활성화 상태 업데이트
    func updateScheduleEnabled(_ enabled: Bool) async {
        // 프로그래매틱 변경 중이면 무시 (무한 루프 방지)
        guard !isSuppressingOnChange else { return }

        // 활성화 상태 변경 시에도 전체 스케줄 저장
        let schedule = AICallSchedule(items: scheduleItems, isEnabled: enabled)

        do {
            try await registrationService.saveSchedules(schedule, wardId: selectedWardId)
            Log.app.i("스케줄 활성화 상태 업데이트: \(enabled) (wardId: \(selectedWardId ?? "없음"))")
        } catch let error as ScheduleError {
            Log.app.e("스케줄 활성화 상태 업데이트 실패: \(error)")
            // 실패 시 상태 롤백 (플래그로 무한 루프 방지)
            isSuppressingOnChange = true
            isScheduleEnabled = !enabled
            isSuppressingOnChange = false
            errorMessage = error.localizedDescription
        } catch {
            Log.app.e("스케줄 활성화 상태 업데이트 실패: \(error)")
            // 실패 시 상태 롤백 (플래그로 무한 루프 방지)
            isSuppressingOnChange = true
            isScheduleEnabled = !enabled
            isSuppressingOnChange = false
            errorMessage = "상태 변경에 실패했습니다."
        }
    }

    /// 새 스케줄 추가
    func addNewSchedule() {
        let newItem = AICallScheduleItem()
        scheduleItems.append(newItem)
        editingItem = newItem
        showEditSheet = true
    }

    /// 스케줄 삭제
    func deleteSchedules(at offsets: IndexSet) async {
        // 삭제할 항목 ID 목록 저장
        let itemsToDelete = offsets.map { scheduleItems[$0] }

        // 로컬에서 먼저 삭제
        scheduleItems.remove(atOffsets: offsets)

        // 서버에서 각 항목 삭제
        for item in itemsToDelete {
            do {
                try await registrationService.deleteSchedule(id: item.id)
                Log.app.i("스케줄 삭제 완료: \(item.id)")
            } catch {
                Log.app.e("스케줄 삭제 실패: \(error)")
                // 삭제 실패 시 전체 스케줄 다시 저장으로 동기화
                await saveChanges()
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScheduleManagementView()
}
