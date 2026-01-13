//
//  Color+Hex.swift
//  damso
//
//  Hex 문자열로 Color 생성하는 확장 및 브랜드 컬러 정의
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Nature Palette (Damso Brand Colors)

    /// Primary - Damso Green: 메인 브랜드 컬러, 강조 및 핵심 액션 버튼
    static let damsoGreen = Color(hex: "8FA963")

    /// Secondary - Soft Sprout: 보조 강조 및 뱃지
    static let softSprout = Color(hex: "C2D5A8")

    /// Foreground - Deep Moss: 텍스트 기본 컬러 (검정 대용)
    static let deepMoss = Color(hex: "4A5D23")

    /// Background - Cream Rice: 눈이 편안한 미색 배경
    static let creamRice = Color(hex: "F7F9F2")

    // MARK: - Semantic Colors

    /// Warning - Amber: 주의가 필요한 상태
    static let damsoWarning = Color(hex: "F59E0B")  // Amber-500

    /// Danger - Red: 응급 상황 또는 심각한 위험
    static let damsoDanger = Color(hex: "EF4444")   // Red-500

    /// Safe - Emerald: 정상 및 안정 상태
    static let damsoSafe = Color(hex: "10B981")     // Emerald-500
}
