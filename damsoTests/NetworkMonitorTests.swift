import XCTest
@testable import damso

final class NetworkMonitorTests: XCTestCase {

    // MARK: - Mock Tests

    @MainActor
    func testMockNetworkMonitor_DefaultState() {
        // Given
        let mock = MockNetworkMonitor()

        // Then
        XCTAssertTrue(mock.isConnected)
        XCTAssertEqual(mock.connectionType, .wifi)
    }

    @MainActor
    func testMockNetworkMonitor_SetConnected() {
        // Given
        let mock = MockNetworkMonitor()

        // When
        mock.setConnected(false)

        // Then
        XCTAssertFalse(mock.isConnected)
    }

    @MainActor
    func testMockNetworkMonitor_SetConnectionType() {
        // Given
        let mock = MockNetworkMonitor()

        // When
        mock.setConnectionType(.cellular)

        // Then
        XCTAssertEqual(mock.connectionType, .cellular)
    }

    // MARK: - NetworkConnectionType Tests

    func testNetworkConnectionType_AllCases() {
        // Verify all cases exist
        let wifi: NetworkConnectionType = .wifi
        let cellular: NetworkConnectionType = .cellular
        let wired: NetworkConnectionType = .wired
        let unknown: NetworkConnectionType = .unknown

        XCTAssertNotNil(wifi)
        XCTAssertNotNil(cellular)
        XCTAssertNotNil(wired)
        XCTAssertNotNil(unknown)
    }
}
