import SwiftUI

struct LaunchScreenView: View {
    let connectionState: ConnectionState
    var onSkip: (() -> Void)? = nil
    @EnvironmentObject var bridge: BridgeService
    @State private var pulsing = false
    @State private var showingSettings = false
    /// Flips true after a short search window so we can move from a neutral
    /// "Searching…" state to an explicit "not found — explore a demo" prompt.
    @State private var searchTimedOut = false

    // How long to look for the bridge before offering the demo explicitly.
    private let searchWindow: Double = 3.0

    // True once we've searched and still have no live bridge connection.
    private var bridgeNotFound: Bool {
        searchTimedOut && connectionState != .connected && connectionState != .rejected
    }

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

                statusArea
                    .padding(.bottom, 50)
            }

            // Settings button — always accessible so an IP can be set manually
            // (e.g. if Bonjour discovery is blocked on the venue network).
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
        .task {
            try? await Task.sleep(for: .seconds(searchWindow))
            withAnimation(.easeInOut(duration: 0.35)) { searchTimedOut = true }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(bridge)
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if connectionState == .rejected {
            // Another iPad already holds the live connection.
            VStack(spacing: 12) {
                Text("Another device is connected")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.45))
                demoButton(title: "Explore Demo Instead")
            }
        } else if bridgeNotFound {
            // Searched, no Mac bridge found — present the demo as a clear,
            // intentional choice rather than a silent timeout.
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("Ableton Bridge not found")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.7))
                    Text("MD Buddy connects to Ableton Live through the Bridge app on your Mac. Make sure the Bridge is running, an Ableton session is open, and both devices are on the same Wi-Fi network.")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 380)
                }
                demoButton(title: "Explore Demo")
            }
            .transition(.opacity)
        } else {
            // Actively searching (or just connected — parent dismisses shortly).
            VStack(spacing: 10) {
                Text(connectionState == .connected ? "Connected" : "Searching for Ableton Bridge…")
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
            }
        }
    }

    private func demoButton(title: String) -> some View {
        Button { onSkip?() } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Capsule().fill(.black.opacity(0.85)))
        }
        .padding(.top, 2)
    }

    private var progressWidth: CGFloat {
        switch connectionState {
        case .disconnected: return 40
        case .connecting:   return 100
        case .connected:    return 160
        case .rejected:     return 40
        }
    }
}
