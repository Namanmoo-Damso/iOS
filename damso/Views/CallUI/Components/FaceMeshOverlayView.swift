//
//  FaceMeshOverlayView.swift
//  damso
//
//  Created by Claude Code on 2025-01-10.
//

import SwiftUI

/// 얼굴 메쉬 오버레이 뷰
/// Vision Framework 랜드마크를 기반으로 점과 삼각형 메쉬를 렌더링
struct FaceMeshOverlayView: View {
    /// 랜드마크 좌표 배열 (정규화된 0~1 좌표)
    let landmarks: [CGPoint]

    /// 메쉬 표시 여부
    var showMesh: Bool = true

    /// 점 표시 여부
    var showPoints: Bool = true

    /// 메쉬 색상
    var meshColor: Color = .yellow

    /// 점 색상
    var pointColor: Color = .yellow

    /// 메쉬 선 두께
    var meshLineWidth: CGFloat = 1.0

    /// 점 크기
    var pointSize: CGFloat = 4.0

    /// 비디오 프레임 크기 (aspect ratio 보정용)
    var videoFrameSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let visibleRect = calculateVideoRect(canvasSize: canvasSize)

            ZStack {
                // 삼각형 메쉬 (최소 랜드마크 개수 확인)
                if showMesh && landmarks.count >= 60 {
                    Canvas { context, _ in
                        drawMesh(context: context, visibleRect: visibleRect, canvasSize: canvasSize)
                    }
                }

                // 랜드마크 점
                if showPoints {
                    Canvas { context, _ in
                        drawPoints(context: context, visibleRect: visibleRect, canvasSize: canvasSize)
                    }
                }
            }
        }
    }

    // MARK: - Video Rect Calculation

    /// .fill 모드에서 Vision 좌표를 화면 좌표로 변환하기 위한 정보 계산
    /// .fill 모드: 비디오가 확대되어 표시 영역을 완전히 채움 (일부 crop)
    private func calculateVideoRect(canvasSize: CGSize) -> CGRect {
        guard videoFrameSize.width > 0 && videoFrameSize.height > 0 else {
            return CGRect(origin: .zero, size: canvasSize)
        }

        let videoAR = videoFrameSize.width / videoFrameSize.height
        let canvasAR = canvasSize.width / canvasSize.height

        // .fill 모드: 비디오가 캔버스를 완전히 채움
        // Vision 좌표 (0~1)에서 보이는 영역만 추출
        var visibleX: CGFloat = 0  // 비디오에서 보이는 영역의 시작 X (0~1)
        var visibleY: CGFloat = 0  // 비디오에서 보이는 영역의 시작 Y (0~1)
        var visibleWidth: CGFloat = 1  // 보이는 영역의 너비 (0~1)
        var visibleHeight: CGFloat = 1  // 보이는 영역의 높이 (0~1)

        if videoAR > canvasAR {
            // 비디오가 더 넓음 → 세로에 맞추고 좌우 crop
            let scale = canvasAR / videoAR
            visibleWidth = scale
            visibleX = (1 - scale) / 2
        } else {
            // 비디오가 더 좁음 → 가로에 맞추고 상하 crop
            let scale = videoAR / canvasAR
            visibleHeight = scale
            visibleY = (1 - scale) / 2
        }

        // 반환: origin = 보이는 영역의 시작점, size = 보이는 영역의 크기 (정규화된 값)
        // 이 값들을 사용해서 Vision 좌표를 화면 좌표로 변환
        return CGRect(x: visibleX, y: visibleY, width: visibleWidth, height: visibleHeight)
    }

    // MARK: - Drawing Methods

    /// 삼각형 메쉬 그리기
    private func drawMesh(context: GraphicsContext, visibleRect: CGRect, canvasSize: CGSize) {
        // dlib 68점 모델은 정확히 68개, Vision Framework는 75개 (또는 다른 개수)
        let triangleIndices = landmarks.count == 68
            ? FaceMeshData.triangleIndices
            : FaceMeshData.visionTriangleIndices

        for triangle in triangleIndices {
            // 인덱스가 범위를 벗어나면 스킵
            guard triangle.allSatisfy({ $0 < landmarks.count }) else { continue }

            let p0 = convertPoint(landmarks[triangle[0]], visibleRect: visibleRect, canvasSize: canvasSize)
            let p1 = convertPoint(landmarks[triangle[1]], visibleRect: visibleRect, canvasSize: canvasSize)
            let p2 = convertPoint(landmarks[triangle[2]], visibleRect: visibleRect, canvasSize: canvasSize)

            var path = Path()
            path.move(to: p0)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.closeSubpath()

            context.stroke(
                path,
                with: .color(meshColor.opacity(0.7)),
                lineWidth: meshLineWidth
            )
        }
    }

    /// 랜드마크 점 그리기
    private func drawPoints(context: GraphicsContext, visibleRect: CGRect, canvasSize: CGSize) {
        for landmark in landmarks {
            let point = convertPoint(landmark, visibleRect: visibleRect, canvasSize: canvasSize)

            let rect = CGRect(
                x: point.x - pointSize / 2,
                y: point.y - pointSize / 2,
                width: pointSize,
                height: pointSize
            )

            context.fill(
                Path(ellipseIn: rect),
                with: .color(pointColor)
            )
        }
    }

    /// Vision 좌표를 화면 좌표로 변환 (.fill 모드 crop 고려)
    /// visibleRect: 비디오에서 보이는 영역 (정규화된 0~1 값)
    private func convertPoint(_ visionPoint: CGPoint, visibleRect: CGRect, canvasSize: CGSize) -> CGPoint {
        // Vision 좌표가 보이는 영역 내의 어디에 해당하는지 계산
        // (visionPoint - visibleRect.origin) / visibleRect.size → 캔버스 내 상대 위치 (0~1)
        let relativeX = (visionPoint.x - visibleRect.origin.x) / visibleRect.width
        let relativeY = (visionPoint.y - visibleRect.origin.y) / visibleRect.height

        return CGPoint(
            x: relativeX * canvasSize.width,
            y: relativeY * canvasSize.height
        )
    }
}

