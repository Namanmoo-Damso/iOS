//
//  NotificationSettingsViewModel.swift
//  damso
//
//  알림 설정 ViewModel
//

import Foundation
import Combine

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var callNotificationsEnabled: Bool = true
    @Published var alertNotificationsEnabled: Bool = true
    @Published var reportNotificationsEnabled: Bool = true
    @Published var isSaving: Bool = false
    @Published var showSaveSuccess: Bool = false
    
    // MARK: - Dependencies
    
    private let pushNotificationService: PushNotificationService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(pushNotificationService: PushNotificationService) {
        self.pushNotificationService = pushNotificationService
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        callNotificationsEnabled = UserDefaults.standard.bool(forKey: "callNotificationsEnabled")
        alertNotificationsEnabled = UserDefaults.standard.bool(forKey: "alertNotificationsEnabled")
        reportNotificationsEnabled = UserDefaults.standard.bool(forKey: "reportNotificationsEnabled")
        
        // 기본값이 false인 경우 true로 설정 (최초 실행 시)
        if !UserDefaults.standard.bool(forKey: "notificationSettingsInitialized") {
            callNotificationsEnabled = true
            alertNotificationsEnabled = true
            reportNotificationsEnabled = true
            UserDefaults.standard.set(true, forKey: "notificationSettingsInitialized")
        }
    }
    
    func saveSettings() async {
        isSaving = true
        
        UserDefaults.standard.set(callNotificationsEnabled, forKey: "callNotificationsEnabled")
        UserDefaults.standard.set(alertNotificationsEnabled, forKey: "alertNotificationsEnabled")
        UserDefaults.standard.set(reportNotificationsEnabled, forKey: "reportNotificationsEnabled")
        
        // 서버에 설정 동기화
        try? await pushNotificationService.updateNotificationSettings(
            callReminder: callNotificationsEnabled,
            callComplete: alertNotificationsEnabled,
            healthAlert: reportNotificationsEnabled
        )
        
        isSaving = false
        showSaveSuccess = true
        
        // 2초 후 성공 메시지 숨김
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        showSaveSuccess = false
    }
    
    func toggleCallNotifications(_ enabled: Bool) {
        callNotificationsEnabled = enabled
    }
    
    func toggleAlertNotifications(_ enabled: Bool) {
        alertNotificationsEnabled = enabled
    }
    
    func toggleReportNotifications(_ enabled: Bool) {
        reportNotificationsEnabled = enabled
    }
}
