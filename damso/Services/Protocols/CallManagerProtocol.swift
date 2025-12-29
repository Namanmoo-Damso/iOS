import Foundation
import Combine

@MainActor
protocol CallStateStoreProtocol: ObservableObject {
    var activeCall: CallInfo? { get }
    var activeCallPublisher: AnyPublisher<CallInfo?, Never> { get }

    func setIncoming(uuid: UUID, callId: String?, handle: String, hasVideo: Bool, roomName: String?)
    func setAnswered(uuid: UUID, callId: String?, handle: String, hasVideo: Bool, roomName: String?)
    func clearCall()
}

protocol CallManagerProtocol {
    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool,
        callId: String?,
        roomName: String?,
        completion: (@Sendable (Error?) -> Void)?
    )
    func answerCall(uuid: UUID)
    func endCall(uuid: UUID)
}
