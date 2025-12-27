import Foundation
import SwiftUI
import Combine
#if canImport(LiveKit)
import LiveKit
#endif

struct ContentView: View {
    #if canImport(LiveKit)
    @StateObject private var viewModel = LiveKitViewModel()

    var body: some View {
        LiveKitRoomView(viewModel: viewModel)
    }
    #else
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text("LiveKit not available in this build.")
                .font(.headline)
            Text("Add the LiveKit Swift Package or build for a supported platform.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    #endif
}

#Preview {
    ContentView()
}
