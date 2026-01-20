//
//  UserRepository.swift
//  damso
//
//  사용자 Repository - Moya + Combine 기반
//

import Foundation
import Combine

#if canImport(Moya)
import Moya
import CombineMoya
#endif

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol {
    func fetchMe() -> AnyPublisher<UserMeResponse, NetworkError>
    func updateProfile(nickname: String?, phoneNumber: String?) -> AnyPublisher<UserMeResponse, NetworkError>
    func registerPushToken(deviceToken: String, voipToken: String?) -> AnyPublisher<Void, NetworkError>
    
    // async/await 버전
    func fetchMe() async throws -> UserMeResponse
    func updateProfile(nickname: String?, phoneNumber: String?) async throws -> UserMeResponse
    func registerPushToken(deviceToken: String, voipToken: String?) async throws
}

// MARK: - User Repository Implementation

@MainActor
final class UserRepository: UserRepositoryProtocol {
    
    static let shared = UserRepository()
    
    #if canImport(Moya)
    private let provider: MoyaProvider<UserAPI>
    
    init(provider: MoyaProvider<UserAPI> = NetworkProviders.shared.user) {
        self.provider = provider
    }
    #else
    init() {}
    #endif
    
    // MARK: - Combine Publishers
    
    func fetchMe() -> AnyPublisher<UserMeResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.me, type: UserMeResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func updateProfile(nickname: String?, phoneNumber: String?) -> AnyPublisher<UserMeResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.updateProfile(nickname: nickname, phoneNumber: phoneNumber), type: UserMeResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func registerPushToken(deviceToken: String, voipToken: String?) -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.registerPushToken(deviceToken: deviceToken, voipToken: voipToken))
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    // MARK: - Async/Await
    
    func fetchMe() async throws -> UserMeResponse {
        #if canImport(Moya)
        return try await provider.request(.me, type: UserMeResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func updateProfile(nickname: String?, phoneNumber: String?) async throws -> UserMeResponse {
        #if canImport(Moya)
        return try await provider.request(.updateProfile(nickname: nickname, phoneNumber: phoneNumber), type: UserMeResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func registerPushToken(deviceToken: String, voipToken: String?) async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.registerPushToken(deviceToken: deviceToken, voipToken: voipToken))
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
}

// MARK: - Mock User Repository (for Testing)

#if DEBUG
final class MockUserRepository: UserRepositoryProtocol {
    
    var fetchMeResult: Result<UserMeResponse, NetworkError> = .failure(.unknown(NSError(domain: "Not set", code: -1)))
    var updateProfileCalled = false
    var registerPushTokenCalled = false
    
    func fetchMe() -> AnyPublisher<UserMeResponse, NetworkError> {
        fetchMeResult.publisher.eraseToAnyPublisher()
    }
    
    func updateProfile(nickname: String?, phoneNumber: String?) -> AnyPublisher<UserMeResponse, NetworkError> {
        updateProfileCalled = true
        return fetchMeResult.publisher.eraseToAnyPublisher()
    }
    
    func registerPushToken(deviceToken: String, voipToken: String?) -> AnyPublisher<Void, NetworkError> {
        registerPushTokenCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func fetchMe() async throws -> UserMeResponse {
        try fetchMeResult.get()
    }
    
    func updateProfile(nickname: String?, phoneNumber: String?) async throws -> UserMeResponse {
        updateProfileCalled = true
        return try fetchMeResult.get()
    }
    
    func registerPushToken(deviceToken: String, voipToken: String?) async throws {
        registerPushTokenCalled = true
    }
}
#endif
