//
//  VideoStatsLogger.swift
//  damso
//
//  LiveKit 통화 중 네트워크 전송 통계 로깅 서비스
//  iOS 시스템 API를 사용하여 실제 전송/수신 바이트 측정
//

import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

/// 네트워크 인터페이스 통계 (시스템 레벨)
private struct NetworkInterfaceStats {
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let packetsSent: UInt64
    let packetsReceived: UInt64
}

/// LiveKit 통화 중 네트워크 통계를 주기적으로 로깅하는 서비스
/// iOS 시스템 API를 사용하여 실제 전송량 측정
@MainActor
final class VideoStatsLogger: ObservableObject {
    
    static let shared = VideoStatsLogger()
    
    // MARK: - Published Stats (실제 측정값)
    
    @Published private(set) var uploadBitrate: Double = 0.0         // Mbps (업로드)
    @Published private(set) var downloadBitrate: Double = 0.0       // Mbps (다운로드)
    @Published private(set) var totalBytesSent: UInt64 = 0          // 총 전송 바이트
    @Published private(set) var totalBytesReceived: UInt64 = 0      // 총 수신 바이트
    @Published private(set) var packetsSent: UInt64 = 0             // 전송 패킷 수
    @Published private(set) var packetsReceived: UInt64 = 0         // 수신 패킷 수
    @Published private(set) var connectionQuality: String = "Unknown"
    @Published private(set) var resolution: String = "N/A"
    
    // 추정된 품질 (LiveKit SDK가 unknown일 때 사용)
    @Published private(set) var estimatedQuality: ConnectionQuality = .unknown
    
    // MARK: - Internal State
    
    private var loggingTimer: Timer?
    private var room: Room?
    private let logInterval: TimeInterval = 3.0 // 3초마다 로깅
    
    private var previousBytesSent: UInt64 = 0
    private var previousBytesReceived: UInt64 = 0
    private var previousTimestamp: Date?
    private var sessionStartBytesSent: UInt64 = 0
    private var sessionStartBytesReceived: UInt64 = 0
    
