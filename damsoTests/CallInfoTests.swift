import XCTest
@testable import damso

final class CallInfoTests: XCTestCase {

    // MARK: - CallInfo Creation Tests

    @MainActor
    func testCallInfo_Creation() {
        // Given
        let uuid = UUID()
        let callId = "test-123"
        let handle = "Test User"
        let hasVideo = true
        let roomName = "test-room"
        let status = CallStatus.ringing

        // When
        let callInfo = CallInfo(
            id: uuid,
            callId: callId,
            handle: handle,
            hasVideo: hasVideo,
            roomName: roomName,
            status: status
        )

        // Then
        XCTAssertEqual(callInfo.id, uuid)
        XCTAssertEqual(callInfo.callId, callId)
        XCTAssertEqual(callInfo.handle, handle)
        XCTAssertEqual(callInfo.hasVideo, hasVideo)
        XCTAssertEqual(callInfo.roomName, roomName)
        XCTAssertEqual(callInfo.status, status)
    }

    @MainActor
    func testCallInfo_WithNilValues() {
        // Given
        let uuid = UUID()

        // When
        let callInfo = CallInfo(
            id: uuid,
            callId: nil,
            handle: "Unknown",
            hasVideo: false,
            roomName: nil,
            status: .ringing
        )

        // Then
        XCTAssertNil(callInfo.callId)
        XCTAssertNil(callInfo.roomName)
        XCTAssertFalse(callInfo.hasVideo)
    }

    // MARK: - CallStatus Tests

    @MainActor
    func testCallStatus_AllCases() {
        // Verify all status cases
        XCTAssertNotNil(CallStatus.ringing)
        XCTAssertNotNil(CallStatus.answered)
        XCTAssertNotNil(CallStatus.ended)
    }

    @MainActor
    func testCallStatus_Equality() {
        XCTAssertEqual(CallStatus.ringing, CallStatus.ringing)
        XCTAssertNotEqual(CallStatus.ringing, CallStatus.answered)
        XCTAssertNotEqual(CallStatus.answered, CallStatus.ended)
    }

    // MARK: - Identifiable Conformance

    @MainActor
    func testCallInfo_Identifiable() {
        // Given
        let uuid1 = UUID()
        let uuid2 = UUID()

        let call1 = CallInfo(id: uuid1, callId: nil, handle: "A", hasVideo: true, roomName: nil, status: .ringing)
        let call2 = CallInfo(id: uuid2, callId: nil, handle: "B", hasVideo: true, roomName: nil, status: .ringing)

        // Then
        XCTAssertNotEqual(call1.id, call2.id)
    }
}
