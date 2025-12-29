import Foundation
import Combine

@MainActor
protocol NetworkMonitorProtocol: ObservableObject {
    var isConnected: Bool { get }
    var connectionType: NetworkConnectionType { get }

    func stopMonitoring()
}

enum NetworkConnectionType {
    case wifi
    case cellular
    case wired
    case unknown
}
