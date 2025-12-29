import UIKit
import Darwin

// MARK: - Device Call Capability

enum DeviceCallCapability {
    case callKit           // iPhone, Cellular iPad
    case notificationOnly  // WiFi-only iPad
}

/// Cellular 네트워크 지원 여부로 CallKit 사용 가능성 판단
/// WiFi-only iPad는 Cellular를 지원하지 않으므로 VoIP Push + CallKit 조합이 불안정
func resolveCallCapability() -> DeviceCallCapability {
    let idiom = UIDevice.current.userInterfaceIdiom
    let hasCellular = hasCellularHardware()

    #if DEBUG
    print("[CallCapability] idiom=\(idiom == .phone ? "phone" : "pad") hasCellular=\(hasCellular)")
    #endif

    // iPhone은 항상 CallKit 지원
    if idiom == .phone {
        return .callKit
    }

    // iPad: Cellular 하드웨어 존재 여부 확인
    if hasCellular {
        return .callKit
    }

    // WiFi-only iPad
    return .notificationOnly
}

/// Cellular 모뎀 하드웨어 존재 여부 확인 (네트워크 인터페이스 기반)
/// pdp_ip 인터페이스가 존재하면 Cellular 모뎀이 있는 것
private func hasCellularHardware() -> Bool {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addrs) == 0, let firstAddr = addrs else {
        return false
    }
    defer { freeifaddrs(addrs) }

    var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let current = ptr {
        let name = String(cString: current.pointee.ifa_name)
        // pdp_ip0, pdp_ip1 등은 Cellular 전용 인터페이스
        if name.hasPrefix("pdp_ip") {
            return true
        }
        ptr = current.pointee.ifa_next
    }

    return false
}
