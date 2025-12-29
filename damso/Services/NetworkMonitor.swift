import Network
import Foundation
import Combine

@MainActor
final class NetworkMonitor: ObservableObject, NetworkMonitorProtocol {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: NetworkConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateConnectionStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func updateConnectionStatus(path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }

        #if DEBUG
        print("[NetworkMonitor] connected=\(isConnected) type=\(connectionType)")
        #endif

        // 연결 끊김 감지
        if wasConnected && !isConnected {
            NotificationCenter.default.post(name: .networkDidDisconnect, object: nil)
        }

        // 연결 복구 감지
        if !wasConnected && isConnected {
            NotificationCenter.default.post(name: .networkDidReconnect, object: nil)
        }
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkDidDisconnect = Notification.Name("networkDidDisconnect")
    static let networkDidReconnect = Notification.Name("networkDidReconnect")
}
