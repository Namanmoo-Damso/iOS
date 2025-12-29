import Foundation
import Combine
@testable import damso

@MainActor
final class MockNetworkMonitor: ObservableObject, NetworkMonitorProtocol {
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: NetworkConnectionType = .wifi

    func setConnected(_ connected: Bool) {
        isConnected = connected
    }

    func setConnectionType(_ type: NetworkConnectionType) {
        connectionType = type
    }

    func stopMonitoring() {
        // No-op for mock
    }
}
