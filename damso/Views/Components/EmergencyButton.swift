//
//  EmergencyButton.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 비상 연락 버튼
struct EmergencyButton: View {
    @State private var showConfirmation = false
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            showConfirmation = true
        } label: {
            Image(systemName: "light.beacon.max.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.red)
                .clipShape(Circle())
                .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isLoading)
        .confirmationDialog(
            "비상 연락",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("비상 연락 보내기", role: .destructive) {
                triggerEmergency()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("보호자와 관계기관에 즉시 연락이 전송됩니다.")
        }
        .alert("비상 연락 완료", isPresented: $showSuccessAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("보호자에게 알림이 전송되었습니다.\n곧 연락이 갈 예정입니다.")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "비상 연락 전송에 실패했습니다.")
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Private Methods

    private func triggerEmergency() {
        isLoading = true

        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        Task {
            do {
                try await EmergencyService.shared.triggerEmergency()

                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true

                    // 성공 햅틱
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true

                    // 에러 햅틱
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
}

#Preview {
    EmergencyButton()
        .padding()
}
