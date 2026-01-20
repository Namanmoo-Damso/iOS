import SwiftUI
#if canImport(LiveKit)
import LiveKit

enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case auto = "자동"
    case p360 = "360p"
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"

    var id: String { rawValue }

    var dimensions: Dimensions? {
        switch self {
        case .auto: return nil
        case .p360: return .h360_169
        case .p480: return Dimensions(width: 854, height: 480)
        case .p720: return .h720_169
        case .p1080: return .h1080_169
        }
    }

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .auto: return "자동"
        case .p360: return "SD"
        case .p480: return "SD"
        case .p720: return "HD"
        case .p1080: return "FHD"
        }
    }
}

struct VideoQualitySelector: View {
    @Binding var selectedQuality: VideoQualityPreset
    @Binding var isExpanded: Bool
    var currentResolution: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                // Quality options
                VStack(spacing: 6) {
                    ForEach(VideoQualityPreset.allCases) { quality in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedQuality = quality
                                isExpanded = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(quality.displayName)
                                    .font(.system(size: 16, weight: .medium))

                                if quality == .auto, let resolution = currentResolution {
                                    Text("(\(resolution))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                if quality == selectedQuality {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                quality == selectedQuality
                                    ? Color.white.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }

            // Current quality indicator (toggle button)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))

                    if selectedQuality == .auto {
                        Text("자동")
                            .font(.system(size: 14, weight: .medium))

                        if let resolution = currentResolution {
                            Text("(\(resolution))")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        Text(selectedQuality.displayName)
                            .font(.system(size: 14, weight: .medium))

                        Text(selectedQuality.shortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
            }
        }
    }
}#endif
