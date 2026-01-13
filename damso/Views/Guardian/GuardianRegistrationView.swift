//
//  GuardianRegistrationView.swift
//  damso
//
//  보호자가 어르신 정보를 등록하는 화면
//

import SwiftUI

/// 보호자 어르신 등록 화면
struct GuardianRegistrationView: View {
    @EnvironmentObject var appState: AppState

    let kakaoUserInfo: KakaoUserInfo
    let onRegistrationComplete: (String, UserMeResponse) -> Void
    let onBack: (() -> Void)?
    let useDummyData: Bool
    let isAddingWard: Bool  // 기존 보호자가 어르신을 추가하는 모드

    // MARK: - State

    // 기본 정보
    @State private var wardName = ""
    @State private var selectedRelation: WardRelationType = .parent
    @State private var wardEmail = ""
    @State private var phoneNumber = ""
    @State private var birthDate = ""
    @State private var selectedGender: Gender = .male
    @State private var address = ""

    // AI 케어 정보
    @State private var medicalConditions = ""
    @State private var medications = ""

    // AI 전화 스케줄
    @State private var scheduleItems: [AICallScheduleItem] = [AICallScheduleItem()]
    @State private var isScheduleEnabled = true
    @State private var showScheduleSheet = false

    // UI 상태
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var registeredGuardianId: String?
    @State private var pendingUser: UserMeResponse?

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case wardName, wardEmail, phoneNumber, birthDate, address
        case medicalConditions, medications
    }

    init(
        kakaoUserInfo: KakaoUserInfo,
        onRegistrationComplete: @escaping (String, UserMeResponse) -> Void,
        onBack: (() -> Void)? = nil,
        useDummyData: Bool = false,
        isAddingWard: Bool = false
    ) {
        self.kakaoUserInfo = kakaoUserInfo
        self.onRegistrationComplete = onRegistrationComplete
        self.onBack = onBack
        self.useDummyData = useDummyData
        self.isAddingWard = isAddingWard
    }

    var body: some View {
        if isAddingWard {
            // 부모 NavigationStack 사용 (중첩 방지)
            mainContent
                .navigationTitle("어르신 추가")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(false)
        } else {
            // 자체 NavigationView 사용 (최초 등록 플로우)
            NavigationView {
                mainContent
                    .navigationTitle("어르신 등록")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if let onBack = onBack {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: onBack) {
                                    Image(systemName: "chevron.left")
                                }
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더 설명
                headerSection

                // 기본 정보 섹션
                basicInfoSection

                // AI 케어 정보 섹션
                aiCareInfoSection

                // AI 전화 스케줄 섹션
                aiCallScheduleSection

                // 에러 메시지
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // 등록 버튼
                registerButton
            }
            .padding()
        }
        .background(Color.creamRice)
        .sheet(isPresented: $showScheduleSheet) {
            AICallScheduleEditView(
                scheduleItems: $scheduleItems,
                isEnabled: $isScheduleEnabled
            )
        }
        .onAppear {
            if useDummyData {
                fillWithDummyData()
            }
        }
    }

    // MARK: - 더미 데이터 (개발용)

    private func fillWithDummyData() {
        wardName = "테스트어르신_\(AppConfig.selectedDeveloperName)"
        selectedRelation = .parent
        // StartView에서 선택한 개발자에 해당하는 어르신 이메일 자동 입력
        wardEmail = AppConfig.selectedDevWardEmail
        phoneNumber = "010-1234-5678"
        birthDate = "19450315"
        selectedGender = .female
        address = "서울시 강남구 테헤란로 123"
        medicalConditions = "고혈압, 당뇨"
        medications = "혈압약(아침), 당뇨약(아침/저녁)"
        isScheduleEnabled = true
        scheduleItems = [
            AICallScheduleItem(
                time: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date(),
                weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                isEnabled: true
            )
        ]
    }

    // MARK: - 헤더 섹션

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI가 맞춤형 대화를 할 수 있도록")
                .font(.body)
                .foregroundColor(.secondary)
            Text("어르신의 정보를 자세히 알려주세요.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - 기본 정보 섹션

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기본 정보")
                .font(.headline)

            VStack(spacing: 12) {
                // 성함 + 관계
                HStack(spacing: 12) {
                    // 성함
                    VStack(alignment: .leading, spacing: 6) {
                        Label("성함", systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("홍길동", text: $wardName)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                            .focused($focusedField, equals: .wardName)
                    }
                    .frame(maxWidth: .infinity)

                    // 관계
                    VStack(alignment: .leading, spacing: 6) {
                        Text("관계")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Menu {
                            ForEach(WardRelationType.allCases) { relation in
                                Button(relation.displayName) {
                                    selectedRelation = relation
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedRelation.displayName)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    .frame(width: 120)
                }

                // 이메일 (연동용) - 가장 중요!
                VStack(alignment: .leading, spacing: 6) {
                    Label("이메일 (연동용)", systemImage: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("elder@example.com", text: $wardEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .wardEmail)
                }

                // 휴대폰 번호
                VStack(alignment: .leading, spacing: 6) {
                    Label("휴대폰 번호", systemImage: "phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("010-1234-5678", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .phoneNumber)
                        .onChange(of: phoneNumber) { _, newValue in
                            phoneNumber = formatPhoneNumber(newValue)
                        }
                }

                // 생년월일 + 성별
                HStack(spacing: 12) {
                    // 생년월일
                    VStack(alignment: .leading, spacing: 6) {
                        Label("생년월일", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("YYYYMMDD", text: $birthDate)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                            .focused($focusedField, equals: .birthDate)
                            .onChange(of: birthDate) { _, newValue in
                                birthDate = String(newValue.filter { $0.isNumber }.prefix(8))
                            }
                    }

                    // 성별
                    VStack(alignment: .leading, spacing: 6) {
                        Text("성별")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 0) {
                            ForEach(Gender.allCases, id: \.rawValue) { gender in
                                Button {
                                    selectedGender = gender
                                } label: {
                                    Text(gender.displayName)
                                        .font(.subheadline)
                                        .fontWeight(selectedGender == gender ? .semibold : .regular)
                                        .foregroundColor(selectedGender == gender ? .primary : .secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            selectedGender == gender
                                                ? Color(.tertiarySystemBackground)
                                                : Color.clear
                                        )
                                }
                            }
                        }
                        .background(Color(.quaternarySystemFill))
                        .cornerRadius(10)
                    }
                    .frame(width: 140)
                }

                // 거주지 주소
                VStack(alignment: .leading, spacing: 6) {
                    Label("거주지 주소", systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("주소 검색...", text: $address)
                        .textContentType(.fullStreetAddress)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .address)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - AI 케어 정보 섹션

    private var aiCareInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 케어 정보 (선택)")
                    .font(.headline)
                Text("입력해주시면 AI가 안부 전화 시 해당 내용을 체크합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                // 기저질환
                VStack(alignment: .leading, spacing: 6) {
                    Label("기저질환 / 앓고 계신 병", systemImage: "cross.case")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("예: 고혈압, 당뇨, 관절염", text: $medicalConditions)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .medicalConditions)
                }

                // 복용 중인 약
                VStack(alignment: .leading, spacing: 6) {
                    Label("복용 중인 약", systemImage: "pills")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("예: 혈압약(아침), 수면제", text: $medications)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .medications)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - AI 전화 스케줄 섹션

    private var aiCallScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 안부 전화 스케줄 (선택)")
                        .font(.headline)
                    Text("설정한 시간에 AI가 어르신께 안부 전화를 드립니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isScheduleEnabled)
                    .labelsHidden()
            }

            if isScheduleEnabled {
                VStack(spacing: 12) {
                    ForEach(scheduleItems) { item in
                        ScheduleItemRow(item: item) {
                            showScheduleSheet = true
                        }
                    }

                    Button {
                        showScheduleSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("스케줄 추가")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 등록 버튼

    private var registerButton: some View {
        Button(action: register) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isAddingWard ? "어르신 추가하기" : "저장하고 연동하기")
                        .font(.headline)
                    Image(systemName: "chevron.right")
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid ? Color(hex: "1F2937") : Color.gray)
            )
        }
        .disabled(!isFormValid || isLoading)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    // MARK: - Validation

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: wardEmail)
    }

    private var isValidPhoneNumber: Bool {
        let digitsOnly = phoneNumber.replacingOccurrences(of: "-", with: "")
        return digitsOnly.isEmpty || (digitsOnly.count >= 10 && digitsOnly.count <= 11 && digitsOnly.allSatisfy { $0.isNumber })
    }

    private var isValidBirthDate: Bool {
        birthDate.count == 8 && birthDate.allSatisfy { $0.isNumber }
    }

    private var isFormValid: Bool {
        !wardName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail &&
        isValidBirthDate
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.replacingOccurrences(of: "-", with: "").filter { $0.isNumber }

        if digitsOnly.count <= 3 {
            return digitsOnly
        } else if digitsOnly.count <= 7 {
            let prefix = String(digitsOnly.prefix(3))
            let suffix = String(digitsOnly.dropFirst(3))
            return "\(prefix)-\(suffix)"
        } else {
            let prefix = String(digitsOnly.prefix(3))
            let middle = String(digitsOnly.dropFirst(3).prefix(4))
            let suffix = String(digitsOnly.dropFirst(7).prefix(4))
            return "\(prefix)-\(middle)-\(suffix)"
        }
    }

    // MARK: - Registration

    private func register() {
        focusedField = nil
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 기본 정보 구성
                let basicInfo = WardBasicInfo(
                    name: wardName,
                    relation: selectedRelation,
                    phoneNumber: phoneNumber.replacingOccurrences(of: "-", with: ""),
                    birthDate: birthDate,
                    gender: selectedGender,
                    address: address
                )

                // AI 케어 정보 구성 (입력이 있을 때만)
                let aiCareInfo: AICarInfo? = (medicalConditions.isEmpty && medications.isEmpty)
                    ? nil
                    : AICarInfo(medicalConditions: medicalConditions, medications: medications)

                // 스케줄 구성
                let schedule: AICallSchedule? = isScheduleEnabled && !scheduleItems.isEmpty
                    ? AICallSchedule(items: scheduleItems, isEnabled: true)
                    : nil

                let user: UserMeResponse

                if useDummyData {
                    // 개발용 API 호출 (카카오 로그인 없이)
                    let authResponse = try await AuthService.shared.registerDevGuardian(
                        wardEmail: wardEmail,
                        wardPhoneNumber: phoneNumber.replacingOccurrences(of: "-", with: ""),
                        wardBasicInfo: basicInfo,
                        aiCareInfo: aiCareInfo,
                        callSchedule: schedule,
                        guardianNickname: "테스트보호자_\(AppConfig.selectedDeveloperName)",
                        guardianEmail: nil
                    )

                    guard let responseUser = authResponse.user else {
                        errorMessage = "사용자 정보를 받지 못했습니다."
                        isLoading = false
                        return
                    }
                    user = responseUser
                } else {
                    // 일반 API 호출
                    let response = try await AuthService.shared.registerGuardian(
                        wardEmail: wardEmail,
                        wardPhoneNumber: phoneNumber.replacingOccurrences(of: "-", with: ""),
                        wardBasicInfo: basicInfo,
                        aiCareInfo: aiCareInfo,
                        callSchedule: schedule
                    )

                    // 사용자 정보 처리
                    if let responseUser = response.user {
                        guard responseUser.nickname != nil else {
                            errorMessage = "사용자 닉네임 정보가 없습니다."
                            isLoading = false
                            return
                        }
                        user = responseUser
                    } else {
                        let userInfo = try await AuthService.shared.getMe()
                        guard userInfo.nickname != nil else {
                            errorMessage = "사용자 닉네임 정보가 없습니다."
                            isLoading = false
                            return
                        }
                        user = userInfo
                    }
                }

                pendingUser = user
                completeRegistration()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func completeRegistration() {
        guard let user = pendingUser else { return }
        appState.didLogin(user: user)
        onRegistrationComplete(wardEmail, user)
    }
}

// MARK: - Schedule Item Row

struct ScheduleItemRow: View {
    let item: AICallScheduleItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.timeString)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(item.weekdaysSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview

#Preview {
    GuardianRegistrationView(
        kakaoUserInfo: KakaoUserInfo(
            id: 12345,
            nickname: "홍길동",
            email: "hong@email.com",
            profileImageUrl: nil
        ),
        onRegistrationComplete: { _, _ in }
    )
    .environmentObject(AppState())
}
