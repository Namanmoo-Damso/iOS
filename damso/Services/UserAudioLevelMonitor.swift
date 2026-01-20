//
//  UserAudioLevelMonitor.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//
//  AVAudioEngine inputNode tap 방식으로 로컬 마이크 레벨 수집
//  (LiveKit LocalAudioTrack의 AudioRenderer는 콜백이 호출되지 않음)
//

import Foundation
import AVFoundation
import Accelerate
import Combine

#if canImport(LiveKit)
import LiveKit

// MARK: - Error Types

enum AudioMonitorError: Error {
    case engineCreationFailed
    case engineNotInitialized
}

/// 사용자 마이크 음량 모니터링 서비스
/// AVAudioEngine inputNode tap을 사용하여 로컬 마이크 오디오 캡처
/// VAD(Voice Activity Detection)와 연동하여 음성일 때만 경고 발생
@MainActor
final class UserAudioLevelMonitor: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = UserAudioLevelMonitor()

    // MARK: - Published Properties

    /// 현재 오디오 레벨 (0.0 ~ 1.0 정규화)
    @Published private(set) var currentLevel: Float = 0

    /// 현재 데시벨 (-160 ~ 0 dB)
    @Published private(set) var currentDecibel: Float = -160

    /// 경고 상태
    @Published private(set) var isWarningActive: Bool = false

    /// 모니터링 활성화 상태
    @Published private(set) var isMonitoring: Bool = false

    /// 현재 음성 감지 상태 (VAD 기반)
    @Published private(set) var isSpeaking: Bool = false

    /// VAD 확률 (0.0 ~ 1.0)
    @Published private(set) var vadProbability: Float = 0

    // MARK: - Configuration

    /// 경고 임계값 (정규화 레벨, 0.0 ~ 1.0)
    var warningThreshold: Float = 0.7

    /// 데시벨 임계값 (-160 ~ 0 dB)
    /// -20dB = 비교적 큰 소리, -10dB = 매우 큰 소리
    var decibelThreshold: Float = -15

    /// 경고 발생까지 지속해야 하는 시간 (초)
    var warningDuration: Float = 0.3

    /// 경고 쿨다운 (중복 방지, 초)
    var warningCooldown: Float = 3.0

    /// VAD 사용 여부 (false면 기존 볼륨 기반만 사용)
    var useVAD: Bool = true

    // MARK: - Private Properties

    private let careAlertService = CareAlertService.shared
    private let vadService = VadService.shared

    private var isActiveUnsafe: Bool = false
    private var thresholdExceededStartTime: Date?
    private var lastWarningTime: Date = .distantPast

    // 스무딩
    private var smoothedLevel: Float = 0
    private let smoothingFactor: Float = 0.3

    // AVAudioEngine for input tap
    private var audioEngine: AVAudioEngine?
    private let tapBusIndex: AVAudioNodeBus = 0
    private let tapBufferSize: AVAudioFrameCount = 4096

    // VAD 구독
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private override init() {
        super.init()
        setupVADSubscription()
    }

    // MARK: - VAD Subscription

    private func setupVADSubscription() {
        // VAD 상태 구독
        vadService.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                self?.isSpeaking = speaking
            }
            .store(in: &cancellables)

        vadService.$probability
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prob in
                self?.vadProbability = prob
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 모니터링 시작 (AVAudioEngine inputNode tap 사용)
    /// - Parameter track: LiveKit LocalAudioTrack (호환성을 위해 유지, 실제로는 사용하지 않음)
    func startMonitoring(track: LocalAudioTrack) {
        guard !isMonitoring else { return }

        isMonitoring = true
        isActiveUnsafe = true

        // VAD 시작
        if useVAD {
            vadService.start()
        }

        debugLog("✅ Started monitoring local audio (VAD: \(useVAD ? "enabled" : "disabled"))")

        // AVAudioEngine을 LiveKit 초기화 완료 후 별도 큐에서 지연 시작
        // LiveKit의 오디오 파이프라인과 충돌 방지
        let audioQueue = DispatchQueue(label: "com.damso.audioMonitor", qos: .userInteractive)
        audioQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            do {
                try self?.setupAudioEngineOnQueue()
            } catch {
                Task { @MainActor in
                    self?.debugLog("❌ Failed to start audio monitoring: \(error)")
                }
            }
        }
    }

    /// 모니터링 중지
    func stopMonitoring(track: LocalAudioTrack) {
        guard isMonitoring else { return }

        stopAudioEngine()

        // VAD 중지
        vadService.stop()

        isMonitoring = false
        isActiveUnsafe = false
        currentLevel = 0
        currentDecibel = -160
        isWarningActive = false
        isSpeaking = false
        vadProbability = 0
        thresholdExceededStartTime = nil

        debugLog("Stopped monitoring local audio")
    }

    // MARK: - AVAudioEngine Setup

    /// 별도 큐에서 AVAudioEngine 설정 및 시작 (nonisolated)
    /// LiveKit 오디오 파이프라인과의 dispatch queue 충돌 방지
    nonisolated private func setupAudioEngineOnQueue() throws {
        let engine = AVAudioEngine()
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        Task { @MainActor [weak self] in
            self?.debugLog("📢 Input format: \(inputFormat)")
        }
        
        // inputNode에 tap 설치
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        // AVAudioSession은 LiveKit이 이미 설정했으므로 건드리지 않음
        try engine.start()
        
        // MainActor에서 engine 참조 저장
        Task { @MainActor [weak self] in
            self?.audioEngine = engine
            self?.debugLog("🎤 AVAudioEngine started on background queue")
        }
    }

    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            throw AudioMonitorError.engineCreationFailed
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: tapBusIndex)

        debugLog("📢 Input format: \(inputFormat)")

        // inputNode에 tap 설치
        inputNode.installTap(
            onBus: tapBusIndex,
            bufferSize: tapBufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }

    private func startAudioEngine() throws {
        guard let engine = audioEngine else {
            throw AudioMonitorError.engineNotInitialized
        }

        // AVAudioSession은 LiveKit이 이미 설정했으므로 건드리지 않음
        try engine.start()
        debugLog("🎤 AVAudioEngine started")
    }

    private func stopAudioEngine() {
        guard let engine = audioEngine else { return }

        engine.inputNode.removeTap(onBus: tapBusIndex)
        engine.stop()
        audioEngine = nil

        debugLog("🎤 AVAudioEngine stopped")
    }

    // MARK: - Audio Processing

    /// 오디오 버퍼 처리 (nonisolated → MainActor로 전달)
    nonisolated private func processAudioBuffer(_ pcmBuffer: AVAudioPCMBuffer) {
        guard let floatData = pcmBuffer.floatChannelData else { return }
        let frameLength = Int(pcmBuffer.frameLength)
        guard frameLength > 0 else { return }

        // RMS (Root Mean Square) 계산
        var rms: Float = 0
        vDSP_rmsqv(floatData[0], 1, &rms, vDSP_Length(frameLength))

        // RMS를 정규화된 레벨로 변환 (0.0 ~ 1.0)
        // 음성은 일반적으로 0.01 ~ 0.3 범위
        let normalizedLevel = min(1.0, rms * 5.0)

        // RMS를 데시벨로 변환
        // dB = 20 * log10(rms)
        let decibel: Float
        if rms > 0 {
            decibel = 20.0 * log10(rms)
        } else {
            decibel = -160
        }

        // VAD용으로 Float 배열 복사 (Sendable 이슈 방지)
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
        let sampleRate = pcmBuffer.format.sampleRate

        // MainActor로 전달 (레벨 업데이트 + VAD 처리)
        Task { @MainActor [weak self] in
            self?.updateLevels(normalized: normalizedLevel, decibel: decibel)

            // VAD에 샘플 전달
            await self?.vadService.processAudioSamples(samples, sampleRate: sampleRate)
        }
    }

    /// 레벨 업데이트 및 경고 확인
    private func updateLevels(normalized: Float, decibel: Float) {
        // 스무딩 적용
        smoothedLevel = smoothedLevel * (1 - smoothingFactor) + normalized * smoothingFactor
        currentLevel = smoothedLevel
        currentDecibel = decibel

        // 임계값 초과 확인
        checkThreshold(level: normalized, decibel: decibel)
    }

    /// 임계값 확인 및 경고 발생
    /// VAD 사용 시: 음성 + 큰 소리일 때만 경고
    /// VAD 미사용 시: 큰 소리만으로 경고 (기존 동작)
    private func checkThreshold(level: Float, decibel: Float) {
        let isOverVolumeThreshold = level >= warningThreshold || decibel >= decibelThreshold

        // VAD 사용 시: 음성이 감지되고 + 볼륨이 높을 때만 경고
        // VAD 미사용 시: 볼륨만으로 판단
        let shouldTrigger: Bool
        if useVAD {
            shouldTrigger = isOverVolumeThreshold && isSpeaking
        } else {
            shouldTrigger = isOverVolumeThreshold
        }

        if shouldTrigger {
            if thresholdExceededStartTime == nil {
                thresholdExceededStartTime = Date()
            }

            // 지정된 시간 이상 지속되면 경고
            if let startTime = thresholdExceededStartTime {
                let duration = Float(Date().timeIntervalSince(startTime))

                if duration >= warningDuration && !isWarningActive {
                    triggerWarning(level: level, decibel: decibel, duration: duration)
                }
            }
        } else {
            // 조건 미충족 시 리셋
            thresholdExceededStartTime = nil
            isWarningActive = false
        }
    }

    /// 경고 발생
    private func triggerWarning(level: Float, decibel: Float, duration: Float) {
        // 쿨다운 확인
        let timeSinceLastWarning = Float(Date().timeIntervalSince(lastWarningTime))
        guard timeSinceLastWarning >= warningCooldown else { return }

        isWarningActive = true
        lastWarningTime = Date()

        debugLog("⚠️ Loud voice detected! Level: \(level), dB: \(decibel)")

        // CareAlertService를 통해 알림 전송
        Task {
            do {
                try await careAlertService.sendLoudVoiceAlert(
                    level: level,
                    decibel: decibel,
                    duration: duration,
                    possibleCause: determineCause(level: level, decibel: decibel)
                )
            } catch {
                debugLog("Failed to send loud voice alert: \(error)")
            }
        }
    }

    /// 원인 추정
    private func determineCause(level: Float, decibel: Float) -> LoudVoiceAlertData.PossibleCause {
        // 매우 큰 소리 (-5dB 이상) = 비명일 가능성
        if decibel >= -5 || level >= 0.9 {
            return .scream
        }
        // 큰 소리 = 큰 목소리
        else if decibel >= -15 || level >= 0.7 {
            return .loudSpeech
        }
        return .unknown
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[UserAudioMonitor] \(message)")
        #endif
    }
}

// MARK: - Audio Renderer

/// LocalAudioTrack용 AudioRenderer
final class UserAudioRenderer: NSObject, AudioRenderer {

    private let onBuffer: @Sendable (AVAudioPCMBuffer) -> Void

    init(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        self.onBuffer = onBuffer
        super.init()
    }

    nonisolated func render(pcmBuffer: AVAudioPCMBuffer) {
        onBuffer(pcmBuffer)
    }
}

#else

// LiveKit 미사용 시 스텁
@MainActor
final class UserAudioLevelMonitor: ObservableObject {
    static let shared = UserAudioLevelMonitor()
    @Published private(set) var currentLevel: Float = 0
    @Published private(set) var currentDecibel: Float = -160
    @Published private(set) var isWarningActive: Bool = false
    @Published private(set) var isMonitoring: Bool = false
    private init() {}
}

#endif
