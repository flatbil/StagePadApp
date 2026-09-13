import SwiftUI
import PhotosUI

/// Per-song background picker (color or image) — split out from the main
/// Settings list into its own screen (2026-09-12) since the row list grows
/// with the setlist and this is a set-once-per-song styling concern, not
/// something glanced at on every visit to Settings the way connection/device
/// info is.
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
                        SongBackgroundRow(song: song, index: index)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()
        }
        .navigationTitle("Song Backgrounds")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One song's row: name + color swatch on top, custom background image below.
/// A custom image (once set) takes priority over both the color tint and any
/// auto-fetched iTunes art — see BridgeService.customSongImages.
private struct SongBackgroundRow: View {
    @EnvironmentObject var bridge: BridgeService
    let song: Song
    let index: Int

    @State private var pickerItem: PhotosPickerItem?

    private var customImage: UIImage? { bridge.customSongImages[song.name] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                // Enlarged from ColorPicker's default (~28pt) swatch — that
                // hitbox was a real fumble target on stage. 44x44 matches
                // Apple's own minimum recommended tap target, and the swatch
                // itself grows to match since ColorPicker scales its chrome
                // to the frame it's given.
                ColorPicker("", selection: Binding(
                    get: { bridge.resolvedColor(for: song, index: index) },
                    set: { bridge.setSongColor($0, forSongNamed: song.name) }
                ))
                .labelsHidden()
                .frame(width: 44, height: 44)
            }

            HStack(spacing: 12) {
                Text("Background Image")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if customImage != nil {
                    Button {
                        bridge.setCustomImage(nil, forSongNamed: song.name)
                        pickerItem = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Group {
                        if let customImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.3)))
                }
            }
        }
        .padding()
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    bridge.setCustomImage(image, forSongNamed: song.name)
                }
            }
        }
    }
}
