import CallKit
import Foundation
import Combine

enum CallStatus {
    case ringing
    case answered
    case ended
}

struct CallInfo: Identifiable {
    let id: UUID
    let callId: String?
    let handle: String
    let hasVideo: Bool
    let roomName: String?
    let status: CallStatus
}

@MainActor
final class CallStateStore: ObservableObject {
    static let shared = CallStateStore()

    @Published private(set) var activeCall: CallInfo?

    func setIncoming(uuid: UUID, callId: String?, handle: String, hasVideo: Bool, roomName: String?) {
        activeCall = CallInfo(
            id: uuid,
            callId: callId,
            handle: handle,
            hasVideo: hasVideo,
            roomName: roomName,
            status: .ringing
        )
    }

    func clearCall() {
        activeCall = nil
    }
}

final class CallManager: NSObject {
    static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var callIdByUUID: [UUID: String] = [:]
    private var roomByUUID: [UUID: String] = [:]
    private var handleByUUID: [UUID: String] = [:]
    private var hasVideoByUUID: [UUID: Bool] = [:]
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CallManager] \(message)")
        #endif
    }

    private func summarizeCallId(_ callId: String?) -> String {
        guard let callId, !callId.isEmpty else { return "nil" }
        let suffix = callId.suffix(6)
        return "\(callId.prefix(8))..\((suffix))"
    }

    override init() {
        let configuration = CXProviderConfiguration()

        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool,
        callId: String?,
        roomName: String?,
        completion: ((Error?) -> Void)? = nil
    ) {
        debugLog("reportIncomingCall uuid=\(uuid.uuidString) callId=\(summarizeCallId(callId)) room=\(roomName ?? "nil") handle=\(handle) hasVideo=\(hasVideo)")
        if let callId {
            callIdByUUID[uuid] = callId
        }
        if let roomName {
            roomByUUID[uuid] = roomName
        }
        handleByUUID[uuid] = handle
        hasVideoByUUID[uuid] = hasVideo

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = hasVideo

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            Task { @MainActor in
                if error == nil {
                    CallStateStore.shared.setIncoming(
                        uuid: uuid,
                        callId: callId,
                        handle: handle,
                        hasVideo: hasVideo,
                        roomName: roomName
                    )
                    self.debugLog("CallKit incoming call reported ok uuid=\(uuid.uuidString)")
                }
            }
            if let error = error {
                self.debugLog("CallKit report failed: \(error)")
            }
            completion?(error)
        }
    }

    func answerCall(uuid: UUID) {
        debugLog("answerCall requested uuid=\(uuid.uuidString)")
        let action = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error {
                self.debugLog("answer call failed: \(error)")
            }
        }
    }

    func endCall(uuid: UUID) {
        debugLog("endCall requested uuid=\(uuid.uuidString)")
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error {
                self.debugLog("end call failed: \(error)")
            }
        }
    }

    private func cleanupCall(uuid: UUID) {
        callIdByUUID.removeValue(forKey: uuid)
        roomByUUID.removeValue(forKey: uuid)
        handleByUUID.removeValue(forKey: uuid)
        hasVideoByUUID.removeValue(forKey: uuid)
    }

    private func sendCallState(callId: String, endpoint: String) {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)\(endpoint)") else { return }
        debugLog("sendCallState endpoint=\(endpoint) callId=\(summarizeCallId(callId))")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["callId": callId])
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.debugLog("call state update failed: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    let bodyText = String(data: data ?? Data(), encoding: .utf8) ?? ""
                    self.debugLog("call state update status=\(httpResponse.statusCode) body=\(bodyText)")
                } else {
                    self.debugLog("call state update ok status=\(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

extension CallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        debugLog("providerDidReset")
        Task { @MainActor in
            CallStateStore.shared.clearCall()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        debugLog("provider answerCall action uuid=\(action.callUUID.uuidString)")
        if let callId = callIdByUUID[action.callUUID] {
            sendCallState(callId: callId, endpoint: "/v1/calls/answer")
        }
        Task { @MainActor in
            CallStateStore.shared.clearCall()
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        debugLog("provider endCall action uuid=\(action.callUUID.uuidString)")
        if let callId = callIdByUUID[action.callUUID] {
            sendCallState(callId: callId, endpoint: "/v1/calls/end")
        }
        cleanupCall(uuid: action.callUUID)
        Task { @MainActor in
            CallStateStore.shared.clearCall()
        }
        action.fulfill()
    }
}

