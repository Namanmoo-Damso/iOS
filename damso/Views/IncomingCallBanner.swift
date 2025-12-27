import SwiftUI

struct IncomingCallBanner: View {
    let caller: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Incoming Call")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(caller)
                    .font(.headline)
            }

            Spacer()

            Button("Decline") {
                onDecline()
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button("Accept") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .padding(.horizontal)
    }
}
