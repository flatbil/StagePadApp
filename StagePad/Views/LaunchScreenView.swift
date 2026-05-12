import SwiftUI

struct LaunchScreenView: View {
    let connectionState: ConnectionState
    var onSkip: (() -> Void)? = nil
    @EnvironmentObject var bridge: BridgeService
    @State private var pulsing = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("GatewayIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulsing ? 1.08 : 0.95)
                    .opacity(pulsing ? 1.0 : 0.65)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsing)

                Spacer()

                // Connection status + progress bar
                VStack(spacing: 10) {
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.black.opacity(0.1))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.black.opacity(0.4))
                            .frame(width: progressWidth, height: 3)
                            .animation(.easeInOut(duration: 0.4), value: connectionState)
                    }
                    .frame(width: 160)

                    if connectionState != .connected {
                        Button("Skip") { onSkip?() }
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.3))
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 50)
            }

            // Settings button — always accessible so IP can be set while connecting
            VStack {
                HStack {
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundStyle(.black.opacity(0.3))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .onAppear { pulsing = true }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(bridge)
        }
    }

    private var statusLabel: String {
        switch connectionState {
        case .disconnected: return "Connecting…"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        }
    }

    private var progressWidth: CGFloat {
        switch connectionState {
        case .disconnected: return 40
        case .connecting:   return 100
        case .connected:    return 160
        }
    }
}
