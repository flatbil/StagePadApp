import SwiftUI

@main
struct StagePadApp: App {
    @StateObject private var bridge = BridgeService()
    @State private var showLaunch = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

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
            // Entering demo from anywhere (menu, search, Settings) leaves the menu.
            .onChange(of: bridge.isDemoMode) { _, demo in
                if demo && showLaunch {
                    withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                }
            }
            .onAppear {
                // Screenshot automation hook — never present outside `simctl launch --args`.
                if ProcessInfo.processInfo.arguments.contains("-UITestDemoMode") {
                    hasSeenOnboarding = true
                    bridge.enterDemoMode()
                    bridge.play()
                    showLaunch = false
                    // Screenshot automation hook — shows the Observer experience
                    // (badge, dimmed non-interactive grid) using the same demo
                    // content, without needing a second physical device synced
                    // to a live bridge.
                    if ProcessInfo.processInfo.arguments.contains("-UITestForceObserver") {
                        bridge.isPrimary = false
                        bridge.myConnectionID = "demo-self"
                        bridge.roster = [
                            RosterDevice(connectionID: "demo-md", name: "MD's iPad", role: "primary"),
                            RosterDevice(connectionID: "demo-self", name: bridge.deviceName, role: "observer"),
                            RosterDevice(connectionID: "demo-2", name: "Bob's iPhone", role: "observer"),
                        ]
                    }
                    return
                }
                if !hasSeenOnboarding { showOnboarding = true }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
            }
        }
    }
}
