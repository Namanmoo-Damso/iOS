//
//  FaceMeshData.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//

import Foundation
import CoreGraphics

/// 얼굴 메쉬 데이터 모델
struct FaceMeshData: Sendable {
    /// 전체 랜드마크 포인트 (정규화된 좌표 0~1)
    let landmarks: [CGPoint]

    /// 얼굴 영역 (정규화된 좌표)
    let boundingBox: CGRect

    /// 타임스탬프
    let timestamp: Date

    /// 랜드마크 개수
    var landmarkCount: Int { landmarks.count }

    /// 삼각형 메쉬 인덱스 (68개 랜드마크 기준 Delaunay triangulation)
    static let triangleIndices: [[Int]] = FaceMeshData.generateTriangleIndices()

    /// 68개 랜드마크 기준 삼각형 인덱스 생성
    private static func generateTriangleIndices() -> [[Int]] {
        // dlib 68 landmarks 기반 Delaunay triangulation 인덱스
        // 얼굴 윤곽 + 눈썹 + 눈 + 코 + 입 연결
        return [
            // 얼굴 윤곽 위쪽 (이마 부분)
            [0, 1, 36], [1, 2, 36], [2, 36, 41], [2, 3, 41],
            [3, 4, 41], [4, 41, 48], [4, 5, 48], [5, 48, 59],
            [5, 6, 59], [6, 59, 58], [6, 7, 58], [7, 57, 58],
            [7, 8, 57], [8, 9, 57], [9, 56, 57], [9, 10, 56],
            [10, 55, 56], [10, 11, 55], [11, 54, 55], [11, 12, 54],
            [12, 13, 54], [13, 35, 54], [13, 14, 35], [14, 35, 46],
            [14, 15, 46], [15, 45, 46], [15, 16, 45],

            // 왼쪽 눈썹
            [0, 17, 36], [17, 18, 36], [18, 36, 37], [18, 19, 37],
            [19, 37, 38], [19, 20, 38], [20, 38, 39], [20, 21, 39],

            // 오른쪽 눈썹
            [16, 26, 45], [26, 25, 45], [25, 44, 45], [25, 24, 44],
            [24, 43, 44], [24, 23, 43], [23, 42, 43], [23, 22, 42],

            // 눈썹 사이
            [21, 22, 27], [21, 27, 39], [22, 27, 42],

            // 왼쪽 눈
            [36, 37, 41], [37, 40, 41], [37, 38, 40], [38, 39, 40],

            // 오른쪽 눈
            [42, 43, 47], [43, 44, 47], [44, 45, 47], [45, 46, 47],

            // 코 윗부분
            [27, 28, 39], [28, 29, 39], [27, 28, 42], [28, 29, 42],
            [29, 30, 39], [29, 30, 42], [30, 31, 39], [30, 35, 42],

            // 코 아랫부분
            [30, 31, 32], [30, 32, 33], [30, 33, 34], [30, 34, 35],
            [31, 32, 48], [32, 33, 50], [33, 34, 52], [34, 35, 54],

            // 입술 위쪽
            [31, 48, 49], [31, 49, 50], [32, 50, 51], [33, 51, 52],
            [34, 52, 53], [35, 53, 54],

            // 입 내부
            [48, 49, 60], [49, 50, 60], [50, 51, 61], [50, 60, 61],
            [51, 52, 62], [51, 61, 62], [52, 53, 62], [53, 54, 63],
            [52, 62, 63], [54, 55, 63],

            // 입술 아래
            [48, 59, 60], [59, 58, 67], [59, 60, 67], [60, 61, 67],
            [61, 62, 66], [61, 66, 67], [62, 63, 65], [62, 65, 66],
            [63, 64, 65], [55, 56, 65], [56, 57, 65], [57, 58, 65],
            [58, 65, 66], [58, 66, 67],

            // 왼쪽 볼
            [1, 2, 41], [2, 29, 41], [29, 40, 41], [29, 31, 40],
            [31, 40, 41], [41, 36, 1], [31, 39, 40], [39, 40, 41],

            // 오른쪽 볼
            [14, 15, 46], [35, 46, 47], [35, 42, 47], [29, 35, 42],
            [15, 35, 46], [42, 43, 47], [46, 45, 47],

            // 턱 라인
            [4, 48, 5], [5, 58, 59], [5, 59, 48],
            [12, 54, 13], [11, 55, 54], [11, 12, 54],
            [8, 56, 57], [8, 9, 56], [9, 10, 55], [10, 11, 55]
        ]
    }

