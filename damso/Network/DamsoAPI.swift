//
//  DamsoAPI.swift
//  damso
//
//  Moya TargetType 정의 - API 엔드포인트
//

import Foundation
import Moya

// MARK: - Auth API

enum AuthAPI {
    case login(accessToken: String, userType: UserType?)
    case refresh(refreshToken: String)
    case logout
    case withdraw
    case registerGuardian(tempToken: String, wardEmail: String, wardPhoneNumber: String)
    case registerWard(tempToken: String, phoneNumber: String)
    case devLogin(wardEmail: String)
}

extension AuthAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .login:
            return "/v1/auth/kakao"
        case .refresh:
            return "/v1/auth/refresh"
        case .logout:
            return "/v1/auth/logout"
        case .withdraw:
            return "/v1/auth/withdraw"
        case .registerGuardian:
            return "/v1/users/register/guardian"
        case .registerWard:
            return "/v1/users/register/ward"
        case .devLogin:
            return "/v1/auth/dev-login"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .login, .refresh, .registerGuardian, .registerWard, .devLogin:
            return .post
        case .logout, .withdraw:
            return .delete
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .login(let accessToken, let userType):
            var params: [String: Any] = ["access_token": accessToken]
            if let type = userType {
                params["user_type"] = type.rawValue
            }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
            
        case .refresh(let refreshToken):
            return .requestParameters(parameters: ["refresh_token": refreshToken], encoding: JSONEncoding.default)
            
        case .logout, .withdraw:
            return .requestPlain
            
        case .registerGuardian(let tempToken, let wardEmail, let wardPhoneNumber):
            return .requestParameters(parameters: [
                "temp_token": tempToken,
                "ward_email": wardEmail,
                "ward_phone_number": wardPhoneNumber
            ], encoding: JSONEncoding.default)
            
        case .registerWard(let tempToken, let phoneNumber):
            return .requestParameters(parameters: [
                "temp_token": tempToken,
                "phone_number": phoneNumber
            ], encoding: JSONEncoding.default)
            
        case .devLogin(let wardEmail):
            return .requestParameters(parameters: [
                "wardEmail": wardEmail
            ], encoding: JSONEncoding.default)
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        
        switch self {
        case .logout, .withdraw:
            if let token = TokenManager.shared.accessToken {
                headers["Authorization"] = "Bearer \(token)"
            }
        default:
            break
        }
        
        return headers
    }
}

// MARK: - User API

enum UserAPI {
    case me
    case updateProfile(nickname: String?, phoneNumber: String?)
    case registerPushToken(deviceToken: String, voipToken: String?)
}

extension UserAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .me:
            return "/v1/users/me"
        case .updateProfile:
            return "/v1/users/me"
        case .registerPushToken:
            return "/v1/users/push-token"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .me:
            return .get
        case .updateProfile:
            return .patch
        case .registerPushToken:
            return .post
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .me:
            return .requestPlain
            
        case .updateProfile(let nickname, let phoneNumber):
            var params: [String: Any] = [:]
            if let nickname = nickname { params["nickname"] = nickname }
            if let phoneNumber = phoneNumber { params["phone_number"] = phoneNumber }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
            
        case .registerPushToken(let deviceToken, let voipToken):
            var params: [String: Any] = [
                "device_token": deviceToken,
                "platform": "ios"
            ]
            if let voip = voipToken { params["voip_token"] = voip }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}

// MARK: - Guardian API

enum GuardianAPI {
    case dashboard(wardId: String?, period: String?)
    case report(wardId: String?, startDate: String?, endDate: String?)
}

extension GuardianAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .dashboard:
            return "/v1/guardian/dashboard"
        case .report:
            return "/v1/guardian/report"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .dashboard, .report:
            return .get
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .dashboard(let wardId, let period):
            var params: [String: Any] = [:]
            if let wardId = wardId { params["ward_id"] = wardId }
            if let period = period { params["period"] = period }
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
            
        case .report(let wardId, let startDate, let endDate):
            var params: [String: Any] = [:]
            if let wardId = wardId { params["ward_id"] = wardId }
            if let startDate = startDate { params["start_date"] = startDate }
            if let endDate = endDate { params["end_date"] = endDate }
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}

