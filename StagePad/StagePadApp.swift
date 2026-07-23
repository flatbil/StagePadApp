import SwiftUI

@main
struct StagePadApp: App {
    @StateObject private var bridge = BridgeService()
    @State private var showLaunch = true
    @State private var showDemoWelcome = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(bridge)
                    .preferredColorScheme(.dark)

                if showLaunch {
                    LaunchScreenView(connectionState: bridge.connectionState) {
                        withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                        if bridge.connectionState != .connected {
                            bridge.enterDemoMode()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showDemoWelcome = true
                            }
                        }
                    }
                    .environmentObject(bridge)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .onChange(of: bridge.connectionState) { _, state in
                if state == .connected && showLaunch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showLaunch = false
                        }
                    }
                }
            }
            // Safety net so the launch screen can never hang (App Store 2.1(a)).
            // The launch screen surfaces an explicit "Explore Demo" button at ~3s;
            // this fires a few seconds later for reviewers who don't tap it.
            .task {
                try? await Task.sleep(for: .seconds(6))
                if showLaunch {
                    withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                    if bridge.connectionState != .connected {
                        bridge.enterDemoMode()
                        try? await Task.sleep(for: .seconds(0.6))
                        showDemoWelcome = true
                    }
                }
            }
            .sheet(isPresented: $showDemoWelcome) {
                DemoWelcomeView(isPresented: $showDemoWelcome)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
