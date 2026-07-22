import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: BridgeService
    @EnvironmentObject var pc: PlanningCenterService
    @State private var selectedSongIndex: Int = 0
    @State private var selectedPCSongIndex: Int = 0
    @State private var pcSetlistOrder: [Int] = []
    @State private var showingSettings = false
    @State private var showingPlan = false
    @State private var karaokeExpanded = false

    private var isArrangementMode: Bool { pc.appMode == .arrangementSheet }

    private var pcOrderBinding: Binding<[Int]> {
        Binding(
            get: {
                guard let plan = pc.currentPlan else { return [] }
                return pcSetlistOrder.count == plan.songs.count
                    ? pcSetlistOrder : Array(0..<plan.songs.count)
            },
            set: { pcSetlistOrder = $0 }
        )
    }

    // Convert PC song into the same Song type the existing grid uses
    private func syntheticSong(from pcSong: PCSong) -> Song {
        let sections = pcSong.sections.enumerated().map { idx, s in
            Section(name: s.displayName, position: Double(idx) * 16.0, cueIndex: idx)
        }
        return Song(name: pcSong.title, position: 0, sections: sections)
    }

    private var currentSongName: String {
        if isArrangementMode { return pc.demoSong?.title ?? "—" }
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return "—" }
        return bridge.songs[bridge.currentSongIndex].name
    }

    private var currentSectionName: String {
        if isArrangementMode { return pc.demoCurrentSection?.displayName ?? "—" }
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return "—" }
        let song = bridge.songs[bridge.currentSongIndex]
        guard song.sections.indices.contains(bridge.currentSectionIndex) else { return "—" }
        return song.sections[bridge.currentSectionIndex].name
    }

    private var currentMeasure: Int {
        guard !isArrangementMode,
              bridge.songs.indices.contains(bridge.currentSongIndex) else { return 1 }
        let sections = bridge.songs[bridge.currentSongIndex].sections
        guard sections.indices.contains(bridge.currentSectionIndex) else { return 1 }
        let beatInSection = max(0, bridge.position - sections[bridge.currentSectionIndex].position)
        return max(1, Int(beatInSection / Double(bridge.timeSignatureNumerator)) + 1)
    }

    private var statusColor: Color {
        if isArrangementMode { return .orange }
        switch bridge.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .red
        }
    }

    // Karaoke is visible when expanded AND there's PC data for the current song
    private var hasPCDataForCurrentSong: Bool {
        if isArrangementMode { return pc.demoSong != nil }
        return pc.song(matchingAbletonName: currentSongName) != nil
    }
    private var karaokeVisible: Bool { karaokeExpanded && hasPCDataForCurrentSong }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    InfoBarView(
                        isPlaying: isArrangementMode ? pc.demoIsPlaying : bridge.isPlaying,
                        isDemo: isArrangementMode,
                        currentSongName: currentSongName,
                        currentSectionName: currentSectionName,
                        tempo: isArrangementMode ? (pc.demoSong?.bpm ?? 0) : bridge.tempo,
                        measure: currentMeasure,
                        statusColor: statusColor,
                        onSettingsTap: { showingSettings = true },
                        onPlanTap: { showingPlan = true },
                        onKaraokeTap: {
                            guard hasPCDataForCurrentSong else { return }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                karaokeExpanded.toggle()
                            }
                        },
                        karaokeActive: karaokeVisible
                    )

                    // Song selector — same component in both modes
                    if isArrangementMode, let plan = pc.currentPlan {
                        let pcSongs = plan.songs.map { syntheticSong(from: $0) }
                        let demoIdx = plan.songs.firstIndex(where: { $0.id == pc.demoSong?.id }) ?? -1
                        SongSelectorView(
                            songs: pcSongs,
                            setlistOrder: pcOrderBinding,
                            selectedSongIndex: selectedPCSongIndex,
                            currentSongIndex: demoIdx,
                            onSelect: { idx in
                                selectedPCSongIndex = idx
                                pc.setDemoSong(plan.songs[idx])
                            }
                        )
                    } else {
                        SongSelectorView(
                            songs: bridge.songs,
                            setlistOrder: $bridge.setlistOrder,
                            selectedSongIndex: selectedSongIndex,
                            currentSongIndex: bridge.currentSongIndex,
                            onSelect: { selectedSongIndex = $0 }
                        )
                    }

                    // Karaoke panel — capped at 45% screen height, works in both modes
                    if karaokeVisible {
                        MDKaraokePanel()
                            .environmentObject(pc)
                            .environmentObject(bridge)
                            .frame(height: geo.size.height * 0.45)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Section grid — SAME component in both modes
                    if isArrangementMode {
                        if let demoSong = pc.demoSong {
                            SectionGridView(
                                song: syntheticSong(from: demoSong),
                                selectedSongIndex: 0,
                                currentSongIndex: 0,
                                currentSectionIndex: pc.demoSectionIndex,
                                onTap: { pc.setDemoSection(index: $0) }
                            )
                        } else {
                            emptyState
                        }
                    } else if bridge.songs.indices.contains(selectedSongIndex) {
                        SectionGridView(
                            song: bridge.songs[selectedSongIndex],
                            selectedSongIndex: selectedSongIndex,
                            currentSongIndex: bridge.currentSongIndex,
                            currentSectionIndex: bridge.currentSectionIndex,
                            onTap: { bridge.jump(songIndex: selectedSongIndex, sectionIndex: $0) }
                        )
                    } else {
                        emptyState
                    }

                    if !karaokeVisible && !isArrangementMode {
                        NextSectionStrip(
                            currentSongName: currentSongName,
                            currentSectionName: currentSectionName
                        )
                        .environmentObject(pc)
                    }

                    TransportBarView(
                        isPlaying: isArrangementMode ? pc.demoIsPlaying : bridge.isPlaying,
                        isConnected: isArrangementMode ? true : (bridge.connectionState == .connected),
                        onPlay: { if isArrangementMode { pc.demoPlay() } else { bridge.play() } },
                        onStop: { if isArrangementMode { pc.demoStop() } else { bridge.stop() } }
                    )
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(bridge)
                .environmentObject(pc)
        }
        .sheet(isPresented: $showingPlan) {
            PlanView()
                .environmentObject(pc)
                .environmentObject(bridge)
        }
        .onAppear { bridge.connect() }
        .onChange(of: bridge.currentSongIndex) { _, newIndex in
            if newIndex >= 0 { selectedSongIndex = newIndex }
        }
        .onChange(of: pc.currentPlan) { _, plan in
            if let plan = plan {
                pcSetlistOrder = Array(0..<plan.songs.count)
                selectedPCSongIndex = 0
            }
        }
        .onChange(of: pc.demoSong) { _, song in
            if song != nil && !karaokeExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    karaokeExpanded = true
                }
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
