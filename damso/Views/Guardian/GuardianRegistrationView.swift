//
//  GuardianRegistrationView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 보호자 회원가입 폼
struct GuardianRegistrationView: View {
    /// 앱 상태
    @EnvironmentObject var appState: AppState

    /// 카카오에서 가져온 사용자 정보
    let kakaoUserInfo: KakaoUserInfo

    /// 등록 완료 콜백 (wardEmail 전달)
    let onRegistrationComplete: (String) -> Void

    /// 뒤로가기 콜백
    let onBack: (() -> Void)?

    @State private var wardEmail = ""
    @State private var wardPhoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var isSharing = false
    @State private var registeredGuardianId: String?
    @State private var pendingUser: UserMeResponse?

    @FocusState private var focusedField: Field?

    enum Field {
        case wardEmail
        case wardPhoneNumber
    }

    init(
        kakaoUserInfo: KakaoUserInfo,
        onRegistrationComplete: @escaping (String) -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.kakaoUserInfo = kakaoUserInfo
        self.onRegistrationComplete = onRegistrationComplete
        self.onBack = onBack
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 헤더
                    headerSection

                    // 카카오 프로필 섹션
                    kakaoProfileSection

                    // 어르신 정보 입력 섹션
                    wardInfoSection

                    // 에러 메시지
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // 가입 버튼
                    registerButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("보호자 등록")
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
        .alert("등록 완료", isPresented: $showSuccessAlert) {
            Button("어르신 초대하기") {
                shareInviteLink()
            }
            Button("나중에", role: .cancel) {
                completeRegistration()
            }
        } message: {
            Text("보호자 등록이 완료되었습니다.\n카카오톡으로 어르신을 초대해 보세요!")
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("보호자 정보를 등록해 주세요")
                .font(.title2)
                .fontWeight(.bold)

            Text("어르신 정보를 입력하시면\n자동으로 연결됩니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var kakaoProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내 정보")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // 프로필 이미지
                if let imageUrl = kakaoUserInfo.profileImageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(kakaoUserInfo.nickname ?? "사용자")
                        .font(.headline)

                    if let email = kakaoUserInfo.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("카카오 연동")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var wardInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("어르신 정보")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // 이메일 입력
                VStack(alignment: .leading, spacing: 6) {
                    Text("이메일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("어르신의 이메일 주소", text: $wardEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(emailValidationColor, lineWidth: wardEmail.isEmpty ? 0 : 1)
                        )
                        .focused($focusedField, equals: .wardEmail)

                    if !wardEmail.isEmpty && !isValidEmail {
                        Text("올바른 이메일 형식을 입력해 주세요")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // 전화번호 입력
                VStack(alignment: .leading, spacing: 6) {
                    Text("전화번호")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("어르신의 전화번호", text: $wardPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(phoneValidationColor, lineWidth: wardPhoneNumber.isEmpty ? 0 : 1)
                        )
                        .focused($focusedField, equals: .wardPhoneNumber)
                        .onChange(of: wardPhoneNumber) { _, newValue in
                            wardPhoneNumber = formatPhoneNumber(newValue)
                        }

                    if !wardPhoneNumber.isEmpty && !isValidPhoneNumber {
                        Text("올바른 전화번호 형식을 입력해 주세요")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var registerButton: some View {
        Button(action: register) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("가입하기")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid ? Color.blue : Color.gray)
            )
        }
        .disabled(!isFormValid || isLoading)
        .padding(.top, 8)
    }

    // MARK: - Validation

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: wardEmail)
    }

    private var isValidPhoneNumber: Bool {
        let digitsOnly = wardPhoneNumber.replacingOccurrences(of: "-", with: "")
        return digitsOnly.count >= 10 && digitsOnly.count <= 11 && digitsOnly.allSatisfy { $0.isNumber }
    }

    private var isFormValid: Bool {
        isValidEmail && isValidPhoneNumber
    }

    private var emailValidationColor: Color {
        if wardEmail.isEmpty { return .clear }
        return isValidEmail ? .green : .red
    }

    private var phoneValidationColor: Color {
        if wardPhoneNumber.isEmpty { return .clear }
        return isValidPhoneNumber ? .green : .red
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

    // MARK: - Registration Complete

    private func completeRegistration() {
        // 로그인 상태 업데이트
        if let user = pendingUser {
            appState.didLogin(user: user)
        }
        onRegistrationComplete(wardEmail)
    }

    // MARK: - Kakao Share

    private func shareInviteLink() {
        guard let guardianId = registeredGuardianId else {
            completeRegistration()
            return
        }

        Task {
            do {
                try await KakaoLinkService.shared.shareInviteLink(
                    guardianId: guardianId,
                    guardianName: kakaoUserInfo.nickname ?? "보호자",
                    wardEmail: wardEmail
                )
            } catch {
                // 공유 실패해도 진행
                print("[GuardianRegistrationView] 카카오 공유 실패: \(error.localizedDescription)")
            }
            // 공유 후 대시보드로 이동
            completeRegistration()
        }
    }

    // MARK: - Registration

    private func register() {
        focusedField = nil
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await AuthService.shared.registerGuardian(
                    wardEmail: wardEmail,
                    wardPhoneNumber: wardPhoneNumber.replacingOccurrences(of: "-", with: "")
                )

                // 응답에 user가 있으면 저장 (아직 didLogin 호출 안함 - Alert 먼저 표시)
                let user: UserMeResponse
                if let responseUser = response.user {
                    guard responseUser.nickname != nil else {
                        errorMessage = "사용자 닉네임 정보가 없습니다. 카카오 계정 설정을 확인해주세요."
                        isLoading = false
                        return
                    }
                    guard responseUser.email != nil else {
                        errorMessage = "사용자 이메일 정보가 없습니다. 카카오 계정 설정을 확인해주세요."
                        isLoading = false
                        return
                    }
                    user = responseUser
                } else {
                    // user가 없으면 서버에서 조회
                    let userInfo = try await AuthService.shared.getMe()
                    guard userInfo.nickname != nil else {
                        errorMessage = "사용자 닉네임 정보가 없습니다. 카카오 계정 설정을 확인해주세요."
                        isLoading = false
                        return
                    }
                    guard userInfo.email != nil else {
                        errorMessage = "사용자 이메일 정보가 없습니다. 카카오 계정 설정을 확인해주세요."
                        isLoading = false
                        return
                    }
                    user = userInfo
                }

                // Alert 표시를 위해 임시 저장 (didLogin은 Alert 버튼 클릭 시 호출)
                pendingUser = user
                registeredGuardianId = response.resolvedGuardianId
                showSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    GuardianRegistrationView(
        kakaoUserInfo: KakaoUserInfo(
            id: 12345,
            nickname: "홍길동",
            email: "hong@email.com",
            profileImageUrl: nil
        ),
        onRegistrationComplete: { wardEmail in print("Complete with \(wardEmail)") }
    )
    .environmentObject(AppState())
}
