//
//  LocationService.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
import CoreLocation
import Combine

/// 실시간 위치 추적 서비스 (어르신 앱 전용)
final class LocationService: NSObject, ObservableObject {

    static let shared = LocationService()

    // MARK: - Published Properties

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var isTracking = false

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var lastSentLocation: CLLocation?
    private let minimumDistance: CLLocationDistance = 100 // 100m 이동 시 업데이트
    private let minimumTimeInterval: TimeInterval = 60 // 최소 60초 간격

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = minimumDistance
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// 위치 권한 요청
    func requestAuthorization() {
        debugLog("Requesting location authorization")
        locationManager.requestAlwaysAuthorization()
    }

    /// 위치 추적 시작
    func startTracking() {
        guard authorizationStatus == .authorizedAlways ||
              authorizationStatus == .authorizedWhenInUse else {
            debugLog("Location authorization not granted")
            requestAuthorization()
            return
        }

        debugLog("Starting location tracking")
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    /// 위치 추적 중지
    func stopTracking() {
        debugLog("Stopping location tracking")
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Private Methods

    private func sendLocationToServer(_ location: CLLocation) async {
        // 최소 시간 간격 체크
        if let lastSent = lastSentLocation {
            let timeSinceLastSend = location.timestamp.timeIntervalSince(lastSent.timestamp)
            if timeSinceLastSend < minimumTimeInterval {
                debugLog("Skipping location update (too soon): \(timeSinceLastSend)s")
                return
            }
        }

        guard let accessToken = TokenManager.shared.accessToken else {
            debugLog("No access token, skipping location update")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/ward/location") else {
            debugLog("Invalid location URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": formatter.string(from: location.timestamp)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                lastSentLocation = location
                debugLog("Location sent successfully: \(location.coordinate)")
            } else {
                debugLog("Location send failed")
            }
        } catch {
            debugLog("Location send error: \(error)")
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[LocationService] \(message)")
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        debugLog("Authorization status changed: \(authorizationStatus.rawValue)")

        if authorizationStatus == .authorizedAlways ||
           authorizationStatus == .authorizedWhenInUse {
            // 권한 승인 후 자동 추적 시작
            if !isTracking {
                startTracking()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        lastLocation = location
        debugLog("Location updated: \(location.coordinate)")

        Task {
            await sendLocationToServer(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugLog("Location error: \(error.localizedDescription)")
    }
}
