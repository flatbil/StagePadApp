import SwiftUI

@main
struct StagePadApp: App {
    @StateObject private var bridge = BridgeService()
    @StateObject private var pc = PlanningCenterService()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(bridge)
                    .environmentObject(pc)
                    .preferredColorScheme(.dark)
                    .task { await pc.fetchCurrentPlan() }

                if showLaunch {
                    LaunchScreenView(connectionState: bridge.connectionState)
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
        }
    }
}
