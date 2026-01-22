//
//  VideoResolutionIndicator.swift
//  damso
//
//  현재 비디오 해상도를 표시하는 인디케이터
//

import SwiftUI

/// 현재 비디오 해상도 인디케이터 (예: 720p, 1080p)
struct VideoResolutionIndicator: View {
    let resolution: String  // "1280x720" 형식
    
    var body: some View {
        Text(resolutionLabel)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(resolutionColor.opacity(0.8))
            .clipShape(Capsule())
    }
    
    /// 해상도를 "720p", "1080p" 형태로 변환
    private var resolutionLabel: String {
        // "1280x720" -> "720p"
        // "1920x1080" -> "1080p"
        // "640x360" -> "360p"
        
        let components = resolution.split(separator: "x")
        guard components.count == 2,
              let height = Int(components[1]) else {
            return resolution  // 파싱 실패 시 원본 반환
        }
        
        return "\(height)p"
    }
    
    /// 해상도에 따른 색상
    private var resolutionColor: Color {
        let components = resolution.split(separator: "x")
        guard components.count == 2,
              let height = Int(components[1]) else {
            return .gray
        }
        
        switch height {
        case 1080...:
            return .green  // 1080p 이상
        case 720..<1080:
            return .blue   // 720p
        case 540..<720:
            return .cyan   // 540p
        case 360..<540:
            return .orange // 360p
        default:
            return .red    // 360p 미만
        }
    }
}

// MARK: - Preview

#Preview("Various Resolutions") {
    VStack(spacing: 16) {
        VideoResolutionIndicator(resolution: "1920x1080")
        VideoResolutionIndicator(resolution: "1280x720")
        VideoResolutionIndicator(resolution: "960x540")
        VideoResolutionIndicator(resolution: "640x360")
        VideoResolutionIndicator(resolution: "N/A")
    }
    .padding()
    .background(Color.black)
}
