import SwiftUI

struct TransportBarView: View {
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 24, weight: .bold))
                    Text("PLAY").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(isPlaying ? 0.35 : 1.0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.1, green: 0.45, blue: 0.15).opacity(isPlaying ? 0.4 : 1.0))
            }
            .buttonStyle(.plain)

            Divider().background(.black)

            Button(action: onStop) {
                HStack(spacing: 10) {
                    Image(systemName: "stop.fill").font(.system(size: 24, weight: .bold))
                    Text("STOP").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(isPlaying ? 1.0 : 0.35))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.5, green: 0.1, blue: 0.1).opacity(isPlaying ? 1.0 : 0.4))
            }
            .buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .frame(height: 72)
        .padding(.top, 10)
    }
}
