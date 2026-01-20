//
//  OnboardingViewModel.swift
//  damso
//
//  온보딩 및 권한 요청 ViewModel
//

import Foundation
import AVFoundation
import UserNotifications
import Combine
import UIKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRequesting: Bool = false
    @Published var allPermissionsGranted: Bool = false
    
    // MARK: - Dependencies
    
    // LocationService는 싱글톤 사용 (Repository 패턴 적용 시 LocationRepository로 래핑 가능)
    // 여기서는 기존 LocationService 사용
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    func requestAllPermissions(userType: UserType, completion: @escaping () -> Void) {
        isRequesting = true
        
        Task {
            // 1. 카메라 권한
            await requestCameraAccess()
            
            // 2. 마이크 권한
            await requestMicrophoneAccess()
            
            // 3. 알림 권한
            await requestNotificationAccess()
            
            // 4. 위치 권한 (어르신만)
            if userType == .ward {
                // LocationService.shared.requestAuthorization() 호출
                // 비동기 처리가 아니므로 바로 호출
                LocationService.shared.requestAuthorization()
            }
            
            // 완료 플래그 저장
            UserDefaults.standard.permissionOnboardingCompleted = true
            
            await MainActor.run {
                isRequesting = false
                completion()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func requestCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return }
        
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                continuation.resume()
            }
        }
    }
    
    private func requestMicrophoneAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .notDetermined else { return }
        
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                continuation.resume()
            }
        }
    }
    
    private func requestNotificationAccess() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                continuation.resume()
            }
        }
    }
}
