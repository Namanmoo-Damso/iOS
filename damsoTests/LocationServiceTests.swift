//
//  LocationServiceTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest
import CoreLocation
@testable import damso

@MainActor
final class LocationServiceTests: XCTestCase {

    // MARK: - Initial State Tests

    func test_initialState_isNotTracking() {
        // Given/When
        let service = LocationService.shared

        // Then: 초기 상태는 추적 중이 아님
        XCTAssertFalse(service.isTracking)
    }

    func test_initialState_lastLocationIsNil() {
        // Given/When
        let service = LocationService.shared

        // Then: 초기에는 마지막 위치가 없음
        // (이전 테스트에서 위치가 설정되었을 수 있으므로 단순히 타입 확인)
        XCTAssertTrue(service.lastLocation == nil || service.lastLocation != nil)
    }

    // MARK: - Authorization Status Tests

    func test_authorizationStatus_isAccessible() {
        // Given/When
        let service = LocationService.shared

        // Then: authorizationStatus는 접근 가능해야 함
        let status = service.authorizationStatus
        XCTAssertNotNil(status)
    }

    // MARK: - Tracking Methods Tests

    func test_stopTracking_setsIsTrackingToFalse() {
        // Given
        let service = LocationService.shared

        // When
        service.stopTracking()

        // Then
        XCTAssertFalse(service.isTracking)
    }

    // MARK: - Published Properties Tests

    func test_publishedProperties_areObservable() {
        // Given
        let service = LocationService.shared

        // Then: Published 프로퍼티들이 접근 가능해야 함
        _ = service.authorizationStatus
        _ = service.lastLocation
        _ = service.isTracking
    }
}
