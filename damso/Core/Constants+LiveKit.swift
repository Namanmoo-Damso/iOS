//
//  Constants+LiveKit.swift
//  damso
//
//  LiveKit 및 통화 관련 상수 정의
//

import Foundation

// MARK: - LiveKit 관련 상수

extension Numbers {
    
    /// LiveKit 서비스 상수
    enum LiveKit {
        /// 기본 원격 오디오 볼륨
        static let defaultRemoteAudioVolume: Double = 1.0
        /// 음소거 시 볼륨
        static let mutedVolume: Double = 0.0
        /// 재연결 타이머 간격 (초)
        static let reconnectTimerInterval: TimeInterval = 1.0
        /// 원격 연결 해제 타이머 간격 (초)
        static let remoteDisconnectTimerInterval: TimeInterval = 1.0
        /// API 요청 타임아웃 (초)
        static let apiTimeout: TimeInterval = 30.0
        /// 재시도 지연 시간 (초)
        static let retryDelay: TimeInterval = 2.0
    }
    
    /// 벨소리 관련 상수
    enum Ringtone {
        /// 기본 볼륨
        static let defaultVolume: Float = 1.0
        /// 진동 간격 (초)
        static let vibrationInterval: TimeInterval = 2.0
    }
    
    /// 자막/트랜스크립션 상수
    enum Transcription {
        /// 자막 폴백 타임아웃 (초)
        static let subtitleFallbackTimeout: TimeInterval = 2.0
    }
}

// MARK: - 통화 관련 문자열 상수

extension Strings {
    
    /// DataChannel 토픽
    enum DataChannelTopics {
        static let sensorData = "sensor_data"
        static let faceDetection = "face_detection"
        static let careAlert = "care_alert"
        static let acknowledgeAlert = "acknowledge_alert"
        static let transcription = "transcription"
        static let motionData = "motion_data"
    }
}
