import SwiftUI

/// Per-song background color picker — split out from the main Settings list
/// into its own screen (2026-09-12) since the row list grows with the
/// setlist and this is a set-once-per-song styling concern, not something
/// glanced at on every visit to Settings the way connection/device info is.
struct SongColorsView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if bridge.songs.isEmpty {
                    Text("Connect to Ableton to see songs here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(bridge.songs.enumerated()), id: \.element.id) { index, song in
                        if index > 0 { Divider() }
                        HStack(spacing: 12) {
                            Text(song.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if bridge.songColors[song.name] != nil {
                                Button {
                                    bridge.setSongColor(nil, forSongNamed: song.name)
                                } label: {
                                    Image(systemName: "arrow.counterclockwise.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            // Enlarged from ColorPicker's default (~28pt) swatch —
                            // that hitbox was a real fumble target on stage. 44x44
                            // matches Apple's own minimum recommended tap target,
                            // and the swatch itself grows to match since
                            // ColorPicker scales its chrome to the frame it's given.
                            ColorPicker("", selection: Binding(
                                get: { bridge.resolvedColor(for: song, index: index) },
                                set: { bridge.setSongColor($0, forSongNamed: song.name) }
                            ))
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()
        }
        .navigationTitle("Song Colors")
        .navigationBarTitleDisplayMode(.inline)
    }
}
