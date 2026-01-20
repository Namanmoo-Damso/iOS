//
//  PersonFallDetector.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//
//  카메라 기반 사람 낙상 감지 서비스
//  얼굴 랜드마크 추적을 통해 급격한 낙하나 갑작스러운 실종 감지
//

import Foundation
import Combine
import CoreGraphics

#if canImport(LiveKit)
import LiveKit

/// 사람 낙상 감지 서비스
/// FaceLandmarkDetector의 얼굴 위치 데이터를 분석하여 낙상 감지
@MainActor
final class PersonFallDetector: ObservableObject {

    // MARK: - Singleton

    static let shared = PersonFallDetector()

    // MARK: - Published Properties

    /// 감지 활성화 상태
    @Published private(set) var isActive: Bool = false

    /// 마지막 감지된 얼굴 Y 위치 (0.0 = 상단, 1.0 = 하단)
    @Published private(set) var lastFaceY: Float = 0.5

    /// 현재 낙상 경고 상태
    @Published private(set) var isFallWarning: Bool = false

    // MARK: - Configuration

    /// Y축 급강하 임계값 (정규화 좌표, 0-1)
    /// 0.3 = 화면 30% 이상 아래로 급격히 이동
    var rapidDescentThreshold: Float = 0.25

    /// 급강하 감지 시간 창 (초)
    /// 이 시간 내에 threshold 이상 하강하면 낙상으로 판정
    var rapidDescentTimeWindow: Float = 0.5

    /// 얼굴 실종 후 낙상 판정 시간 (초)
    /// 얼굴이 갑자기 사라지고 이 시간 동안 복구되지 않으면 낙상 의심
    var faceDisappearanceTimeout: Float = 2.0

    /// 경고 쿨다운 (중복 방지, 초)
    var warningCooldown: Float = 10.0

    /// 최소 추적 시간 (초)
    /// 안정적인 추적 후에만 낙상 감지 시작
    var minimumTrackingTime: Float = 2.0

    /// 얼굴 실종 감지 활성화 여부
    /// false로 설정 시 얼굴이 사라져도 낙상 알림을 보내지 않음
    var faceDisappearanceDetectionEnabled: Bool = false

    // MARK: - Private Properties

    private let faceLandmarkDetector = FaceLandmarkDetector.shared
    private let careAlertService = CareAlertService.shared

    private var cancellables = Set<AnyCancellable>()

    // 얼굴 위치 기록 (시간, Y좌표)
    private var facePositionHistory: [(timestamp: Date, y: Float)] = []
    private let maxHistoryCount = 30  // 최대 30 프레임 저장

    // 추적 상태
    private var trackingStartTime: Date?
    private var lastFaceDetectedTime: Date?
    private var lastWarningTime: Date = .distantPast
    private var wasTrackingFace: Bool = false

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 감지 시작
    func start() {
        guard !isActive else {
            debugLog("Already active, skipping start")
            return
        }

        isActive = true
        trackingStartTime = nil
        facePositionHistory.removeAll()
        wasTrackingFace = false

        setupSubscriptions()

        debugLog("✅ Person fall detection started")
    }

    /// 감지 중지
    func stop() {
        guard isActive else { return }

        isActive = false
        cancellables.removeAll()
        facePositionHistory.removeAll()
        trackingStartTime = nil
        lastFaceDetectedTime = nil
        wasTrackingFace = false
        isFallWarning = false

        // 얼굴 Y 좌표 초기화 (다음 통화 시 이전 값 잔류 방지)
        lastFaceY = 0.5

        debugLog("Person fall detection stopped")
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // 얼굴 랜드마크 스트림 구독
        faceLandmarkDetector.landmarksStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                self?.processLandmarks(landmarks)
            }
            .store(in: &cancellables)

