import SwiftUI

struct SectionGridView: View {
    let song: Song
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let currentSectionIndex: Int
    let currentPosition: Double
    let nextSongStartPosition: Double?  // start of the following song, for last-section progress
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let columns = max(2, min(5, song.sections.count))
            let spacing: CGFloat = 10
            let hPad: CGFloat = 12
            let btnWidth = (geo.size.width - spacing * CGFloat(columns - 1) - hPad * 2) / CGFloat(columns)
            let rows = Int(ceil(Double(song.sections.count) / Double(columns)))
            let btnHeight = max(80, (geo.size.height - spacing * CGFloat(rows - 1) - 12) / CGFloat(rows))
            let gridColumns = Array(repeating: GridItem(.fixed(btnWidth), spacing: spacing), count: columns)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: spacing) {
                    ForEach(Array(song.sections.enumerated()), id: \.offset) { sectionIndex, section in
                        let isLastSection = sectionIndex + 1 == song.sections.count
                        let next: Double? = !isLastSection
                            ? song.sections[sectionIndex + 1].position
                            : nextSongStartPosition
                        SectionButtonWrapper(
                            section: section,
                            sectionIndex: sectionIndex,
                            nextSectionPosition: next,
                            selectedSongIndex: selectedSongIndex,
                            currentSongIndex: currentSongIndex,
                            currentSectionIndex: currentSectionIndex,
                            currentPosition: currentPosition,
                            onTap: { onTap(sectionIndex) }
                        )
                        .frame(height: btnHeight)
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
        }
    }
}
