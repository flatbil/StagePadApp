import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var selectedSongIndex: Int = 0
    @State private var showingSettings = false

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

    private var statusColor: Color {
        switch bridge.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .red
        }
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
                    position: bridge.position,
                    statusColor: statusColor,
                    onSettingsTap: { showingSettings = true }
                )

                SongSelectorView(
                    songs: bridge.songs,
                    selectedSongIndex: selectedSongIndex,
                    currentSongIndex: bridge.currentSongIndex,
                    onSelect: { selectedSongIndex = $0 }
                )

                if bridge.songs.indices.contains(selectedSongIndex) {
                    let nextSongStart: Double? = bridge.songs.indices.contains(selectedSongIndex + 1)
                        ? bridge.songs[selectedSongIndex + 1].position : nil
                    SectionGridView(
                        song: bridge.songs[selectedSongIndex],
                        selectedSongIndex: selectedSongIndex,
                        currentSongIndex: bridge.currentSongIndex,
                        currentSectionIndex: bridge.currentSectionIndex,
                        currentPosition: bridge.position,
                        nextSongStartPosition: nextSongStart,
                        onTap: { bridge.jump(songIndex: selectedSongIndex, sectionIndex: $0) }
                    )
                } else {
                    emptyState
                }

                TransportBarView(
                    onPlay: { bridge.play() },
                    onStop: { bridge.stop() }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(bridge)
        }
        .onAppear { bridge.connect() }
        .onChange(of: bridge.currentSongIndex) { _, newIndex in
            if newIndex >= 0 { selectedSongIndex = newIndex }
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
