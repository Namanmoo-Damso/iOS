//
//  Logger.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
import os

/// 앱 전역 로거 - OSLog 기반
enum Log {
    // MARK: - Subsystem
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.damso"

    // MARK: - Category Loggers
    static let app = Logger(subsystem: subsystem, category: "App")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let kakao = Logger(subsystem: subsystem, category: "Kakao")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let livekit = Logger(subsystem: subsystem, category: "LiveKit")
    static let push = Logger(subsystem: subsystem, category: "Push")
    static let location = Logger(subsystem: subsystem, category: "Location")
    static let call = Logger(subsystem: subsystem, category: "Call")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}

// MARK: - Logger Extension for convenience

extension Logger {
    /// Debug 레벨 로그 (개발용)
    func d(_ message: String) {
        self.debug("\(message)")
    }

    /// Info 레벨 로그 (일반 정보)
    func i(_ message: String) {
        self.info("\(message)")
    }

    /// Warning 레벨 로그 (경고)
    func w(_ message: String) {
        self.warning("\(message)")
    }

    /// Error 레벨 로그 (에러)
    func e(_ message: String) {
        self.error("\(message)")
    }

    /// Fault 레벨 로그 (치명적 에러)
    func f(_ message: String) {
        self.fault("\(message)")
    }
}
