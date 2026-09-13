import SwiftUI

struct TrackMixerView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss

    private var songName: String {
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return "" }
        return bridge.songs[bridge.currentSongIndex].name
    }

    var body: some View {
        NavigationStack {
            List {
                if bridge.tracks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No tracks found.")
                                .foregroundStyle(.secondary)
                            Text("Connect to Ableton to see tracks.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(bridge.tracks) { track in
                        HStack {
                            Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundStyle(track.isMuted ? Color.gray : Color.green)
                                .frame(width: 24)
                            // Live output meter — commented out for the v1.1 submission.
                            // The bridge-side polling fix was never confirmed against a
                            // real Ableton session (last bridge commit only added
                            // diagnostic logging), so this could easily ship as a visibly
                            // dead control. Mute toggling itself is unaffected and already
                            // shipped/verified — only the meter bar is disabled here.
                            // TrackLevelMeter(level: bridge.trackMeters[track.id] ?? 0)
                            Text(track.name)
                                .foregroundStyle(track.isMuted ? .secondary : .primary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !track.isMuted },
                                set: { _ in bridge.toggleTrackMute(trackIndex: track.id) }
                            ))
                            .labelsHidden()
                            .tint(.green)
                            .disabled(!bridge.isPrimary)
                        }
                        // The Toggle above is the single source of truth for this
                        // action. A row-wide .onTapGesture calling the same
                        // function used to sit here too — tapping the switch could
                        // fire both handlers for one touch, toggling it and then
                        // immediately toggling it back (sending two contradictory
                        // mute commands), which read as "it flips, then flips
                        // back." Removed rather than debounced, since one row =
                        // one action is the less surprising interaction anyway.
                        .opacity(bridge.isPrimary ? 1.0 : 0.6)
                        // Alternating row tint — with the meter bar gone, adjacent
                        // rows had nothing but a hairline separator telling them
                        // apart. track.id is the track's own Ableton index, so
                        // this alternates by actual track order even if a row is
                        // ever missing from the array (malformed bridge data).
                        .listRowBackground(track.id % 2 == 0
                            ? Color.clear
                            : Color.white.opacity(0.045))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(songName.isEmpty ? "Tracks" : "Tracks — \(songName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// Disabled for v1.1 alongside the call site above — re-enable once the
// bridge's meter polling has actually been verified against a live session.
//
// /// A compact live output-level bar, driven by BridgeService.trackMeters —
// /// Ableton's own post-fader, post-mute meter reading (0...1) for that track,
// /// broadcast at ~10Hz. Green through most of its range, warning toward the
// /// top the same way a real channel-strip meter would.
// private struct TrackLevelMeter: View {
//     let level: Double
//
//     private var clamped: Double { min(max(level, 0), 1) }
//
//     private var fillColor: Color {
//         if clamped > 0.9 { return .red }
//         if clamped > 0.7 { return .yellow }
//         return .green
//     }
//
//     var body: some View {
//         GeometryReader { geo in
//             ZStack(alignment: .leading) {
//                 Capsule().fill(Color.white.opacity(0.08))
//                 Capsule()
//                     .fill(fillColor)
//                     .frame(width: max(3, geo.size.width * clamped))
//             }
//         }
//         .frame(width: 46, height: 6)
//         .animation(.easeOut(duration: 0.08), value: clamped)
//     }
// }
