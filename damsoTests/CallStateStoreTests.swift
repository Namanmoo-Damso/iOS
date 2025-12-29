import XCTest
@testable import damso

final class CallStateStoreTests: XCTestCase {

    // MARK: - setIncoming Tests

    @MainActor
    func testSetIncoming_SetsActiveCallWithRingingStatus() {
        // Given
        let sut = CallStateStore.shared
        sut.clearCall()

        let uuid = UUID()
        let callId = "test-call-123"
        let handle = "Test Caller"
        let hasVideo = true
        let roomName = "test-room"

        // When
        sut.setIncoming(uuid: uuid, callId: callId, handle: handle, hasVideo: hasVideo, roomName: roomName)

        // Then
        XCTAssertNotNil(sut.activeCall)
        XCTAssertEqual(sut.activeCall?.id, uuid)
        XCTAssertEqual(sut.activeCall?.callId, callId)
        XCTAssertEqual(sut.activeCall?.handle, handle)
        XCTAssertEqual(sut.activeCall?.hasVideo, hasVideo)
        XCTAssertEqual(sut.activeCall?.roomName, roomName)
        XCTAssertEqual(sut.activeCall?.status, .ringing)

        // Cleanup
        sut.clearCall()
    }

    @MainActor
    func testSetIncoming_WithNilCallId_SetsActiveCall() {
        // Given
        let sut = CallStateStore.shared
        sut.clearCall()
        let uuid = UUID()

        // When
        sut.setIncoming(uuid: uuid, callId: nil, handle: "Caller", hasVideo: false, roomName: nil)

        // Then
        XCTAssertNotNil(sut.activeCall)
        XCTAssertNil(sut.activeCall?.callId)
        XCTAssertNil(sut.activeCall?.roomName)

        // Cleanup
        sut.clearCall()
    }

    // MARK: - setAnswered Tests

    @MainActor
    func testSetAnswered_SetsActiveCallWithAnsweredStatus() {
        // Given
        let sut = CallStateStore.shared
        sut.clearCall()
        let uuid = UUID()
        let callId = "answered-call-456"
        let handle = "Answered Caller"

        // When
        sut.setAnswered(uuid: uuid, callId: callId, handle: handle, hasVideo: true, roomName: "room")

        // Then
        XCTAssertNotNil(sut.activeCall)
        XCTAssertEqual(sut.activeCall?.status, .answered)
        XCTAssertEqual(sut.activeCall?.callId, callId)

        // Cleanup
        sut.clearCall()
    }

    // MARK: - clearCall Tests

    @MainActor
    func testClearCall_RemovesActiveCall() {
        // Given
        let sut = CallStateStore.shared
        sut.setIncoming(uuid: UUID(), callId: "123", handle: "Test", hasVideo: true, roomName: nil)
        XCTAssertNotNil(sut.activeCall)

        // When
        sut.clearCall()

        // Then
        XCTAssertNil(sut.activeCall)
    }

    // MARK: - State Transition Tests

    @MainActor
    func testStateTransition_FromRingingToAnswered() {
        // Given
        let sut = CallStateStore.shared
        sut.clearCall()
        let uuid = UUID()
        sut.setIncoming(uuid: uuid, callId: "123", handle: "Test", hasVideo: true, roomName: "room")
        XCTAssertEqual(sut.activeCall?.status, .ringing)

        // When
        sut.setAnswered(uuid: uuid, callId: "123", handle: "Test", hasVideo: true, roomName: "room")

        // Then
        XCTAssertEqual(sut.activeCall?.status, .answered)

        // Cleanup
        sut.clearCall()
    }
}