    /// Vision Framework 75개 랜드마크용 삼각형 인덱스
    /// Vision 랜드마크 순서:
    /// - faceContour: 17개 (0-16)
    /// - leftEyebrow: 8개 (17-24)
    /// - rightEyebrow: 8개 (25-32)
    /// - noseCrest: 3개 (33-35)
    /// - nose: 9개 (36-44)
    /// - leftEye: 8개 (45-52)
    /// - rightEye: 8개 (53-60)
    /// - outerLips: 9개 (61-69)
    /// - innerLips: 5개 (70-74)
    static let visionTriangleIndices: [[Int]] = {
        var indices: [[Int]] = []

        // 얼굴 윤곽 삼각형 (0-16) - 코 상단(33)과 연결
        for i in 0..<16 {
            indices.append([i, i + 1, 33])
        }

        // 왼쪽 눈썹 (17-24) - 순차적 연결 + 왼쪽 눈 첫점(45)과 연결
        for i in 17..<23 {
            indices.append([i, i + 1, 45])
        }

        // 오른쪽 눈썹 (25-32) - 순차적 연결 + 오른쪽 눈 첫점(53)과 연결
        for i in 25..<31 {
            indices.append([i, i + 1, 53])
        }

        // 코 능선 (33-35) - 순차적 연결
        indices.append([33, 34, 36])
        indices.append([34, 35, 36])

        // 코 (36-44) - Fan 형태로 중심(40)과 연결
        for i in 36..<43 {
            indices.append([i, i + 1, 40])
        }

        // 왼쪽 눈 (45-52) - Fan 형태로 중심(48)과 연결
        indices.append([45, 46, 48])
        indices.append([46, 47, 48])
        indices.append([47, 48, 49])
        indices.append([48, 49, 50])
        indices.append([49, 50, 51])
        indices.append([50, 51, 52])
        indices.append([51, 52, 45])
        indices.append([52, 45, 46])

        // 오른쪽 눈 (53-60) - Fan 형태로 중심(56)과 연결
        indices.append([53, 54, 56])
        indices.append([54, 55, 56])
        indices.append([55, 56, 57])
        indices.append([56, 57, 58])
        indices.append([57, 58, 59])
        indices.append([58, 59, 60])
        indices.append([59, 60, 53])
        indices.append([60, 53, 54])

        // 입술 외곽 (61-69) - Fan 형태로 중심(65)과 연결
        for i in 61..<68 {
            indices.append([i, i + 1, 65])
        }
        indices.append([68, 69, 65])
        indices.append([69, 61, 65])

        // 입술 내부 (70-74) - Fan 형태로 중심(72)과 연결
        indices.append([70, 71, 72])
        indices.append([71, 72, 73])
        indices.append([72, 73, 74])
        indices.append([73, 74, 70])
        indices.append([74, 70, 71])

        return indices
    }()
}

/// 랜드마크 타입
enum FaceLandmarkType: String, CaseIterable {
    case faceContour = "face_contour"
    case leftEyebrow = "left_eyebrow"
    case rightEyebrow = "right_eyebrow"
    case leftEye = "left_eye"
    case rightEye = "right_eye"
    case nose = "nose"
    case outerLips = "outer_lips"
    case innerLips = "inner_lips"
}
