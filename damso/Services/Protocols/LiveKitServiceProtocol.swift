import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit

@MainActor
protocol LiveKitServiceProtocol: ObservableObject {
    var connectionState: ConnectionState { get }
    var reconnectMode: ReconnectMode? { get }
    var errorMessage: String? { get }
    var reconnectTimeRemaining: Int { get }
    var isReconnecting: Bool { get }
    var remoteParticipantDisconnected: Bool { get }
    var remoteDisconnectTimeRemaining: Int { get }

    var room: Room { get }
    var localMedia: LocalMedia { get }

    func connect(token: String) async throws
    func disconnect() async
    func setRemoteAudioEnabled(_ enabled: Bool) async
}
#endif
