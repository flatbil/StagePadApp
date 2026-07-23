import SwiftUI

/// Launch menu: asks whether to search for the Ableton Bridge or enter demo
/// mode. Nothing happens automatically — the user chooses. Once "Search" is
/// tapped the view shows connection progress; the parent dismisses on connect.
struct LaunchScreenView: View {
    let connectionState: ConnectionState
    var onSearch: () -> Void
    var onDemo: () -> Void
    @EnvironmentObject var bridge: BridgeService
    @State private var pulsing = false
    @State private var showingSettings = false
    @State private var searching = false
    @State private var searchTimedOut = false

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

                if searching { searchingArea } else { menuArea }
            }
            .padding(.bottom, 50)

            // Settings — always available so a manual IP can be entered.
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

    // MARK: - Menu (initial choice)

    private var menuArea: some View {
        VStack(spacing: 16) {
            Text("Connect to your Ableton set, or explore a demo.")
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.bottom, 4)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { searching = true }
                startSearchTimer()
                onSearch()
            } label: {
                menuLabel("Search for Ableton Bridge", icon: "dot.radiowaves.left.and.right", filled: true)
            }
            .buttonStyle(.plain)

            Button { onDemo() } label: {
                menuLabel("Enter Demo Mode", icon: "play.rectangle", filled: false)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Searching (after choosing to connect)

    private var searchingArea: some View {
        VStack(spacing: 14) {
            Text(searchStatus)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.1)).frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.black.opacity(0.4))
                    .frame(width: progressWidth, height: 3)
                    .animation(.easeInOut(duration: 0.4), value: connectionState)
            }
            .frame(width: 160)

            Button { onDemo() } label: {
                menuLabel("Enter Demo Mode", icon: "play.rectangle", filled: false)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button("Back") {
                bridge.disconnect()
                withAnimation(.easeInOut(duration: 0.25)) { searching = false }
                searchTimedOut = false
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.black.opacity(0.35))
        }
    }

    private var searchStatus: String {
        switch connectionState {
        case .rejected:  return "Another device is connected"
        case .connected: return "Connected"
        default:
            return searchTimedOut
                ? "Bridge not found — still searching…\nMake sure the Bridge and Ableton are running\non the same Wi-Fi network."
                : "Searching for Ableton Bridge…"
        }
    }

    private func startSearchTimer() {
        searchTimedOut = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if searching { withAnimation { searchTimedOut = true } }
        }
    }

    // MARK: - Shared

    private func menuLabel(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(filled ? .white : .black.opacity(0.75))
        .padding(.horizontal, 26)
        .padding(.vertical, 13)
        .frame(minWidth: 280)
        .background(
            Capsule().fill(filled ? Color.black.opacity(0.85) : Color.clear)
                .overlay(Capsule().stroke(.black.opacity(filled ? 0 : 0.25), lineWidth: 1.5))
        )
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
