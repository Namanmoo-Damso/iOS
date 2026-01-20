//
//  Constants+Sensor.swift
//  damso
//
//  센서 관련 상수 정의
//

import Foundation

// MARK: - 센서 관련 상수

extension Numbers {
    
    /// 모션 센서 상수
    enum Motion {
        /// 센서 업데이트 주기 (Hz)
        static let updateRate: Double = 50.0
        /// 데이터 채널 전송 주기 (초)
        static let dataChannelSendInterval: TimeInterval = 0.1
        /// 최근 가속도 기록 개수
        static let recentAccelerationsCount: Int = 10
    }
    
    /// 낙상 감지 상수
    enum FallDetection {
        /// 자유낙하 임계값 (g)
        static let freefallThreshold: Float = 0.3
        /// 충격 임계값 (g)
        static let impactThreshold: Float = 2.5
        /// 회전 임계값 (rad/s)
        static let rotationThreshold: Float = 5.0
        /// 위험도 - 정상 최대값
        static let riskNormalMax: Float = 0.5
        /// 위험도 - 주의 최대값
        static let riskCautionMax: Float = 0.7
        /// 위험도 - 위급 (0.7 이상)
        static let riskCriticalMin: Float = 0.7
        /// 기여도 - 자유낙하
        static let freefallContribution: Float = 0.25
        /// 기여도 - 충격
        static let impactContribution: Float = 0.25
        /// 기여도 - 회전
        static let rotationContribution: Float = 0.20
        /// 기여도 - 소리
        static let audioContribution: Float = 0.20
        /// 급격한 하강 임계값 (화면 비율)
        static let rapidDescentThreshold: Float = 0.25
        /// 급격한 하강 시간 윈도우 (초)
        static let rapidDescentTimeWindow: Float = 0.5
    }
    
    /// 오디오 관련 상수
    enum Audio {
        /// 오디오 시각화 스무딩 계수
        static let visualizerSmoothingFactor: Float = 0.3
        /// 말하기 시뮬레이션 타이머 간격 (초)
        static let speakingTimerInterval: TimeInterval = 0.05
        /// 말하기 레벨 최소값
        static let speakingLevelMin: Float = 0.3
        /// 말하기 레벨 최대값
        static let speakingLevelMax: Float = 0.7
        /// RMS 감지 임계값
        static let rmsDetectionThreshold: Float = 0.005
        /// RMS 정규화 승수
        static let rmsNormalizationMultiplier: Float = 5.0
    }
    
    /// VAD (Voice Activity Detection) 상수
    enum VAD {
        /// VAD 임계값 (기본값)
        static let threshold: Float = 0.5
        /// 타겟 샘플레이트 (Hz)
        static let targetSampleRate: Int = 16000
        /// 오디오 청크 크기 (샘플 수)
        static let chunkSize: Int = 4096
    }
    
    /// 얼굴 인식 상수
    enum FaceDetection {
        /// 스무딩 계수 (0 = 이전값 유지, 1 = 새값만 사용)
        static let smoothingFactor: CGFloat = 0.7
        /// FPS 측정 타이머 간격 (초)
        static let fpsTimerInterval: TimeInterval = 1.0
    }
    
    /// 센서 데이터 집계 상수
    enum SensorAggregation {
        /// 기본 집계 주기 (Hz)
        static let defaultRate: Double = 10.0
        /// 최소 집계 주기 (Hz)
        static let minRate: Double = 1.0
        /// 최대 집계 주기 (Hz)
        static let maxRate: Double = 30.0
    }
}
