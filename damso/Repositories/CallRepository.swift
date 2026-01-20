//
//  CallRepository.swift
//  damso
//
//  통화 Repository - Moya + Combine 기반
//

import Foundation
import Combine

#if canImport(Moya)
import Moya
import CombineMoya
#endif

// MARK: - Call Repository Protocol

protocol CallRepositoryProtocol {
    func invite(wardId: String) -> AnyPublisher<InviteCallResponse, NetworkError>
    func join(callId: String) -> AnyPublisher<Void, NetworkError>
    func end(callId: String) -> AnyPublisher<Void, NetworkError>
    func fetchHistory(wardId: String?, page: Int, limit: Int) -> AnyPublisher<CallHistoryResponse, NetworkError>
    func fetchDetail(callId: String) -> AnyPublisher<CallDetailResponse, NetworkError>
    
    // async/await 버전
    func invite(wardId: String) async throws -> InviteCallResponse
    func join(callId: String) async throws
    func end(callId: String) async throws
    func fetchHistory(wardId: String?, page: Int, limit: Int) async throws -> CallHistoryResponse
    func fetchDetail(callId: String) async throws -> CallDetailResponse
}

// MARK: - Call Repository Implementation

@MainActor
final class CallRepository: CallRepositoryProtocol {
    
    static let shared = CallRepository()
    
    #if canImport(Moya)
    private let provider: MoyaProvider<CallAPI>
    
    init(provider: MoyaProvider<CallAPI> = NetworkProviders.shared.call) {
        self.provider = provider
    }
    #else
    init() {}
    #endif
    
    // MARK: - Combine Publishers
    
    func invite(wardId: String) -> AnyPublisher<InviteCallResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.invite(wardId: wardId), type: InviteCallResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func join(callId: String) -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.join(callId: callId))
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func end(callId: String) -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.end(callId: callId))
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func fetchHistory(wardId: String?, page: Int, limit: Int) -> AnyPublisher<CallHistoryResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.history(wardId: wardId, page: page, limit: limit), type: CallHistoryResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func fetchDetail(callId: String) -> AnyPublisher<CallDetailResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.detail(callId: callId), type: CallDetailResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    // MARK: - Async/Await
    
    func invite(wardId: String) async throws -> InviteCallResponse {
        #if canImport(Moya)
        return try await provider.request(.invite(wardId: wardId), type: InviteCallResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func join(callId: String) async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.join(callId: callId))
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func end(callId: String) async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.end(callId: callId))
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func fetchHistory(wardId: String?, page: Int, limit: Int) async throws -> CallHistoryResponse {
        #if canImport(Moya)
        return try await provider.request(.history(wardId: wardId, page: page, limit: limit), type: CallHistoryResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func fetchDetail(callId: String) async throws -> CallDetailResponse {
        #if canImport(Moya)
        return try await provider.request(.detail(callId: callId), type: CallDetailResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
}

// MARK: - Mock Call Repository (for Testing)

#if DEBUG
final class MockCallRepository: CallRepositoryProtocol {
    
    var inviteCalled = false
    var fetchHistoryCalled = false
    var historyResult: [CallRecordDTO] = []
    
    func invite(wardId: String) -> AnyPublisher<InviteCallResponse, NetworkError> {
        inviteCalled = true
        return Fail(error: NetworkError.unknown(NSError(domain: "Mock", code: -1))).eraseToAnyPublisher()
    }
    
    func join(callId: String) -> AnyPublisher<Void, NetworkError> {
        Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func end(callId: String) -> AnyPublisher<Void, NetworkError> {
        Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchHistory(wardId: String?, page: Int, limit: Int) -> AnyPublisher<CallHistoryResponse, NetworkError> {
        fetchHistoryCalled = true
        let response = CallHistoryResponse(calls: historyResult, totalCount: historyResult.count, page: page, limit: limit)
        return Just(response).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchDetail(callId: String) -> AnyPublisher<CallDetailResponse, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock", code: -1))).eraseToAnyPublisher()
    }
    
    func invite(wardId: String) async throws -> InviteCallResponse {
        inviteCalled = true
        throw NetworkError.unknown(NSError(domain: "Mock", code: -1))
    }
    
    func join(callId: String) async throws {}
    func end(callId: String) async throws {}
    
    func fetchHistory(wardId: String?, page: Int, limit: Int) async throws -> CallHistoryResponse {
        fetchHistoryCalled = true
        return CallHistoryResponse(calls: historyResult, totalCount: historyResult.count, page: page, limit: limit)
    }
    
    func fetchDetail(callId: String) async throws -> CallDetailResponse {
        throw NetworkError.unknown(NSError(domain: "Mock", code: -1))
    }
}
#endif
