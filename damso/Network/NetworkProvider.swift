//
//  NetworkProvider.swift
//  damso
//
//  Moya + Combine 네트워크 프로바이더
//

import Foundation
import Combine
import Moya
import CombineMoya

// MARK: - Moya Providers

@MainActor
final class NetworkProviders {
    static let shared = NetworkProviders()
    
    // MARK: - Providers
    
    lazy var auth: MoyaProvider<AuthAPI> = {
        MoyaProvider<AuthAPI>(plugins: [networkLogger])
    }()
    
    lazy var user: MoyaProvider<UserAPI> = {
        MoyaProvider<UserAPI>(plugins: [networkLogger])
    }()
    
    lazy var call: MoyaProvider<CallAPI> = {
        MoyaProvider<CallAPI>(plugins: [networkLogger])
    }()
    
    lazy var schedule: MoyaProvider<ScheduleAPI> = {
        MoyaProvider<ScheduleAPI>(plugins: [networkLogger])
    }()
    
    lazy var alert: MoyaProvider<AlertAPI> = {
        MoyaProvider<AlertAPI>(plugins: [networkLogger])
    }()
    
    // MARK: - Plugins
    
    private var networkLogger: PluginType {
        #if DEBUG
        return NetworkLoggerPlugin(configuration: .init(logOptions: .verbose))
        #else
        return NetworkLoggerPlugin(configuration: .init(logOptions: .errorResponseBody))
        #endif
    }
    
    private init() {}
}

// MARK: - Combine Extensions

extension MoyaProvider {
    
    /// Combine Publisher로 요청
    func requestPublisher<T: Decodable>(
        _ target: Target,
        type: T.Type,
        decoder: JSONDecoder = .damsoDecoder
    ) -> AnyPublisher<T, NetworkError> {
        requestPublisher(target)
            .map(\.data)
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> NetworkError in
                if let moyaError = error as? MoyaError {
                    return NetworkError.from(moyaError)
                }
                if error is DecodingError {
                    return .decodingError(error)
                }
                return .unknown(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Void 응답 요청 (DELETE 등)
    func requestVoidPublisher(_ target: Target) -> AnyPublisher<Void, NetworkError> {
        requestPublisher(target)
            .map { _ in () }
            .mapError { NetworkError.from($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Async/Await Extensions

extension MoyaProvider {
    
    /// async/await로 요청
    func request<T: Decodable>(
        _ target: Target,
        type: T.Type,
        decoder: JSONDecoder = .damsoDecoder
    ) async throws -> T {
        // Swift 6 strict concurrency workaround:
        // Use @Sendable closure and nonisolated(unsafe) to suppress data race warnings
        nonisolated(unsafe) var result: Result<T, Error>?
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.request(target) { response in
                switch response {
                case .success(let res):
                    do {
                        let decoded = try decoder.decode(T.self, from: res.data)
                        result = .success(decoded)
                        continuation.resume()
                    } catch {
                        result = .failure(NetworkError.decodingError(error))
                        continuation.resume()
                    }
                case .failure(let error):
                    result = .failure(NetworkError.from(error))
                    continuation.resume()
                }
            }
        }
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// async/await Void 응답 요청
    func requestVoid(_ target: Target) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.request(target) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.from(error))
                }
            }
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case networkUnavailable
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "서버로부터 응답이 없습니다."
        case .decodingError(let error):
            return "데이터 파싱 오류: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "서버 오류 (\(code))"
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .networkUnavailable:
            return "네트워크 연결을 확인해주세요."
        case .timeout:
            return "요청 시간이 초과되었습니다."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    static func from(_ error: MoyaError) -> NetworkError {
        switch error {
        case .statusCode(let response):
            if response.statusCode == 401 {
                return .unauthorized
            }
            return .serverError(statusCode: response.statusCode, message: nil)
        case .underlying(let nsError as NSError, _):
            if nsError.code == NSURLErrorNotConnectedToInternet {
                return .networkUnavailable
            }
            if nsError.code == NSURLErrorTimedOut {
                return .timeout
            }
            return .unknown(nsError)
        default:
            return .unknown(error)
        }
    }
}

// MARK: - JSON Decoder

extension JSONDecoder {
    static var damsoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // ISO8601 시도
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            // 다른 포맷 시도
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
