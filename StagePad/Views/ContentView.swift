import SwiftUI

struct ContentView: View {
    let onExitToMenu: () -> Void
    @EnvironmentObject var bridge: BridgeService
    @State private var selectedSongIndex: Int = 0
    @State private var showingSettings = false
    @State private var showingTracks = false

    private var currentSongName: String {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return "—" }
        return bridge.songs[bridge.currentSongIndex].name
    }

    private var currentSectionName: String {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return "—" }
        let song = bridge.songs[bridge.currentSongIndex]
        guard song.sections.indices.contains(bridge.currentSectionIndex) else { return "—" }
        return song.sections[bridge.currentSectionIndex].name
    }

    private var currentMeasure: Int {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return 1 }
        let sections = bridge.songs[bridge.currentSongIndex].sections
        guard sections.indices.contains(bridge.currentSectionIndex) else { return 1 }
        let sectionStart = sections[bridge.currentSectionIndex].position
        let beatInSection = max(0, bridge.position - sectionStart)
        return max(1, Int(beatInSection / Double(bridge.timeSignatureNumerator)) + 1)
    }

    private var statusColor: Color {
        if ProcessInfo.processInfo.arguments.contains("-UITestDemoMode") { return .green }
        if bridge.isDemoMode { return .orange }
        switch bridge.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .red
        case .rejected:     return .red
        }
    }

    /// This device currently holds control (primary + actually connected, or
    /// demo mode) — shown with a border so a room full of identical-looking
    /// iPads makes it obvious at a glance who's driving.
    private var isInCommand: Bool {
        (bridge.connectionState == .connected && bridge.isPrimary) || bridge.isDemoMode
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                InfoBarView(
                    isPlaying: bridge.isPlaying,
                    currentSongName: currentSongName,
                    currentSectionName: currentSectionName,
                    tempo: bridge.tempo,
                    measure: currentMeasure,
                    statusColor: statusColor,
                    isDemo: bridge.isDemoMode && !ProcessInfo.processInfo.arguments.contains("-UITestDemoMode"),
                    isObserver: !bridge.isPrimary && bridge.connectionState == .connected,
                    onSettingsTap: { showingSettings = true },
                    onTracksTap: { showingTracks = true },
                    onDemoTap: onExitToMenu
                )

                SongSelectorView(
                    songs: bridge.songs,
                    setlistOrder: $bridge.setlistOrder,
                    selectedSongIndex: selectedSongIndex,
                    currentSongIndex: bridge.currentSongIndex,
                    onSelect: { selectedSongIndex = $0 }
                )

                if bridge.songs.indices.contains(selectedSongIndex) {
                    SectionGridView(
                        song: bridge.songs[selectedSongIndex],
                        selectedSongIndex: selectedSongIndex,
                        currentSongIndex: bridge.currentSongIndex,
                        currentSectionIndex: bridge.currentSectionIndex,
                        onTap: { bridge.jump(songIndex: selectedSongIndex, sectionIndex: $0) }
                    )
                    // Observers can still scroll/browse sections to look ahead —
                    // this only blocks the tap-to-jump gesture. jump() also
                    // guards server-side, so this is a UX cue, not the only gate.
                    .allowsHitTesting(bridge.isPrimary)
                    .opacity(bridge.isPrimary ? 1.0 : 0.6)
                } else {
                    emptyState
                }

                TransportBarView(
                    isPlaying: bridge.isPlaying,
                    // Demo mode drives its own local playback, so enable transport
                    // there too (not just on a live bridge connection). Observers
                    // never get transport control.
                    isConnected: (bridge.connectionState == .connected || bridge.isDemoMode) && bridge.isPrimary,
                    onPlay: { bridge.play() },
                    onStop: { bridge.stop() }
                )
            }
            // Always-present margin (not conditional on isInCommand) so content
            // doesn't shift/resize when control changes hands — the border below
            // lives in this gap instead of drawing on top of the content.
            .padding(10)
        }
        .overlay {
            if isInCommand {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.green, lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(bridge)
        }
        .sheet(isPresented: $showingTracks) {
            TrackMixerView().environmentObject(bridge)
        }
        .alert("Too Many Markers", isPresented: $bridge.showCueWarning) {
            Button("OK") { bridge.showCueWarning = false }
        } message: {
            Text("Your Ableton set has \(bridge.cueCount) cue markers — above the recommended limit of 500. At very high counts, some markers may not be received. Consider splitting your set across multiple Ableton projects.")
        }
        .onChange(of: bridge.currentSongIndex) { _, newIndex in
            if newIndex >= 0 { selectedSongIndex = newIndex }
        }
        .onAppear {
            // Screenshot automation hooks — never present outside `simctl launch --args`.
            if ProcessInfo.processInfo.arguments.contains("-UITestShowTracks") {
                showingTracks = true
            }
            if ProcessInfo.processInfo.arguments.contains("-UITestShowSettings") {
                showingSettings = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.15))
            Text("No songs loaded")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.3))
            Text("Open a project in Ableton with\n== Song Name == markers")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