// MARK: - Preview

#Preview {
    // 샘플 랜드마크 데이터 (간단한 얼굴 형태)
    let sampleLandmarks: [CGPoint] = {
        var points: [CGPoint] = []

        // 얼굴 윤곽 (17개)
        for i in 0..<17 {
            let angle = Double(i) / 16.0 * .pi
            let x = 0.5 + 0.35 * cos(.pi - angle)
            let y = 0.3 + 0.4 * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        // 왼쪽 눈썹 (5개)
        for i in 0..<5 {
            points.append(CGPoint(x: 0.25 + Double(i) * 0.04, y: 0.28))
        }

        // 오른쪽 눈썹 (5개)
        for i in 0..<5 {
            points.append(CGPoint(x: 0.55 + Double(i) * 0.04, y: 0.28))
        }

        // 코 (9개)
        points.append(CGPoint(x: 0.5, y: 0.35)) // 27
        points.append(CGPoint(x: 0.5, y: 0.4))
        points.append(CGPoint(x: 0.5, y: 0.45))
        points.append(CGPoint(x: 0.5, y: 0.5))
        points.append(CGPoint(x: 0.42, y: 0.52))
        points.append(CGPoint(x: 0.46, y: 0.53))
        points.append(CGPoint(x: 0.5, y: 0.54))
        points.append(CGPoint(x: 0.54, y: 0.53))
        points.append(CGPoint(x: 0.58, y: 0.52))

        // 왼쪽 눈 (6개)
        for i in 0..<6 {
            let angle = Double(i) / 6.0 * 2 * .pi
            points.append(CGPoint(x: 0.35 + 0.04 * cos(angle), y: 0.35 + 0.02 * sin(angle)))
        }

        // 오른쪽 눈 (6개)
        for i in 0..<6 {
            let angle = Double(i) / 6.0 * 2 * .pi
            points.append(CGPoint(x: 0.65 + 0.04 * cos(angle), y: 0.35 + 0.02 * sin(angle)))
        }

        // 입 외곽 (12개)
        for i in 0..<12 {
            let angle = Double(i) / 12.0 * 2 * .pi
            points.append(CGPoint(x: 0.5 + 0.08 * cos(angle), y: 0.65 + 0.03 * sin(angle)))
        }

        // 입 내부 (8개)
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * 2 * .pi
            points.append(CGPoint(x: 0.5 + 0.04 * cos(angle), y: 0.65 + 0.015 * sin(angle)))
        }

        return points
    }()

    ZStack {
        Color.black
        FaceMeshOverlayView(
            landmarks: sampleLandmarks,
            showMesh: true,
            showPoints: true
        )
    }
    .frame(width: 300, height: 400)
}
