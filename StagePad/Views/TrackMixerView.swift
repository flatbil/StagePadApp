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
