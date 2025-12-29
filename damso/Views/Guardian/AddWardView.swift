//
//  AddWardView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 추가 화면
struct AddWardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var wardEmail = ""
    @State private var wardPhoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !wardEmail.isEmpty && !wardPhoneNumber.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이메일", text: $wardEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("전화번호", text: $wardPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } header: {
                    Text("어르신 정보")
                } footer: {
                    Text("어르신이 카카오 로그인 시 사용할 이메일과 전화번호를 입력해주세요.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("어르신 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addWard()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }

    private func addWard() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let authService = AuthService()
                _ = try await authService.registerGuardian(
                    wardEmail: wardEmail,
                    wardPhoneNumber: wardPhoneNumber
                )

                // 사용자 정보 새로고침
                await appState.checkAuthStatus()

                dismiss()
            } catch {
                errorMessage = "등록에 실패했습니다. 다시 시도해주세요."
            }

            isLoading = false
        }
    }
}

#Preview {
    AddWardView()
        .environmentObject(AppState())
}
