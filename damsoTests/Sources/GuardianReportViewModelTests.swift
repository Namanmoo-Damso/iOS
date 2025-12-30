//
//  GuardianReportViewModelTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest

/// GuardianReportViewModel 단위 테스트
/// Sources 폴더의 테스트용 ViewModel 사용 (LiveKit 의존성 없음)
@MainActor
final class GuardianReportViewModelTests: XCTestCase {

    // MARK: - Initial State Tests

    func test_initialState_isNotLoading() {
        let viewModel = TestGuardianReportViewModel()
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_initialState_hasNoError() {
        let viewModel = TestGuardianReportViewModel()
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_initialState_hasEmptyEmotionTrend() {
        let viewModel = TestGuardianReportViewModel()
        XCTAssertTrue(viewModel.emotionTrend.isEmpty)
    }

    func test_initialState_hasNoHealthKeywords() {
        let viewModel = TestGuardianReportViewModel()
        XCTAssertNil(viewModel.healthKeywords)
    }

    func test_initialState_hasEmptyWeeklySummary() {
        let viewModel = TestGuardianReportViewModel()
        XCTAssertTrue(viewModel.weeklySummary.isEmpty)
    }

    // MARK: - Fetch Report Tests

    func test_fetchReport_setsLoadingCorrectly() async {
        let viewModel = TestGuardianReportViewModel()

        // fetchReport 호출 전
        XCTAssertFalse(viewModel.isLoading)

        // fetchReport 실행
        await viewModel.fetchReport()

        // 완료 후 isLoading은 false
        XCTAssertFalse(viewModel.isLoading)
    }

    #if DEBUG
    func test_fetchReport_loadsData_inDebug() async {
        let viewModel = TestGuardianReportViewModel()

        await viewModel.fetchReport()

        // Mock 데이터가 로드되었는지 확인
        XCTAssertFalse(viewModel.emotionTrend.isEmpty)
        XCTAssertNotNil(viewModel.healthKeywords)
        XCTAssertFalse(viewModel.weeklySummary.isEmpty)
    }
    #endif
}
