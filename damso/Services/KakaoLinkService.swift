//
//  KakaoLinkService.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
import KakaoSDKShare
import KakaoSDKTemplate
import UIKit

enum KakaoLinkError: LocalizedError {
    case shareNotAvailable
    case templateError(String)
    case urlError
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .shareNotAvailable:
            return "카카오톡 공유 기능을 사용할 수 없습니다."
        case .templateError(let message):
            return "템플릿 오류: \(message)"
        case .urlError:
            return "URL 생성에 실패했습니다."
        case .unknownError(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
}

@MainActor
final class KakaoLinkService: KakaoLinkServiceProtocol {
    static let shared = KakaoLinkService()

    private init() {}

    // MARK: - Share Invite Link

    /// 카카오톡으로 초대 링크 공유
    /// - Parameters:
    ///   - guardianId: 보호자 ID
    ///   - guardianName: 보호자 닉네임
    ///   - wardEmail: 피보호자 이메일
    func shareInviteLink(
        guardianId: String,
        guardianName: String,
        wardEmail: String
    ) async throws {
        // 카카오톡 공유 가능 여부 확인
        guard ShareApi.isKakaoTalkSharingAvailable() else {
            // 웹 공유로 대체
            try await shareViaWeb(guardianId: guardianId, guardianName: guardianName, wardEmail: wardEmail)
            return
        }

        let template = createInviteTemplate(
            guardianId: guardianId,
            guardianName: guardianName,
            wardEmail: wardEmail
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ShareApi.shared.shareDefault(templatable: template) { sharingResult, error in
                if let error = error {
                    continuation.resume(throwing: KakaoLinkError.unknownError(error.localizedDescription))
                    return
                }

                if let sharingResult = sharingResult {
                    // 카카오톡 앱 열기
                    UIApplication.shared.open(sharingResult.url, options: [:]) { success in
                        if success {
                            continuation.resume(returning: ())
                        } else {
                            continuation.resume(throwing: KakaoLinkError.urlError)
                        }
                    }
                } else {
                    continuation.resume(throwing: KakaoLinkError.unknownError("No sharing result"))
                }
            }
        }
    }

    // MARK: - Web Share Fallback

    /// 웹 브라우저를 통한 공유 (카카오톡 미설치 시)
    private func shareViaWeb(
        guardianId: String,
        guardianName: String,
        wardEmail: String
    ) async throws {
        let template = createInviteTemplate(
            guardianId: guardianId,
            guardianName: guardianName,
            wardEmail: wardEmail
        )

        // makeDefaultUrl은 동기 메서드
        guard let url = ShareApi.shared.makeDefaultUrl(templatable: template) else {
            throw KakaoLinkError.urlError
        }

        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }

        if !success {
            throw KakaoLinkError.urlError
        }
    }

    // MARK: - Template Creation

    private func createInviteTemplate(
        guardianId: String,
        guardianName: String,
        wardEmail: String
    ) -> FeedTemplate {
        // 딥링크 파라미터
        let inviteParams = "guardian_id=\(guardianId)&ward_email=\(wardEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? wardEmail)"

        // Universal Link URL (앱 미설치 시 스토어로 이동)
        let webUrl = URL(string: "https://damso.app/invite?\(inviteParams)")

        // 앱 실행 파라미터
        let appExecutionParams = ["guardian_id": guardianId, "ward_email": wardEmail]

        let content = Content(
            title: "담소 초대",
            imageUrl: URL(string: "https://damso.app/og-image.png")!,
            description: "\(guardianName)님이 회원님을 담소에 초대했어요!\nAI 친구와 따뜻한 대화를 나눠보세요.",
            link: Link(
                webUrl: webUrl,
                mobileWebUrl: webUrl
            )
        )

        let button = Button(
            title: "앱에서 열기",
            link: Link(
                androidExecutionParams: appExecutionParams,
                iosExecutionParams: appExecutionParams
            )
        )

        return FeedTemplate(
            content: content,
            buttons: [button]
        )
    }

    // MARK: - Check Share Availability

    /// 카카오톡 공유 가능 여부 확인
    var isShareAvailable: Bool {
        ShareApi.isKakaoTalkSharingAvailable()
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[KakaoLinkService] \(message)")
        #endif
    }
}
