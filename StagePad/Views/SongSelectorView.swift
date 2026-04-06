import SwiftUI

struct SongSelectorView: View {
    let songs: [Song]
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 8) {
                ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                    SongPillButton(
                        song: song,
                        index: index,
                        isSelected: index == selectedSongIndex,
                        isActive: index == currentSongIndex,
                        onTap: { onSelect(index) }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 72)
        .background(Color.white.opacity(0.03))
        // Extra invisible tap-buffer below so section buttons aren't accidentally hit
        .contentShape(Rectangle())
    }
}

private struct SongPillButton: View {
    let song: Song
    let index: Int
    let isSelected: Bool
    let isActive: Bool
    let onTap: () -> Void

    private var color: Color { Song.songColor(for: index) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: Song.songIcon(for: index))
                    .font(.system(size: 14))
                Text(song.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? color : color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isActive ? Color.white.opacity(0.7) : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
