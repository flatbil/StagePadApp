import SwiftUI

struct SectionButtonWrapper: View {
    let section: Section
    let sectionIndex: Int
    let nextSectionPosition: Double?
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let currentSectionIndex: Int
    let currentPosition: Double
    let onTap: () -> Void

    private var isActive: Bool {
        selectedSongIndex == currentSongIndex && sectionIndex == currentSectionIndex
    }

    private var progress: Double {
        guard isActive else { return 0 }
        let end = nextSectionPosition ?? (section.position + 1)
        let length = end - section.position
        guard length > 0 else { return 0 }
        return (currentPosition - section.position) / length
    }

    var body: some View {
        let style = SectionStyle.style(for: section.name)
        SectionButton(
            label: section.name,
            color: style.color,
            icon: style.icon,
            isActive: isActive,
            progress: progress,
            onTap: onTap
        )
    }
}
