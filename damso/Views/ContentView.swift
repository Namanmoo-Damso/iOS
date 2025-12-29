import Foundation
import SwiftUI
import Combine
import LiveKit

enum AppNavigationState {
    case serverSelection
    case login
    case main
}

struct ContentView: View {
    @State private var navigationState: AppNavigationState = .serverSelection
    @StateObject private var viewModel = DependencyContainer.shared.makeLiveKitViewModel()
    @StateObject private var kakaoAuth = KakaoAuthService.shared

    var body: some View {
        Group {
            switch navigationState {
            case .serverSelection:
                StartView(isServerSelected: Binding(
                    get: { false },
                    set: { if $0 { navigationState = .login } }
                ))
                .transition(.move(edge: .leading))

            case .login:
                KakaoLoginView(isLoggedIn: Binding(
                    get: { false },
                    set: { if $0 { navigationState = .main } }
                ))
                .transition(.move(edge: .trailing))

            case .main:
                LiveKitRoomView(viewModel: viewModel)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: navigationState)
        .onAppear {
            // Check if already logged in
            if kakaoAuth.isLoggedIn {
                navigationState = .main
            }
        }
    }
}
