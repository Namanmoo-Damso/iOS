//
//  CallSessionManager.swift
//  damso
//
//  통화 세션 중 센서 및 보조 서비스의 생명주기를 관리하는 매니저
//  LiveKitService에서 분리되어 SRP를 준수
//

import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

/// 통화 세션 중 활성화되는 모든 센서/보조 서비스를 관리
/// LiveKitService는 순수하게 WebRTC 연결만 담당하고,
/// 이 매니저가 세션 시작/종료 시 필요한 서비스들을 조율합니다.
@MainActor
final class CallSessionManager: ObservableObject {
    
    static let shared = CallSessionManager()
    
    // MARK: - Session State
    
    @Published private(set) var isSessionActive: Bool = false
    
    // MARK: - Managed Services (References)
    
    private let transcription = TranscriptionManager.shared
    private let faceDetectionChannel = FaceDetectionDataChannel.shared
    private let sensorAggregator = SensorDataAggregator.shared
    private let careAlertService = CareAlertService.shared
    private let sensorStreamService = SensorStreamService.shared
    private let userAudioMonitor = UserAudioLevelMonitor.shared
    private let personFallDetector = PersonFallDetector.shared
    private let motionSensorService = MotionSensorService.shared
    private let faceLandmarkDetector = FaceLandmarkDetector.shared
    private let emotionAnalyzer = EmotionAnalyzer.shared
    private let videoStatsLogger = VideoStatsLogger.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 통화 세션 시작 시 모든 센서/보조 서비스 활성화
    /// - Parameters:
    ///   - room: LiveKit Room 인스턴스
    ///   - wardId: 어르신 ID (케어 알림용)
    func startSession(room: Room, wardId: String?) {
        guard !isSessionActive else {
            debugLog("⚠️ Session already active, skipping start")
            return
        }
        
        debugLog("🎬 [SESSION] Starting all services...")
        
        // 1. Transcription (자막)
        transcription.start()
        debugLog("🎬 [SESSION] Transcription started")
        
        // 2. Face Detection Data Channel
        faceDetectionChannel.setRoom(room)
        debugLog("🎬 [SESSION] FaceDetectionChannel connected")
        
        // 4. Sensor Aggregator (얼굴 + 모션 통합)
        sensorAggregator.start(enableMotionSensor: true)
        debugLog("🎬 [SESSION] SensorAggregator started")
        
        // 5. Care Alert Service (낙상/음성/감정 알림)
        careAlertService.start(room: room, wardId: wardId)
        debugLog("🎬 [SESSION] CareAlertService started (wardId: \(wardId ?? "unknown"))")
        
        // 6. Sensor Stream Service (매초 raw data 전송)
        sensorStreamService.start(room: room)
        debugLog("🎬 [SESSION] SensorStreamService started")
        
        // 7. User Audio Monitor (큰 소리 감지)
        if let localAudioTrack = room.localParticipant.localAudioTracks.first?.track as? LocalAudioTrack {
            userAudioMonitor.startMonitoring(track: localAudioTrack)
            debugLog("🎬 [SESSION] UserAudioMonitor started")
        } else {
            debugLog("🎬 [SESSION] ⚠️ LocalAudioTrack not found for monitoring")
        }
        
        // 8. Person Fall Detector (카메라 기반 사람 낙상 감지)
        personFallDetector.start()
        debugLog("🎬 [SESSION] PersonFallDetector started")
        
        // 9. Motion Sensor Service (기기 낙상 감지)
        motionSensorService.startCollection(sendToDataChannel: false)
        debugLog("🎬 [SESSION] MotionSensorService started")
        
        // 10. Face Landmark Detector (감정 분석용)
        if let localVideoTrack = room.localParticipant.localVideoTracks.first?.track as? LocalVideoTrack {
            faceLandmarkDetector.startDetection(for: localVideoTrack)
            debugLog("🎬 [SESSION] FaceLandmarkDetector started")
        } else {
            debugLog("🎬 [SESSION] ⚠️ LocalVideoTrack not found for face detection")
        }
        
        // 11. Emotion Analyzer (감정 분석)
        emotionAnalyzer.start()
        debugLog("🎬 [SESSION] EmotionAnalyzer started")
        
        // 12. Video Stats Logger (네트워크 통계 로깅)
        videoStatsLogger.startLogging(room: room)
        debugLog("🎬 [SESSION] VideoStatsLogger started")
        
        isSessionActive = true
        debugLog("🎬 [SESSION] All services started successfully")
    }
    
    /// 통화 세션 종료 시 모든 센서/보조 서비스 비활성화
    /// - Parameter room: LiveKit Room 인스턴스 (트랙 해제용)
    func stopSession(room: Room?) {
        guard isSessionActive else {
            debugLog("⚠️ Session not active, skipping stop")
            return
        }
        
        debugLog("🎬 [SESSION] Stopping all services...")
        
        // 1. Transcription
        transcription.stop()
        debugLog("🎬 [SESSION] Transcription stopped")
        
        // 2. Face Detection Data Channel
        faceDetectionChannel.setRoom(nil)
        debugLog("🎬 [SESSION] FaceDetectionChannel disconnected")
        
        // 4. Sensor Aggregator
        sensorAggregator.stop()
        debugLog("🎬 [SESSION] SensorAggregator stopped")
        
        // 5. Care Alert Service
        careAlertService.stop()
        debugLog("🎬 [SESSION] CareAlertService stopped")
        
        // 6. Sensor Stream Service
        sensorStreamService.stop()
        debugLog("🎬 [SESSION] SensorStreamService stopped")
        
        // 7. User Audio Monitor
        if let room = room,
           let localAudioTrack = room.localParticipant.localAudioTracks.first?.track as? LocalAudioTrack {
            userAudioMonitor.stopMonitoring(track: localAudioTrack)
            debugLog("🎬 [SESSION] UserAudioMonitor stopped")
        }
        
        // 8. Person Fall Detector
        personFallDetector.stop()
        debugLog("🎬 [SESSION] PersonFallDetector stopped")
        
        // 9. Motion Sensor Service
        motionSensorService.stopCollection()
        debugLog("🎬 [SESSION] MotionSensorService stopped")
        
        // 10. Face Landmark Detector
        if let room = room,
           let localVideoTrack = room.localParticipant.localVideoTracks.first?.track as? LocalVideoTrack {
            faceLandmarkDetector.stopDetection(for: localVideoTrack)
            debugLog("🎬 [SESSION] FaceLandmarkDetector stopped")
        }
        
        // 11. Emotion Analyzer
        emotionAnalyzer.stop()
        debugLog("🎬 [SESSION] EmotionAnalyzer stopped")
        
        // 12. Video Stats Logger
        videoStatsLogger.stopLogging()
        debugLog("🎬 [SESSION] VideoStatsLogger stopped")
        
        isSessionActive = false
        debugLog("🎬 [SESSION] All services stopped successfully")
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CallSessionManager] \(message)")
        #endif
    }
}
#endif