        // 얼굴 감지 상태 구독
        faceLandmarkDetector.$isFaceDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDetected in
                self?.handleFaceDetectionStateChange(isDetected)
            }
            .store(in: &cancellables)

        // 주기적 얼굴 실종 체크
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkFaceDisappearance()
            }
            .store(in: &cancellables)
    }

    /// 랜드마크 데이터 처리
    private func processLandmarks(_ landmarks: [CGPoint]) {
        guard !landmarks.isEmpty else { return }

        let now = Date()

        // 추적 시작 시간 기록
        if trackingStartTime == nil {
            trackingStartTime = now
        }

        lastFaceDetectedTime = now

        // 얼굴 중심 Y좌표 계산 (랜드마크들의 평균 Y)
        let averageY = landmarks.reduce(0.0) { $0 + $1.y } / CGFloat(landmarks.count)
        let currentY = Float(averageY)

        lastFaceY = currentY

        // 위치 기록에 추가
        facePositionHistory.append((timestamp: now, y: currentY))

        // 오래된 기록 제거
        if facePositionHistory.count > maxHistoryCount {
            facePositionHistory.removeFirst()
        }

        // 급강하 감지 (최소 추적 시간 경과 후)
        if let startTime = trackingStartTime,
           Float(now.timeIntervalSince(startTime)) >= minimumTrackingTime {
            checkRapidDescent(currentY: currentY, now: now)
        }
    }

    /// 얼굴 감지 상태 변화 처리
    private func handleFaceDetectionStateChange(_ isDetected: Bool) {
        let wasTracking = wasTrackingFace
        wasTrackingFace = isDetected

        if wasTracking && !isDetected {
            // 얼굴이 갑자기 사라짐
            debugLog("⚠️ Face suddenly disappeared!")
        } else if !wasTracking && isDetected {
            // 얼굴 다시 감지됨
            debugLog("✅ Face reappeared")
            // 기존 기록 초기화 (새로운 추적 시작)
            facePositionHistory.removeAll()
            trackingStartTime = Date()
        }
    }

    /// 급강하 감지
    private func checkRapidDescent(currentY: Float, now: Date) {
        // 시간 창 내의 기록만 필터링
        let timeWindowStart = now.addingTimeInterval(-Double(rapidDescentTimeWindow))
        let recentHistory = facePositionHistory.filter { $0.timestamp >= timeWindowStart }

        guard recentHistory.count >= 2 else { return }

        // 시간 창 시작점의 Y좌표
        guard let startPosition = recentHistory.first else { return }

        // Y좌표 변화량 (하강 = 양수, 상승 = 음수)
        // 화면 좌표계: Y=0이 상단, Y=1이 하단
        let yDelta = currentY - startPosition.y
        let deltaTime = Float(now.timeIntervalSince(startPosition.timestamp))

        // 급격한 하강 감지 (임계값 이상 + 아래 방향)
        if yDelta >= rapidDescentThreshold && deltaTime > 0 {
            triggerFallWarning(
                detectionType: .rapidDescent,
                faceYDelta: yDelta,
                deltaTime: deltaTime,
                lastPosition: currentY
            )
        }
    }

    /// 얼굴 실종 체크
    private func checkFaceDisappearance() {
        // 얼굴 실종 감지 비활성화 시 스킵
        guard faceDisappearanceDetectionEnabled else { return }
        guard isActive, wasTrackingFace == false else { return }

        // 충분한 추적 시간이 있었는지 확인
        guard let startTime = trackingStartTime,
              Float(Date().timeIntervalSince(startTime)) >= minimumTrackingTime else {
            return
        }

        // 얼굴이 마지막으로 감지된 시간 체크
        guard let lastDetected = lastFaceDetectedTime else { return }

        let timeSinceLastDetection = Float(Date().timeIntervalSince(lastDetected))

        if timeSinceLastDetection >= faceDisappearanceTimeout {
            triggerFallWarning(
                detectionType: .faceDisappeared,
                faceYDelta: nil,
                deltaTime: timeSinceLastDetection,
                lastPosition: lastFaceY
            )

            // 한 번 알림 후 리셋 (연속 알림 방지)
            lastFaceDetectedTime = nil
        }
    }

    /// 낙상 경고 발생
    private func triggerFallWarning(
        detectionType: PersonFallAlertData.PersonFallDetectionType,
        faceYDelta: Float?,
        deltaTime: Float,
        lastPosition: Float
    ) {
        // 쿨다운 확인
        let timeSinceLastWarning = Float(Date().timeIntervalSince(lastWarningTime))
        guard timeSinceLastWarning >= warningCooldown else {
            debugLog("Fall warning skipped (cooldown)")
            return
        }

        isFallWarning = true
        lastWarningTime = Date()

        debugLog("🚨 Person fall detected! Type: \(detectionType), yDelta: \(faceYDelta ?? 0), time: \(deltaTime)s")

        // useThresholdBasedAlerts가 false면 care_alert 전송 안함
        // SensorStreamService가 원시 데이터를 전송하고 Agent가 판단
        guard careAlertService.useThresholdBasedAlerts else {
            debugLog("⚙️ Threshold-based alerts disabled - skipping care_alert (SensorStreamService sends raw data)")
            // 경고 상태만 리셋
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.isFallWarning = false
                }
            }
            return
        }

        // CareAlertService를 통해 알림 전송 (useThresholdBasedAlerts == true일 때만)
        Task {
            do {
                try await careAlertService.sendPersonFallAlert(
                    detectionType: detectionType,
                    faceYDelta: faceYDelta,
                    deltaTime: deltaTime,
                    lastFacePosition: PersonFallAlertData.NormalizedPosition(
                        x: 0.5,  // X는 현재 추적하지 않으므로 중앙값 사용
                        y: lastPosition
                    )
                )

                // 경고 상태 리셋 (3초 후)
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.isFallWarning = false
                }
            } catch {
                debugLog("Failed to send person fall alert: \(error)")
                isFallWarning = false
            }
        }
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        // Face 로그 비활성화
        // #if DEBUG
        // print("[PersonFallDetector] \(message)")
        // #endif
    }
}

#else

// LiveKit 미사용 시 스텁
@MainActor
final class PersonFallDetector: ObservableObject {
    static let shared = PersonFallDetector()
    @Published private(set) var isActive: Bool = false
    @Published private(set) var isFallWarning: Bool = false
    private init() {}
    func start() {}
    func stop() {}
}

#endif
