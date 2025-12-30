//
//  MyNetworkStatusView.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import SwiftUI
#if canImport(LiveKit)
import LiveKit

/// 내 네트워크 상태 표시 뷰
struct MyNetworkStatusView: View {
    let connectionQuality: ConnectionQuality
    let connectionType: NetworkConnectionType

    var body: some View {
        HStack(spacing: 6) {
            // Connection type icon
            Image(systemName: connectionTypeIcon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))

            // Quality bars
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: index))
                        .frame(width: 3, height: barHeight(for: index))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
        )
    }

    // MARK: - Private Properties

    private var connectionTypeIcon: String {
        switch connectionType {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "cable.connector"
        case .unknown: return "questionmark.circle"
        }
    }

    private var activeBars: Int {
        switch connectionQuality {
        case .excellent: return 4
        case .good: return 3
        case .poor: return 2
        case .lost: return 0
        case .unknown: return 1
        @unknown default: return 1
        }
    }

    private var qualityColor: Color {
        switch connectionQuality {
        case .excellent, .good: return .green
        case .poor: return .orange
        case .lost: return .red
        case .unknown: return .gray
        @unknown default: return .gray
        }
    }

    // MARK: - Private Methods

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [4, 6, 9, 12]
        return heights[index]
    }

    private func barColor(for index: Int) -> Color {
        let activeCount = activeBars
        if index < activeCount {
            return qualityColor
        }
        return Color.white.opacity(0.3)
    }
}
#endif
