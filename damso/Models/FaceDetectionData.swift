//
//  FaceDetectionData.swift
//  damso
//
//  Created by Claude Code on 2025-01-09.
//

import Foundation
import CoreGraphics

/// Face detection 결과 데이터 모델
/// LiveKit Data Channel을 통해 전송됨
struct FaceDetectionData: Codable, Sendable {
    /// 감지 타임스탬프 (Unix time milliseconds)
    let timestamp: Int64

    /// 감지된 얼굴 목록
    let faces: [DetectedFace]

    /// 프레임 크기 (정규화 기준)
    let frameSize: FrameSize

    /// 감지 신뢰도 임계값
    let confidenceThreshold: Float

    init(faces: [DetectedFace], frameSize: FrameSize, confidenceThreshold: Float = 0.5) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.faces = faces
        self.frameSize = frameSize
        self.confidenceThreshold = confidenceThreshold
    }
}

// MARK: - DetectedFace

/// 감지된 얼굴 정보
struct DetectedFace: Codable, Sendable {
    /// 얼굴 ID (추적용)
    let faceId: String?

    /// 바운딩 박스 (0.0~1.0 정규화 좌표)
    let boundingBox: NormalizedRect

    /// 감지 신뢰도 (0.0~1.0)
    let confidence: Float

    /// 얼굴 랜드마크 (눈, 코, 입 등)
    let landmarks: [FaceLandmark]?

    /// 감정 분석 결과 (옵션)
    let emotion: EmotionResult?

    init(
        faceId: String? = nil,
        boundingBox: NormalizedRect,
        confidence: Float,
        landmarks: [FaceLandmark]? = nil,
        emotion: EmotionResult? = nil
    ) {
        self.faceId = faceId
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
        self.emotion = emotion
    }
}

// MARK: - NormalizedRect

/// 정규화된 사각형 좌표 (0.0~1.0)
struct NormalizedRect: Codable, Sendable {
    /// 좌상단 X 좌표
    let x: Float

    /// 좌상단 Y 좌표
    let y: Float

    /// 너비
    let width: Float

    /// 높이
    let height: Float

    /// 중심점 X
    var centerX: Float { x + width / 2 }

    /// 중심점 Y
    var centerY: Float { y + height / 2 }

    init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// CGRect에서 정규화된 좌표로 변환
    init(cgRect: CGRect, frameSize: CGSize) {
        self.x = Float(cgRect.origin.x / frameSize.width)
        self.y = Float(cgRect.origin.y / frameSize.height)
        self.width = Float(cgRect.width / frameSize.width)
        self.height = Float(cgRect.height / frameSize.height)
    }

    /// CGRect로 변환
    func toCGRect(frameSize: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(x) * frameSize.width,
            y: CGFloat(y) * frameSize.height,
            width: CGFloat(width) * frameSize.width,
            height: CGFloat(height) * frameSize.height
        )
    }
}

// MARK: - FrameSize

/// 프레임 크기
struct FrameSize: Codable, Sendable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    init(cgSize: CGSize) {
        self.width = Int(cgSize.width)
        self.height = Int(cgSize.height)
    }

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - FaceLandmark

/// 얼굴 랜드마크 (특징점)
struct FaceLandmark: Codable, Sendable {
    /// 랜드마크 타입
    let type: LandmarkType

    /// 정규화된 X 좌표 (0.0~1.0)
    let x: Float

    /// 정규화된 Y 좌표 (0.0~1.0)
    let y: Float

    enum LandmarkType: String, Codable, Sendable {
        case leftEye
        case rightEye
        case nose
        case mouth
        case leftEar
        case rightEar
        case chin
    }
}

// MARK: - EmotionResult

/// 감정 분석 결과
struct EmotionResult: Codable, Sendable {
    /// 주요 감정
    let primaryEmotion: Emotion

    /// 감정별 신뢰도
    let scores: [Emotion: Float]

    enum Emotion: String, Codable, Sendable, CaseIterable {
        case happy
        case sad
        case angry
        case surprised
        case neutral
        case fearful
        case disgusted
    }

    init(primaryEmotion: Emotion, scores: [Emotion: Float]) {
        self.primaryEmotion = primaryEmotion
        self.scores = scores
    }
}

// MARK: - Data Channel Constants

extension FaceDetectionData {
    /// Data channel topic 이름
    static let topic = "face_detection"

    /// 최대 페이로드 크기 (LiveKit 제한: 15KB)
    static let maxPayloadSize = 15 * 1024

    /// JSON 인코딩
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// JSON 디코딩
    static func from(jsonData: Data) throws -> FaceDetectionData {
        let decoder = JSONDecoder()
        return try decoder.decode(FaceDetectionData.self, from: jsonData)
    }
}
