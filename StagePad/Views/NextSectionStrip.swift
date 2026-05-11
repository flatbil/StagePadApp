import SwiftUI

struct NextSectionStrip: View {
    @EnvironmentObject var pc: PlanningCenterService
    let currentSongName: String
    let currentSectionName: String

    private var matchedSong: PCSong? {
        pc.song(matchingAbletonName: currentSongName)
    }

    private var nextSection: PCSection? {
        guard let song = matchedSong, !currentSectionName.isEmpty else { return nil }
        return pc.nextSection(after: currentSectionName, in: song)
    }

    private var nashvilleForNext: String? {
        guard let song = matchedSong, let next = nextSection else { return nil }
        return song.nashvilleBySection[next.label.lowercased()]
    }

    var body: some View {
        if let next = nextSection {
            HStack(spacing: 10) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                let style = SectionStyle.style(for: next.label)
                RoundedRectangle(cornerRadius: 2)
                    .fill(style.color)
                    .frame(width: 3, height: 16)

                Text(next.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                if let chords = nashvilleForNext, !chords.isEmpty {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.2))
                    Text(chords)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.04))
        }
    }
}
