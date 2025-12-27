import Foundation
import Combine

enum TokenError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case missingToken
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "Missing API auth token. Store it in UserDefaults with key 'authToken'."
        case .invalidResponse:
            return "Invalid token response."
        case let .httpStatus(code, body):
            if body.isEmpty {
                return "Token API failed with status \(code)."
            }
            return "Token API failed (\(code)): \(body)"
        case .missingToken:
            return "Token is missing in API response."
        case let .networkError(msg):
            return "Network Error: \(msg)"
        }
    }
}

class AuthService {
    private let authTokenKey = "authToken"
    private let identityKey = "user_identity"
    private let apnsKey = "cached_apns_token"
    private let voipKey = "cached_voip_token"
    
    private var apnsEnv: String {
        #if DEBUG
        return "dev"
        #else
        return "prod"
        #endif
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AuthService] \(message)")
        #endif
    }
    
    // 익명 인증 토큰 발급
    func fetchApiToken() async throws(TokenError) -> String {
        let identity = stableIdentity()
        let url = URL(string: "\(AppConfig.apiBaseURL)/v1/auth/anonymous")!
        
        var req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let data: Data
        let response: URLResponse
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "identity": identity,
                "displayName": "iOS User"
            ])
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw .networkError(error.localizedDescription)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if !(200..<300).contains(httpResponse.statusCode) {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw TokenError.httpStatus(code: httpResponse.statusCode, body: bodyText)
            }
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["accessToken"] as? String else {
                throw TokenError.missingToken
            }
            UserDefaults.standard.set(token, forKey: authTokenKey)
            debugLog("API token stored")
            return token
        } catch {
            if let tokenErr = error as? TokenError { throw tokenErr }
            throw .networkError("JSON Parsing Error")
        }
    }
    
    // LiveKit 접속용 토큰 발급
    func fetchLiveKitToken(roomName: String) async throws(TokenError) -> String {
        var authToken = UserDefaults.standard.string(forKey: authTokenKey)
        if authToken == nil || authToken?.isEmpty == true {
            authToken = try await fetchApiToken()
        }
        
        let token = authToken!
        let tokenEndpoint = URL(string: "\(AppConfig.apiBaseURL)/v1/rtc/token")!
        
        var request = URLRequest(url: tokenEndpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let identity = stableIdentity()
        let cachedApns = UserDefaults.standard.string(forKey: apnsKey)
        let cachedVoip = UserDefaults.standard.string(forKey: voipKey)
        
        var body: [String: Any] = [
            "roomName": roomName,
            "identity": identity,
            "name": "iOS User",
            "role": "viewer",
            "platform": "ios",
            "env": apnsEnv
        ]
        
        // Swift 6 Shorthand if let
        if let cachedApns, !cachedApns.isEmpty {
            body["apnsToken"] = cachedApns
        }
        if let cachedVoip, !cachedVoip.isEmpty {
            body["voipToken"] = cachedVoip
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
             throw .networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            UserDefaults.standard.removeObject(forKey: authTokenKey)
            throw TokenError.httpStatus(code: 401, body: "Unauthorized - Token might be expired")
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.httpStatus(code: httpResponse.statusCode, body: body)
        }
        
        return try parseToken(from: data)
    }
    
    private func parseToken(from data: Data) throws(TokenError) -> String {
        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.first != "{", trimmed.first != "[" {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        
        struct TokenEnvelope: Decodable {
            let token: String?
            let accessToken: String?
            let data: Nested?
            let result: Nested?
            
            struct Nested: Decodable {
                let token: String?
                let accessToken: String?
            }
        }
        
        let response: TokenEnvelope
        do {
            response = try JSONDecoder().decode(TokenEnvelope.self, from: data)
        } catch {
            throw .networkError("JSON Decode Failed")
        }
        
        if let t = response.token { return t }
        if let t = response.accessToken { return t }
        if let t = response.data?.token { return t }
        if let t = response.data?.accessToken { return t }
        if let t = response.result?.token { return t }
        if let t = response.result?.accessToken { return t }
        
        throw TokenError.missingToken
    }
    
    private func stableIdentity() -> String {
        if let stored = UserDefaults.standard.string(forKey: identityKey) {
            return stored
        }
        let newIdentity = "ios-\(UUID().uuidString)"
        UserDefaults.standard.set(newIdentity, forKey: identityKey)
        return newIdentity
    }
}

