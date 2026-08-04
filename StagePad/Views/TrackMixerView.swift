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
            Group {
                if bridge.tracks.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Tracks")
                            .font(.title3.weight(.semibold))
                        Text("Connect to Ableton to see tracks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List(bridge.tracks) { track in
                        HStack {
                            Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundStyle(track.isMuted ? .secondary : .green)
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
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { bridge.toggleTrackMute(trackIndex: track.id) }
                    }
                    .listStyle(.insetGrouped)
                }
            }
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
