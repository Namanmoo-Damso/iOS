//
//  AuthRepository.swift
//  damso
//
//  인증 Repository - Moya + Combine 기반
//

import Foundation
import Combine

#if canImport(Moya)
import Moya
import CombineMoya
#endif

// MARK: - Auth Repository Protocol

protocol AuthRepositoryProtocol {
    func login(accessToken: String, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError>
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError>
    func refresh(refreshToken: String) -> AnyPublisher<TokenRefreshResponse, NetworkError>
    func logout() -> AnyPublisher<Void, NetworkError>
    func withdraw() -> AnyPublisher<Void, NetworkError>
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) -> AnyPublisher<GuardianRegistrationResponse, NetworkError>
    func registerWard(tempToken: String, phoneNumber: String) -> AnyPublisher<AuthResponse, NetworkError>
    func devLogin(wardEmail: String) -> AnyPublisher<AuthResponse, NetworkError>
    
    // async/await 버전
    func login(accessToken: String, userType: UserType?) async throws -> AuthResponse
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) async throws -> AuthResponse
    func refresh(refreshToken: String) async throws -> TokenRefreshResponse
    func logout() async throws
    func withdraw() async throws
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse
    func devLogin(wardEmail: String) async throws -> AuthResponse
}

// MARK: - Auth Repository Implementation

@MainActor
final class AuthRepository: AuthRepositoryProtocol {
    
    static let shared = AuthRepository()
    
    #if canImport(Moya)
    private let provider: MoyaProvider<AuthAPI>
    
    init(provider: MoyaProvider<AuthAPI> = NetworkProviders.shared.auth) {
        self.provider = provider
    }
    #else
    init() {}
    #endif
    
    // MARK: - Combine Publishers
    
    func login(accessToken: String, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.login(accessToken: accessToken, userType: userType), type: AuthResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.loginWithKakao(accessToken: accessToken, kakaoUserInfo: kakaoUserInfo, userType: userType), type: AuthResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func refresh(refreshToken: String) -> AnyPublisher<TokenRefreshResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.refresh(refreshToken: refreshToken), type: TokenRefreshResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func logout() -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.logout)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func withdraw() -> AnyPublisher<Void, NetworkError> {
        #if canImport(Moya)
        return provider.requestVoidPublisher(.withdraw)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) -> AnyPublisher<GuardianRegistrationResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(
            .registerGuardian(tempToken: tempToken, wardEmail: wardEmail, wardPhoneNumber: wardPhoneNumber),
            type: GuardianRegistrationResponse.self
        )
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func registerWard(tempToken: String, phoneNumber: String) -> AnyPublisher<AuthResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(
            .registerWard(tempToken: tempToken, phoneNumber: phoneNumber),
            type: AuthResponse.self
        )
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    func devLogin(wardEmail: String) -> AnyPublisher<AuthResponse, NetworkError> {
        #if canImport(Moya)
        return provider.requestPublisher(.devLogin(wardEmail: wardEmail), type: AuthResponse.self)
        #else
        return Fail(error: NetworkError.unknown(NSError(domain: "Moya not available", code: -1)))
            .eraseToAnyPublisher()
        #endif
    }
    
    // MARK: - Async/Await
    
    func login(accessToken: String, userType: UserType?) async throws -> AuthResponse {
        #if canImport(Moya)
        return try await provider.request(.login(accessToken: accessToken, userType: userType), type: AuthResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) async throws -> AuthResponse {
        #if canImport(Moya)
        let response = try await provider.request(.loginWithKakao(accessToken: accessToken, kakaoUserInfo: kakaoUserInfo, userType: userType), type: AuthResponse.self)
        
        // 토큰 저장 (기존 AuthService와 동일한 동작 유지)
        if let accessToken = response.accessToken, let refreshToken = response.refreshToken {
            TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        }
        
        return response
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func refresh(refreshToken: String) async throws -> TokenRefreshResponse {
        #if canImport(Moya)
        return try await provider.request(.refresh(refreshToken: refreshToken), type: TokenRefreshResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func logout() async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.logout)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func withdraw() async throws {
        #if canImport(Moya)
        try await provider.requestVoid(.withdraw)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func devLogin(wardEmail: String) async throws -> AuthResponse {
        #if canImport(Moya)
        return try await provider.request(.devLogin(wardEmail: wardEmail), type: AuthResponse.self)
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
    
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        #if canImport(Moya)
        return try await provider.request(
            .registerGuardian(tempToken: tempToken, wardEmail: wardEmail, wardPhoneNumber: wardPhoneNumber),
            type: GuardianRegistrationResponse.self
        )
        #else
        throw NetworkError.unknown(NSError(domain: "Moya not available", code: -1))
        #endif
    }
}

// MARK: - Mock Auth Repository (for Testing)

#if DEBUG
final class MockAuthRepository: AuthRepositoryProtocol {
    
    var loginResult: Result<AuthResponse, NetworkError> = .failure(.unknown(NSError(domain: "Not set", code: -1)))
    var refreshResult: Result<TokenRefreshResponse, NetworkError> = .failure(.unknown(NSError(domain: "Not set", code: -1)))
    var logoutCalled = false
    var withdrawCalled = false
    
    func login(accessToken: String, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError> {
        loginResult.publisher.eraseToAnyPublisher()
    }
    
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) -> AnyPublisher<AuthResponse, NetworkError> {
        loginResult.publisher.eraseToAnyPublisher()
    }
    
    func refresh(refreshToken: String) -> AnyPublisher<TokenRefreshResponse, NetworkError> {
        refreshResult.publisher.eraseToAnyPublisher()
    }
    
    func logout() -> AnyPublisher<Void, NetworkError> {
        logoutCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func withdraw() -> AnyPublisher<Void, NetworkError> {
        withdrawCalled = true
        return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
    }
    
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) -> AnyPublisher<GuardianRegistrationResponse, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock not implemented", code: -1))).eraseToAnyPublisher()
    }
    
    func registerWard(tempToken: String, phoneNumber: String) -> AnyPublisher<AuthResponse, NetworkError> {
        Fail(error: NetworkError.unknown(NSError(domain: "Mock not implemented", code: -1))).eraseToAnyPublisher()
    }
    
    func login(accessToken: String, userType: UserType?) async throws -> AuthResponse {
        try loginResult.get()
    }
    
    func loginWithKakao(accessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) async throws -> AuthResponse {
        try loginResult.get()
    }

    
    func refresh(refreshToken: String) async throws -> TokenRefreshResponse {
        try refreshResult.get()
    }
    
    func logout() async throws {
        logoutCalled = true
    }
    
    func withdraw() async throws {
        withdrawCalled = true
    }
    
    func devLogin(wardEmail: String) -> AnyPublisher<AuthResponse, NetworkError> {
        loginResult.publisher.eraseToAnyPublisher()
    }
    
    func devLogin(wardEmail: String) async throws -> AuthResponse {
        try loginResult.get()
    }
    
    func registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        throw NetworkError.unknown(NSError(domain: "Mock not implemented", code: -1))
    }
}
#endif
