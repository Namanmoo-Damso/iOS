//
//  ScheduleRepository.swift
//  damso
//
//  스케줄 Repository - Moya + Combine 기반
//

import Foundation
import Combine

#if canImport(Moya)
import Moya
import CombineMoya
#endif

// MARK: - Schedule Repository Protocol

protocol ScheduleRepositoryProtocol {
    func fetchSchedules(wardId: String) -> AnyPublisher<[AICallScheduleItem], NetworkError>
    func createSchedule(wardId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError>
    func updateSchedule(scheduleId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError>
    func updateScheduleStatus(scheduleId: String, isActive: Bool) -> AnyPublisher<Void, NetworkError>
    func deleteSchedule(scheduleId: String) -> AnyPublisher<Void, NetworkError>
    
    // async/await 버전
    func fetchSchedules(wardId: String) async throws -> [AICallScheduleItem]
    func updateScheduleStatus(scheduleId: String, isActive: Bool) async throws
    func deleteSchedule(scheduleId: String) async throws
}

// MARK: - Schedule Repository Implementation

@MainActor
final class ScheduleRepository: ScheduleRepositoryProtocol {
    
    static let shared = ScheduleRepository()
    
    #if canImport(Moya)
    private let provider: MoyaProvider<ScheduleAPI>
    
    init(provider: MoyaProvider<ScheduleAPI> = NetworkProviders.shared.schedule) {
        self.provider = provider
    }
    #else
    init() {}
    #endif
    
    // MARK: - Combine Publishers
    
    func fetchSchedules(wardId: String) -> AnyPublisher<[AICallScheduleItem], NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.list(wardId: wardId), type: ScheduleListResponse.self)
            .map { $0.schedules.map { $0.toAICallScheduleItem() } }
            .eraseToAnyPublisher()
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func createSchedule(wardId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(
            .create(wardId: wardId, title: title, weekdays: weekdays, hour: hour, minute: minute, isActive: isActive),
            type: ScheduleDTO.self
        )
        .map { $0.toAICallScheduleItem() }
        .eraseToAnyPublisher()
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func updateSchedule(scheduleId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(
            .update(scheduleId: scheduleId, title: title, weekdays: weekdays, hour: hour, minute: minute, isActive: isActive),
            type: ScheduleDTO.self
        )
        .map { $0.toAICallScheduleItem() }
        .eraseToAnyPublisher()
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func updateScheduleStatus(scheduleId: String, isActive: Bool) -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.updateStatus(scheduleId: scheduleId, isActive: isActive))
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func deleteSchedule(scheduleId: String) -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.delete(scheduleId: scheduleId))
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    // MARK: - Async/Await
    
    func fetchSchedules(wardId: String) async throws -> [AICallScheduleItem] {
        #if canImport(Moya)
        let response = try await provider.request(.list(wardId: wardId), type: ScheduleListResponse.self)
        return response.schedules.map { $0.toAICallScheduleItem() }
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func updateScheduleStatus(scheduleId: String, isActive: Bool) async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.updateStatus(scheduleId: scheduleId, isActive: isActive))
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func deleteSchedule(scheduleId: String) async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.delete(scheduleId: scheduleId))
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
}

// MARK: - Mock Schedule Repository (for Testing)

#if DEBUG
final class MockScheduleRepository: ScheduleRepositoryProtocol {
    
    var schedules: [AICallScheduleItem] = []
    var fetchCalled = false
    var updateStatusCalled = false
    var deleteCalled = false
    
    func fetchSchedules(wardId: String) -> AnyPublisher<[AICallScheduleItem], NetworkError> {
        fetchCalled = true
        return Just(schedules).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func createSchedule(wardId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock", code: -1))).eraseToAnyPublisher()
    }
    
    func updateSchedule(scheduleId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool) -> AnyPublisher<AICallScheduleItem, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock", code: -1))).eraseToAnyPublisher()
    }
    
    func updateScheduleStatus(scheduleId: String, isActive: Bool) -> AnyPublisher<Void, NetworkError> {
        updateStatusCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func deleteSchedule(scheduleId: String) -> AnyPublisher<Void, NetworkError> {
        deleteCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchSchedules(wardId: String) async throws -> [AICallScheduleItem] {
        fetchCalled = true
        return schedules
    }
    
    func updateScheduleStatus(scheduleId: String, isActive: Bool) async throws {
        updateStatusCalled = true
    }
    
    func deleteSchedule(scheduleId: String) async throws {
        deleteCalled = true
    }
}
#endif
