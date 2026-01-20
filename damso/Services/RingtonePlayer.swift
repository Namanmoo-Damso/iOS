//
//  RingtonePlayer.swift
//  damso
//
//  Created by Claude Code on 2025-01-14.
//

import Foundation
import AVFoundation
import AudioToolbox

/// 전화 벨소리 재생 서비스
/// APNs 수신 시 벨소리 + 진동 반복 재생
@MainActor
final class RingtonePlayer: ObservableObject {

    // MARK: - Singleton

    static let shared = RingtonePlayer()

    // MARK: - Published Properties

    @Published private(set) var isPlaying: Bool = false

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?

    /// 벨소리 파일명 (확장자 제외)
    private let ringtoneFileName = "cellphone-ringing-6475"

    /// 벨소리 파일 확장자
    private let ringtoneFileExtension = "mp3"

    // MARK: - Init

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 다른 오디오와 함께 재생, 스피커 출력
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            debugLog("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Public Methods

    /// 벨소리 + 진동 시작
    func startRinging() {
        guard !isPlaying else {
            debugLog("Already playing, skipping")
            return
        }

        isPlaying = true

        // 오디오 재생 시작
        startAudioPlayback()

        // 진동 시작 (2초마다 반복)
        startVibration()

        debugLog("Ringtone started")
    }

    /// 벨소리 + 진동 중지
    func stopRinging() {
        guard isPlaying else { return }

        isPlaying = false

        // 오디오 중지
        audioPlayer?.stop()
        audioPlayer = nil

        // 진동 중지
        vibrationTimer?.invalidate()
        vibrationTimer = nil

        debugLog("Ringtone stopped")
    }

    // MARK: - Private Methods

    private func startAudioPlayback() {
        guard let url = Bundle.main.url(
            forResource: ringtoneFileName,
            withExtension: ringtoneFileExtension
        ) else {
            debugLog("Ringtone file not found: \(ringtoneFileName).\(ringtoneFileExtension)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // 무한 반복
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            debugLog("Audio playback started")
        } catch {
            debugLog("Failed to play ringtone: \(error)")
        }
    }

    private func startVibration() {
        // 즉시 진동 1회
        vibrateOnce()

        // 2초마다 진동 반복
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // 진동은 어느 스레드에서든 호출 가능
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    nonisolated private func vibrateOnce() {
        // 기본 진동 패턴
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[RingtonePlayer] \(message)")
        #endif
    }
}