    // 네트워크 품질 기반 자동 조정
    private var poorQualityCount: Int = 0
    private let poorQualityThreshold: Int = 1  // 1회만 감지해도 즉시 대응 (jitter 대응)
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 로깅 시작
    func startLogging(room: Room) {
        stopLogging()
        self.room = room
        
        // 네트워크 타입별 초기 최적화
        optimizeForNetworkType(room: room)
        
        // 세션 시작 시점의 네트워크 카운터 저장
        let initialStats = getNetworkStats()
        sessionStartBytesSent = initialStats.bytesSent
        sessionStartBytesReceived = initialStats.bytesReceived
        previousBytesSent = initialStats.bytesSent
        previousBytesReceived = initialStats.bytesReceived
        previousTimestamp = Date()
        
        debugLog("📊 [STATS] Started logging (interval: \(logInterval)s)")
        debugLog("📊 [STATS] Initial network counters - Sent: \(formatBytes(initialStats.bytesSent)), Received: \(formatBytes(initialStats.bytesReceived))")
        
        loggingTimer = Timer.scheduledTimer(withTimeInterval: logInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logStats()
            }
        }
    }
    
    /// 로깅 중지
    func stopLogging() {
        loggingTimer?.invalidate()
        loggingTimer = nil
        room = nil
        
        // 세션 종료 시 총 전송량 로그
        if totalBytesSent > 0 || totalBytesReceived > 0 {
            debugLog("📊 [STATS] Session ended - Total Sent: \(formatBytes(totalBytesSent)), Total Received: \(formatBytes(totalBytesReceived))")
        }
        
        resetStats()
        debugLog("📊 [STATS] Stopped logging")
    }
    
    // MARK: - Private Methods
    
    private func resetStats() {
        uploadBitrate = 0.0
        downloadBitrate = 0.0
        totalBytesSent = 0
        totalBytesReceived = 0
        packetsSent = 0
        packetsReceived = 0
        connectionQuality = "Unknown"
        resolution = "N/A"
        previousBytesSent = 0
        previousBytesReceived = 0
        previousTimestamp = nil
        sessionStartBytesSent = 0
        sessionStartBytesReceived = 0
    }
    
    private func logStats() {
        guard let room = room else { return }
        
        let now = Date()
        let elapsedSeconds = previousTimestamp.map { now.timeIntervalSince($0) } ?? logInterval
        
        // 시스템 네트워크 통계 가져오기
        let currentStats = getNetworkStats()
        
        // 비트레이트 계산 (bytes -> Mbps)
        let deltaBytesSent = currentStats.bytesSent - previousBytesSent
        let deltaBytesReceived = currentStats.bytesReceived - previousBytesReceived
        
        uploadBitrate = Double(deltaBytesSent) * 8.0 / elapsedSeconds / 1_000_000.0     // Mbps
        downloadBitrate = Double(deltaBytesReceived) * 8.0 / elapsedSeconds / 1_000_000.0 // Mbps
        
        // 세션 시작 이후 총 전송량
        totalBytesSent = currentStats.bytesSent - sessionStartBytesSent
        totalBytesReceived = currentStats.bytesReceived - sessionStartBytesReceived
        packetsSent = currentStats.packetsSent
        packetsReceived = currentStats.packetsReceived
        
        // LiveKit 연결 품질
        updateConnectionQuality(room: room)
        
        // 비디오 해상도
        updateVideoResolution(room: room)
        
        // 네트워크 품질 기반 자동 조정
        adjustVideoQualityIfNeeded(room: room)
        
        // 실제 통계 기반 품질 추정
        estimateQualityFromStats()
        
        // 이전 값 업데이트
        previousBytesSent = currentStats.bytesSent
        previousBytesReceived = currentStats.bytesReceived
        previousTimestamp = now
        
        // 콘솔 로그 출력
        printStatsLog()
    }
    
    private func updateConnectionQuality(room: Room) {
        let quality = room.localParticipant.connectionQuality
        let previousQuality = connectionQuality
        
        switch quality {
        case .excellent: connectionQuality = "Excellent"
        case .good: connectionQuality = "Good"
        case .poor: connectionQuality = "Poor"
        case .lost: connectionQuality = "Lost"
        case .unknown: connectionQuality = "Unknown"
        @unknown default: connectionQuality = "Unknown"
        }
        
        // 품질 변경 시 로그 출력
        if previousQuality != connectionQuality {
            debugLog("📶 [QUALITY] Changed: \(previousQuality) → \(connectionQuality)")
        }
    }
    
    private func updateVideoResolution(room: Room) {
        if let videoPublication = room.localParticipant.localVideoTracks.first,
           let videoTrack = videoPublication.track as? LocalVideoTrack,
           let dimensions = videoTrack.dimensions {
            let width = Int(dimensions.width)
            let height = Int(dimensions.height)
            
            // 가로/세로 중 큰 값이 width, 작은 값이 height가 되도록 정규화
            let normalizedWidth = max(width, height)
            let normalizedHeight = min(width, height)
            
            resolution = "\(normalizedWidth)x\(normalizedHeight)"
            debugLog("📐 [RESOLUTION] Raw: \(width)x\(height), Normalized: \(normalizedWidth)x\(normalizedHeight) → \(normalizedHeight)p")
        }
    }
    
    /// 네트워크 품질이 poor일 때 자동으로 해상도 낮춤
    private func adjustVideoQualityIfNeeded(room: Room) {
        let quality = room.localParticipant.connectionQuality
        
        if quality == .poor {
            poorQualityCount += 1
            
            // 3회 연속 poor면 해상도 낮춤
            if poorQualityCount >= poorQualityThreshold {
                debugLog("⚠️ [QUALITY] Poor connection detected \(poorQualityCount) times, reducing quality")
                Task {
                    await reduceVideoQuality(room: room)
                }
                poorQualityCount = 0  // 리셋
            }
        } else if quality == .excellent || quality == .good {
            // 연결이 좋아지면 카운터 리셋
            if poorQualityCount > 0 {
                debugLog("✅ [QUALITY] Connection improved, resetting counter")
                poorQualityCount = 0
            }
        }
    }
    
    /// 해상도를 단계적으로 낮춤
    private func reduceVideoQuality(room: Room) async {
        guard let videoTrack = room.localParticipant.localVideoTracks.first?.track as? LocalVideoTrack,
              let currentDimensions = videoTrack.dimensions else {
            return
        }
        
        let currentWidth = Int(currentDimensions.width)
        
        // 현재 해상도에 따라 낮춤
        let newDimensions: Dimensions
        if currentWidth >= 1920 {
            newDimensions = .h1080_169
            debugLog("📉 [QUALITY] Reducing: 1920p → 1080p")
        } else if currentWidth >= 1280 {
            newDimensions = .h720_169
            debugLog("📉 [QUALITY] Reducing: 1080p → 720p")
        } else if currentWidth >= 1024 {
            newDimensions = .h540_169
            debugLog("📉 [QUALITY] Reducing: 720p → 540p")
        } else if currentWidth >= 640 {
            newDimensions = .h360_169
            debugLog("📉 [QUALITY] Reducing: 540p → 360p")
        } else {
            debugLog("⚠️ [QUALITY] Already at minimum resolution (360p)")
            return
        }
        
        let captureOptions = CameraCaptureOptions(dimensions: newDimensions)
        do {
            try await room.localParticipant.setCamera(enabled: true, captureOptions: captureOptions)
            debugLog("✅ [QUALITY] Resolution reduced successfully")
        } catch {
            debugLog("❌ [QUALITY] Failed to reduce resolution: \(error)")
        }
    }
    
    /// 실제 네트워크 통계를 기반으로 품질 추정
    /// LiveKit SDK의 connectionQuality가 unknown일 때 대체값으로 사용
    private func estimateQualityFromStats() {
        let networkMonitor = NetworkMonitor.shared
        let isWiFi = networkMonitor.connectionType == .wifi || networkMonitor.connectionType == .wired
        
        // WiFi: 높은 기준, Cellular: 낮은 기준
        if isWiFi {
            // WiFi 환경: 4Mbps+ = excellent, 2.5~4Mbps = good, 1~2.5Mbps = poor
            if uploadBitrate >= 4.0 {
                estimatedQuality = .excellent
            } else if uploadBitrate >= 2.5 {
                estimatedQuality = .good
            } else if uploadBitrate >= 1.0 {
                estimatedQuality = .poor
            } else if uploadBitrate > 0.1 {
                estimatedQuality = .poor
            } else {
                estimatedQuality = .unknown
            }
        } else {
            // Cellular 환경: 2Mbps+ = excellent, 1~2Mbps = good, 0.5~1Mbps = poor
            if uploadBitrate >= 2.0 {
                estimatedQuality = .excellent
            } else if uploadBitrate >= 1.0 {
                estimatedQuality = .good
            } else if uploadBitrate >= 0.5 {
                estimatedQuality = .poor
            } else if uploadBitrate > 0.1 {
                estimatedQuality = .poor
            } else {
                estimatedQuality = .unknown
            }
        }
        
        #if DEBUG
        if connectionQuality == "Unknown" && estimatedQuality != .unknown {
            print("[VideoStatsLogger] 📊 Using estimated quality: \\(estimatedQuality) (upload: \\(String(format: \"%.2f\", uploadBitrate))Mbps, network: \\(networkMonitor.connectionType))")
        }
        #endif
    }
    
    /// 네트워크 타입(WiFi/Cellular)에 따른 초기 최적화
    private func optimizeForNetworkType(room: Room) {
        // LiveKit adaptive bitrate에 맡김 - 수동 조정 제거
        // degradationPreference: .balanced가 자동으로 네트워크 상태 감지하여
        // 해상도/프레임레이트를 최적화함
        debugLog("📊 [OPTIMIZE] Using LiveKit adaptive bitrate (no manual intervention)")
    }
    
    /// 시스템 네트워크 인터페이스 통계 가져오기 (모든 인터페이스 합산)
    private func getNetworkStats() -> NetworkInterfaceStats {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return NetworkInterfaceStats(bytesSent: 0, bytesReceived: 0, packetsSent: 0, packetsReceived: 0)
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var totalBytesSent: UInt64 = 0
        var totalBytesReceived: UInt64 = 0
        var totalPacketsSent: UInt64 = 0
        var totalPacketsReceived: UInt64 = 0
        
        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            
            // 활성화되어 있고 루프백이 아닌 인터페이스만 집계
            if isUp && !isLoopback {
                if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalBytesSent += UInt64(data.pointee.ifi_obytes)
                    totalBytesReceived += UInt64(data.pointee.ifi_ibytes)
                    totalPacketsSent += UInt64(data.pointee.ifi_opackets)
                    totalPacketsReceived += UInt64(data.pointee.ifi_ipackets)
                }
            }
            
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        
        return NetworkInterfaceStats(
            bytesSent: totalBytesSent,
            bytesReceived: totalBytesReceived,
            packetsSent: totalPacketsSent,
            packetsReceived: totalPacketsReceived
        )
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", Double(bytes) / 1_000_000_000.0)
        } else if bytes >= 1_000_000 {
            return String(format: "%.2f MB", Double(bytes) / 1_000_000.0)
        } else if bytes >= 1_000 {
            return String(format: "%.2f KB", Double(bytes) / 1_000.0)
        } else {
            return "\(bytes) B"
        }
    }
    
    private func printStatsLog() {
        // 읽기 쉽게 개별 라인으로 출력
        debugLog("📊 [NETWORK STATS]")
        debugLog("├─ ⬆️ Upload: \(String(format: "%.2f", uploadBitrate)) Mbps")
        debugLog("├─ ⬇️ Download: \(String(format: "%.2f", downloadBitrate)) Mbps")
        debugLog("├─ 📤 Total Sent: \(formatBytes(totalBytesSent))")
        debugLog("├─ 📥 Total Received: \(formatBytes(totalBytesReceived))")
        debugLog("├─ 🎥 Resolution: \(resolution)")
        debugLog("└─ 📶 Quality: \(connectionQuality)")
        
        // OSLog는 한 줄 요약으로 기록 (필터링 용도)
        Log.network.i("Network Stats: Up \(String(format: "%.2f", uploadBitrate))Mbps, Down \(String(format: "%.2f", downloadBitrate))Mbps, Sent \(formatBytes(totalBytesSent))")
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[VideoStatsLogger] \(message)")
        #endif
    }
}
#endif
