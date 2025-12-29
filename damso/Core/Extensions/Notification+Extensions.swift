//
//  Notification+Extensions.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation

extension Notification.Name {
    /// 탭 네비게이션 알림 (userInfo["tab"]: "home" | "report" | "settings")
    static let navigateToTab = Notification.Name("navigateToTab")
}
