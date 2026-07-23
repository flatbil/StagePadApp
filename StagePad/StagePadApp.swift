import SwiftUI

@main
struct StagePadApp: App {
    @StateObject private var bridge = BridgeService()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(onExitToMenu: {
                    bridge.exitDemoMode()
                    withAnimation(.easeInOut(duration: 0.4)) { showLaunch = true }
                })
                .environmentObject(bridge)
                .preferredColorScheme(.dark)

                if showLaunch {
                    LaunchScreenView(
                        connectionState: bridge.connectionState,
                        onSearch: { bridge.connect() },
                        onDemo: {
                            bridge.enterDemoMode()
                            withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                        }
                    )
                    .environmentObject(bridge)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            // Bridge found while the menu is up → proceed to live mode.
            .onChange(of: bridge.connectionState) { _, state in
                if state == .connected && showLaunch {
                    withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                }
            }
        }
    }
}
