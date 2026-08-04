import SwiftUI

struct SectionButtonWrapper: View {
    @EnvironmentObject var bridge: BridgeService

    let section: Section
    let sectionIndex: Int
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let currentSectionIndex: Int
    let onTap: () -> Void

    private var isActive: Bool {
        selectedSongIndex == currentSongIndex && sectionIndex == currentSectionIndex
    }

    private var isQueued: Bool {
        selectedSongIndex == bridge.queuedSongIndex && sectionIndex == bridge.queuedSectionIndex
    }

    var body: some View {
        let style = SectionStyle.style(for: section.name)
        if isActive {
            // TimelineView drives 30fps smooth rendering from wall-clock + BPM math.
            // No @Published updates means no view-tree churn — progress is display-sync'd.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                SectionButton(
                    label: section.name,
                    color: style.color,
                    icon: style.icon,
                    isActive: true,
                    isQueued: false,
                    progress: computedProgress(at: tl.date),
                    danceDate: bridge.isPlaying ? tl.date : nil,
                    onTap: onTap
                )
            }
        } else {
            SectionButton(
                label: section.name,
                color: style.color,
                icon: style.icon,
                isActive: false,
                isQueued: isQueued,
                progress: 0,
                danceDate: nil,
                onTap: onTap
            )
        }
    }

    private func computedProgress(at now: Date) -> Double {
        let length = bridge.sectionEndBeat - bridge.sectionStartBeat
        // Prefer measured tempo (derived from actual beat timing) over reported tempo.
        // This handles per-song BPM changes and stale AbletonOSC tempo values.
        let bpm = bridge.interpolationTempo > 0 ? bridge.interpolationTempo : bridge.tempo
        guard bpm > 0, length > 0 else { return 0 }

        let anchorBeat: Double
        if bridge.isPlaying {
            let elapsed = max(0, now.timeIntervalSince(bridge.sectionAnchorDate))
            anchorBeat = bridge.sectionAnchorBeat + elapsed * bpm / 60.0
        } else {
            anchorBeat = bridge.sectionAnchorBeat
        }

        return min(1.0, max(0, (anchorBeat - bridge.sectionStartBeat) / length))
    }
}
