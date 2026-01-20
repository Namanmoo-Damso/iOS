//
//  AICallScheduleEditView.swift
//  damso
//
//  AI 전화 스케줄 편집 화면
//

import SwiftUI

/// AI 전화 스케줄 편집 시트
struct AICallScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var scheduleItems: [AICallScheduleItem]
    @Binding var isEnabled: Bool

    @State private var editingIndex: Int?

    private var showDetailSheet: Binding<Bool> {
        Binding(
            get: {
                guard let idx = editingIndex else { return false }
                return idx < scheduleItems.count
            },
            set: { if !$0 { editingIndex = nil } }
        )
    }

    var body: some View {
        NavigationView {
            List {
                // 전체 활성화 토글
                Section {
                    Toggle("AI 안부 전화 활성화", isOn: $isEnabled)
                }

                // 스케줄 목록
                if isEnabled {
                    Section("스케줄 목록") {
                        ForEach(scheduleItems.indices, id: \.self) { index in
                            ScheduleEditRowView(
                                item: scheduleItems[index],
                                isEnabled: safeIsEnabledBinding(at: index),
                                onEdit: {
                                    editingIndex = index
                                }
                            )
                        }
                        .onDelete(perform: deleteItems)

                        Button {
                            let newItem = AICallScheduleItem()
                            scheduleItems.append(newItem)
                            editingIndex = scheduleItems.count - 1
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
            .navigationTitle("스케줄 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: showDetailSheet) {
                if let index = editingIndex, index < scheduleItems.count {
                    ScheduleDetailEditView(item: safeItemBinding(at: index))
                }
            }
        }
    }

    // 안전한 isEnabled 바인딩 - bounds 체크 포함
    private func safeIsEnabledBinding(at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard index < scheduleItems.count else { return false }
                return scheduleItems[index].isEnabled
            },
            set: { newValue in
                guard index < scheduleItems.count else { return }
                scheduleItems[index].isEnabled = newValue
            }
        )
    }

    // 안전한 item 바인딩 - bounds 체크 포함
    private func safeItemBinding(at index: Int) -> Binding<AICallScheduleItem> {
        Binding(
            get: {
                guard index < scheduleItems.count else { return AICallScheduleItem() }
                return scheduleItems[index]
            },
            set: { newValue in
                guard index < scheduleItems.count else { return }
                scheduleItems[index] = newValue
            }
        )
    }

    private func deleteItems(at offsets: IndexSet) {
        // 삭제할 항목이 현재 편집 중이면 편집 취소
        if let editingIndex = editingIndex, offsets.contains(editingIndex) {
            self.editingIndex = nil
        }
        scheduleItems.remove(atOffsets: offsets)
    }
}

// MARK: - Schedule Edit Row View

struct ScheduleEditRowView: View {
    let item: AICallScheduleItem
    @Binding var isEnabled: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.slotTimeString)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(item.weekdaysSummary)
                    Text("·")
                    Text("최대 \(AICallScheduleItem.maxCallDurationMinutes)분")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Schedule Detail Edit View

struct ScheduleDetailEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var item: AICallScheduleItem

    // 시간/분 Picker 값
    @State private var selectedHour: Int = 10
    @State private var selectedMinuteIndex: Int = 0

    private let validMinutes = AICallScheduleItem.validMinutes  // [0, 10, 20, 30, 40, 50]

    var body: some View {
        NavigationView {
            Form {
                // 슬롯 시간 선택
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("전화 슬롯 시간")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            // 시간 Picker
                            Picker("시", selection: $selectedHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(String(format: "%02d", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()

                            Text(":")
                                .font(.title2)
                                .fontWeight(.medium)

                            // 분 Picker (10분 단위)
                            Picker("분", selection: $selectedMinuteIndex) {
                                ForEach(0..<validMinutes.count, id: \.self) { index in
                                    Text(String(format: "%02d", validMinutes[index])).tag(index)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                        }
                        .frame(height: 120)

                        // 슬롯 정보 표시
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(slotDisplayString)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .padding(.top, 8)

                        Text("슬롯 내 최대 \(AICallScheduleItem.maxCallDurationMinutes)분 통화 가능")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // 요일 선택
                Section("요일") {
                    ForEach(Weekday.allCases) { weekday in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            HStack {
                                Text(weekday.fullName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if item.weekdays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                // 빠른 선택
                Section("빠른 선택") {
                    Button("평일 (월~금)") {
                        item.weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                    }
                    Button("주말 (토, 일)") {
                        item.weekdays = [.saturday, .sunday]
                    }
                    Button("매일") {
                        item.weekdays = Set(Weekday.allCases)
                    }
                }
            }
            .navigationTitle("스케줄 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        // Picker 값을 item에 반영
                        item.slotStartHour = selectedHour
                        item.slotStartMinute = validMinutes[selectedMinuteIndex]
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 초기값 설정
                selectedHour = item.slotStartHour
                selectedMinuteIndex = validMinutes.firstIndex(of: item.slotStartMinute) ?? 0
            }
        }
    }

    /// 슬롯 표시 문자열 (예: "10:00 ~ 10:10")
    private var slotDisplayString: String {
        let startMinute = validMinutes[selectedMinuteIndex]
        let duration = AICallScheduleItem.slotDurationMinutes

        let endHour: Int
        let endMinute: Int
        if startMinute + duration >= 60 {
            endHour = selectedHour + 1
            endMinute = (startMinute + duration) % 60
        } else {
            endHour = selectedHour
            endMinute = startMinute + duration
        }

        return String(format: "%02d:%02d ~ %02d:%02d", selectedHour, startMinute, endHour, endMinute)
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if item.weekdays.contains(weekday) {
            item.weekdays.remove(weekday)
        } else {
            item.weekdays.insert(weekday)
        }
    }
}

// MARK: - Preview