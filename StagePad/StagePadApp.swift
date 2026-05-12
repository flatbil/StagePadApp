import SwiftUI

@main
struct StagePadApp: App {
    @StateObject private var bridge = BridgeService()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(bridge)
                    .preferredColorScheme(.dark)

                if showLaunch {
                    LaunchScreenView(connectionState: bridge.connectionState) {
                        withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
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
            .task {
                // Always dismiss after 5 s — reviewers and users without Ableton shouldn't wait forever
                try? await Task.sleep(for: .seconds(5))
                if showLaunch {
                    withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                }
            }
        }
    }
}
