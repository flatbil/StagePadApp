import SwiftUI

struct TransportBarView: View {
    let isPlaying: Bool
    let isConnected: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 24, weight: .bold))
                    Text("PLAY").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(isConnected ? (isPlaying ? 0.35 : 1.0) : 0.2))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.1, green: 0.45, blue: 0.15).opacity(isConnected ? (isPlaying ? 0.4 : 1.0) : 0.15))
            }
            .buttonStyle(.plain)
            .disabled(!isConnected)

            Divider().background(.black)

            Button(action: onStop) {
                HStack(spacing: 10) {
                    Image(systemName: "stop.fill").font(.system(size: 24, weight: .bold))
                    Text("STOP").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(isConnected ? (isPlaying ? 1.0 : 0.35) : 0.2))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.5, green: 0.1, blue: 0.1).opacity(isConnected ? (isPlaying ? 1.0 : 0.4) : 0.15))
            }
            .buttonStyle(.plain)
            .disabled(!isConnected)
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .animation(.easeInOut(duration: 0.2), value: isConnected)
        .frame(height: 72)
        .padding(.top, 10)
    }
}
