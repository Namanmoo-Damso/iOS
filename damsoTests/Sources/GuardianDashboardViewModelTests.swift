//
//  GuardianDashboardViewModelTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest

/// GuardianDashboardViewModel 단위 테스트
/// Sources 폴더의 테스트용 ViewModel 사용 (LiveKit 의존성 없음)
@MainActor
final class GuardianDashboardViewModelTests: XCTestCase {

    // MARK: - Initial State Tests

    func test_initialState_isNotLoading() {
        let viewModel = TestGuardianDashboardViewModel()
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_initialState_hasNoError() {
        let viewModel = TestGuardianDashboardViewModel()
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_initialState_hasZeroStatistics() {
        let viewModel = TestGuardianDashboardViewModel()
        XCTAssertEqual(viewModel.totalCalls, 0)
        XCTAssertEqual(viewModel.weeklyChange, 0)
        XCTAssertEqual(viewModel.averageDuration, 0)
        XCTAssertEqual(viewModel.positiveMoodPercent, 0)
    }

    func test_initialState_hasEmptyAlerts() {
        let viewModel = TestGuardianDashboardViewModel()
        XCTAssertTrue(viewModel.alerts.isEmpty)
    }

    func test_initialState_hasEmptyRecentCalls() {
        let viewModel = TestGuardianDashboardViewModel()
        XCTAssertTrue(viewModel.recentCalls.isEmpty)
    }

    // MARK: - Fetch Dashboard Tests

    func test_fetchDashboard_setsLoadingCorrectly() async {
        let viewModel = TestGuardianDashboardViewModel()

        // fetchDashboard 호출 전
        XCTAssertFalse(viewModel.isLoading)

        // fetchDashboard 실행
        await viewModel.fetchDashboard()

        // 완료 후 isLoading은 false
        XCTAssertFalse(viewModel.isLoading)
    }

    #if DEBUG
    func test_fetchDashboard_loadsData_inDebug() async {
        let viewModel = TestGuardianDashboardViewModel()

        await viewModel.fetchDashboard()

        // Mock 데이터가 로드되었는지 확인
        XCTAssertEqual(viewModel.totalCalls, 24)
        XCTAssertEqual(viewModel.weeklyChange, 3)
        XCTAssertEqual(viewModel.averageDuration, 11)
        XCTAssertEqual(viewModel.positiveMoodPercent, 85)
        XCTAssertFalse(viewModel.alerts.isEmpty)
        XCTAssertFalse(viewModel.recentCalls.isEmpty)
    }
    #endif
}
