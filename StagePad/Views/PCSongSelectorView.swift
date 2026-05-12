import SwiftUI

struct PCSongSelectorView: View {
    let songs: [PCSong]
    let selectedIndex: Int
    let demoSongID: UUID?
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(songs.enumerated()), id: \.offset) { idx, song in
                    pill(song: song, index: idx)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.03))
    }

    private func pill(song: PCSong, index: Int) -> some View {
        let isSelected = selectedIndex == index
        let isDemo = demoSongID == song.id
        let color = Song.palette[index % Song.palette.count]
        let icon = Song.songIcons[index % Song.songIcons.count]

        return Button { onSelect(index) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if !song.key.isEmpty {
                    Text(song.key)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(isSelected ? 1.0 : 0.5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isDemo ? Color.orange : Color.white,
                            lineWidth: isDemo ? 2 : (isSelected ? 2 : 0))
            )
        }
        .buttonStyle(.plain)
    }
}
