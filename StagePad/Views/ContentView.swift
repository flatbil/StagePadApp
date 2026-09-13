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
        if ProcessInfo.processInfo.arguments.contains("-UITestForceObserver") { return false }
        return (bridge.connectionState == .connected && bridge.isPrimary) || bridge.isDemoMode
    }

    /// Every song gets a subdued, distinct background — its custom color if
    /// one's been picked (Settings → Song Colors), else the same auto-cycled
    /// palette the selector pills already use, so differentiation is on by
    /// default rather than something you have to configure per song first.
    private var currentSongBackgroundColor: Color? {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return nil }
        return bridge.resolvedColor(for: bridge.songs[bridge.currentSongIndex], index: bridge.currentSongIndex)
    }

    /// The device's actual screen corner radius, so the "in command" border
    /// below hugs the real bezel curve instead of cutting across it. iOS has
    /// no public API for this — `_displayCornerRadius` is a long-standing,
    /// widely-used KVC read on UIScreen (not a linked private symbol, so it
    /// doesn't trip App Review's binary scan), with a safe fallback to the
    /// old fixed value for any device/OS where the key isn't there.
    private var deviceCornerRadius: CGFloat {
        (UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat).flatMap { $0 > 0 ? $0 : nil } ?? 20
    }

    /// Background image for the current song, highest priority first: a
    /// user-picked image (Settings → Song Backgrounds) beats the auto-fetched
    /// iTunes art, which beats nothing at all (falls through to the color
    /// tint below). nil here just means neither is set/loaded yet — never an
    /// error state, and never something this screen depends on.
    private var currentSongArt: UIImage? {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return nil }
        let name = bridge.songs[bridge.currentSongIndex].name
        return bridge.customSongImages[name] ?? bridge.albumArt[name]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let art = currentSongArt {
                // Heavily blurred + darkened so it reads as ambiance behind
                // the UI, not competing with it for attention or hurting
                // the readability every foreground element depends on.
                //
                // .scaledToFit(), not .scaledToFill(): iTunes art is always a
                // 600x600 square, and *covering* an iPad's much taller/wider
                // screen (fill mode) forces a ~4-5x upscale — confirmed live
                // as both "way too big" (fill mode can paint past its own
                // frame per Apple's documented caveat) and, once clipped,
                // still an oversized, illegible wash even at a heavier blur
                // radius, because so much of what's on screen was just a few
                // magnified pixels of the original art. Fit mode scales the
                // whole square to the screen's *narrower* dimension instead
                // (~1.5-2x on an iPad, not 4-5x) — the art stays recognizable,
                // letterboxed top/bottom or side/side into the black base
                // layer, which the blur then feathers into rather than
                // needing to hide a zoomed-in mess. Blur/overlay retuned again
                // (40/0.5 -> 20/0.25) after confirming live against Way
                // Maker's cover (a high-contrast black & white photo) that the
                // old values crushed it into an unrecognizable gray fog —
                // simulated the exact render pipeline locally across a grid of
                // blur/overlay values against the real downloaded artwork to
                // pick this pair rather than guess through more rebuilds.
                GeometryReader { geo in
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 20)
                        .overlay(Color.black.opacity(0.25))
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: bridge.currentSongIndex)
            } else if let tint = currentSongBackgroundColor {
                tint.opacity(0.22)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: bridge.currentSongIndex)
            }
            VStack(spacing: 0) {
                InfoBarView(
                    isPlaying: bridge.isPlaying,
                    currentSongName: currentSongName,
                    currentSectionName: currentSectionName,
                    tempo: bridge.tempo,
                    measure: currentMeasure,
                    statusColor: statusColor,
                    isDemo: bridge.isDemoMode && !ProcessInfo.processInfo.arguments.contains("-UITestDemoMode"),
                    isObserver: (!bridge.isPrimary && bridge.connectionState == .connected)
                        || ProcessInfo.processInfo.arguments.contains("-UITestForceObserver"),
                    // Only meaningful once we're actually talking to the bridge —
                    // a dead bridge connection already shows red via statusColor,
                    // no need to also flash this and double up the "something's
                    // wrong" signal with two different badges at once.
                    isAbletonOffline: bridge.connectionState == .connected && !bridge.abletonConnected,
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
                RoundedRectangle(cornerRadius: deviceCornerRadius, style: .continuous)
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