// MARK: - Call API

enum CallAPI {
    case invite(wardId: String)
    case join(callId: String)
    case end(callId: String)
    case history(wardId: String?, page: Int, limit: Int)
    case detail(callId: String)
}

extension CallAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .invite:
            return "/v1/calls/invite"
        case .join(let callId):
            return "/v1/calls/\(callId)/join"
        case .end(let callId):
            return "/v1/calls/\(callId)/end"
        case .history:
            return "/v1/calls/history"
        case .detail(let callId):
            return "/v1/calls/\(callId)"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .invite, .join, .end:
            return .post
        case .history, .detail:
            return .get
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .invite(let wardId):
            return .requestParameters(parameters: ["ward_id": wardId], encoding: JSONEncoding.default)
            
        case .join, .end:
            return .requestPlain
            
        case .history(let wardId, let page, let limit):
            var params: [String: Any] = ["page": page, "limit": limit]
            if let wardId = wardId { params["ward_id"] = wardId }
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
            
        case .detail:
            return .requestPlain
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}

// MARK: - Schedule API

enum ScheduleAPI {
    case list(wardId: String)
    case create(wardId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool)
    case update(scheduleId: String, title: String, weekdays: [Int], hour: Int, minute: Int, isActive: Bool)
    case updateStatus(scheduleId: String, isActive: Bool)
    case delete(scheduleId: String)
}

extension ScheduleAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .list(let wardId):
            return "/v1/wards/\(wardId)/schedules"
        case .create:
            return "/v1/schedules"
        case .update(let scheduleId, _, _, _, _, _):
            return "/v1/schedules/\(scheduleId)"
        case .updateStatus(let scheduleId, _):
            return "/v1/schedules/\(scheduleId)/status"
        case .delete(let scheduleId):
            return "/v1/schedules/\(scheduleId)"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .list:
            return .get
        case .create:
            return .post
        case .update:
            return .put
        case .updateStatus:
            return .patch
        case .delete:
            return .delete
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .list:
            return .requestPlain
            
        case .create(let wardId, let title, let weekdays, let hour, let minute, let isActive):
            return .requestParameters(parameters: [
                "ward_id": wardId,
                "title": title,
                "weekdays": weekdays,
                "hour": hour,
                "minute": minute,
                "is_active": isActive
            ], encoding: JSONEncoding.default)
            
        case .update(_, let title, let weekdays, let hour, let minute, let isActive):
            return .requestParameters(parameters: [
                "title": title,
                "weekdays": weekdays,
                "hour": hour,
                "minute": minute,
                "is_active": isActive
            ], encoding: JSONEncoding.default)
            
        case .updateStatus(_, let isActive):
            return .requestParameters(parameters: ["is_active": isActive], encoding: JSONEncoding.default)
            
        case .delete:
            return .requestPlain
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}

// MARK: - Alert API

enum AlertAPI {
    case list(wardId: String?, page: Int, limit: Int)
    case detail(alertId: String)
    case acknowledge(alertId: String)
}

extension AlertAPI: TargetType {
    var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }
    
    var path: String {
        switch self {
        case .list:
            return "/v1/alerts"
        case .detail(let alertId):
            return "/v1/alerts/\(alertId)"
        case .acknowledge(let alertId):
            return "/v1/alerts/\(alertId)/acknowledge"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .list, .detail:
            return .get
        case .acknowledge:
            return .post
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .list(let wardId, let page, let limit):
            var params: [String: Any] = ["page": page, "limit": limit]
            if let wardId = wardId { params["ward_id"] = wardId }
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
            
        case .detail:
            return .requestPlain
            
        case .acknowledge:
            return .requestParameters(
                parameters: ["timestamp": ISO8601DateFormatter().string(from: Date())],
                encoding: JSONEncoding.default
            )
        }
    }
    
    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}
