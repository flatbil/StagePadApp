import SwiftUI

struct MDKaraokePanel: View {
    @EnvironmentObject var pc: PlanningCenterService
    @EnvironmentObject var bridge: BridgeService
    @State private var showNashville = true

    // Resolve active PC song from whichever mode is running
    private var activeSong: PCSong? {
        if pc.appMode == .arrangementSheet {
            return pc.demoSong
        }
        guard bridge.songs.indices.contains(bridge.currentSongIndex) else { return nil }
        return pc.song(matchingAbletonName: bridge.songs[bridge.currentSongIndex].name)
    }

    // Resolve active PC section label from whichever mode is running
    private var activeSectionLabel: String {
        if pc.appMode == .arrangementSheet {
            return pc.demoCurrentSection?.label ?? ""
        }
        guard bridge.songs.indices.contains(bridge.currentSongIndex),
              bridge.songs[bridge.currentSongIndex].sections.indices.contains(bridge.currentSectionIndex)
        else { return "" }
        return bridge.songs[bridge.currentSongIndex].sections[bridge.currentSectionIndex].name
    }

    private var activeSection: PCSection? {
        guard let song = activeSong else { return nil }
        if pc.appMode == .arrangementSheet { return pc.demoCurrentSection }
        let label = activeSectionLabel.lowercased()
        return song.sections.first {
            $0.label.lowercased() == label || $0.displayName.lowercased() == label
        }
    }

    private var nextSection: PCSection? {
        guard let song = activeSong, let current = activeSection,
              let idx = song.sections.firstIndex(where: { $0.id == current.id })
        else { return nil }
        let next = idx + 1
        return next < song.sections.count ? song.sections[next] : nil
    }

    private var style: SectionStyle { SectionStyle.style(for: activeSection?.label ?? "") }

    private var chordsEmptyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            if activeSong?.chordChart == nil {
                Text("No chord chart in Planning Center.")
                    .italic()
                Text("Add one in Services → Songs → Arrangements → chord chart field.")
                    .font(.system(size: 12))
            } else if activeSong?.key.isEmpty == true {
                Text("Chord chart found but no key is set.")
                    .italic()
                Text("Set the key on the arrangement in Planning Center.")
                    .font(.system(size: 12))
            } else {
                let keys = activeSong?.nashvilleBySection.keys.sorted().joined(separator: ", ") ?? ""
                Text("No chords for this section — chart may be lyrics-only.")
                    .italic()
                if !keys.isEmpty {
                    Text("Chart sections: \(keys)")
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .foregroundStyle(.white.opacity(0.4))
        .font(.system(size: 14))
    }

    private var lyricsEmptyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            if activeSong?.chordChart == nil {
                Text("No chord chart / lyrics in Planning Center.")
                    .italic()
            } else {
                let keys = activeSong?.lyricsbySection.keys.sorted().joined(separator: ", ") ?? ""
                Text("No lyrics for this section in Planning Center.")
                    .italic()
                if !keys.isEmpty {
                    Text("Sections found: \(keys)")
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .foregroundStyle(.white.opacity(0.4))
        .font(.system(size: 14))
    }

    private var nashvilleChords: String {
        guard let song = activeSong, let section = activeSection else { return "" }
        return sectionValue(section, in: song.nashvilleBySection)
    }

    private var rawChords: String {
        guard let song = activeSong, let section = activeSection else { return "" }
        return sectionValue(section, in: song.rawChordsBySection)
    }

    private var lyrics: String {
        guard let song = activeSong, let section = activeSection else { return "" }
        return sectionValue(section, in: song.lyricsbySection)
    }

    private var activeChordDisplay: String { showNashville ? nashvilleChords : rawChords }

    // Tries multiple key forms to match chart-parsed section headers
    // e.g. PCSection(label="Verse", number=1) tries: "verse", "verse 1", prefix "verse*"
    private func sectionValue(_ section: PCSection, in dict: [String: String]) -> String {
        let label = section.label.lowercased()
        if let v = dict[section.displayName.lowercased()], !v.isEmpty { return v }
        if let v = dict["\(label) \(section.number)"], !v.isEmpty { return v }
        return dict.first(where: { $0.key.hasPrefix(label) })?.value ?? ""
    }

    private var isArrangementMode: Bool { pc.appMode == .arrangementSheet }

    var body: some View {
        VStack(spacing: 0) {
            chordsPanel
            sectionDivider
            lyricsPanel
            if isArrangementMode { advanceControls }
        }
        .background(Color(white: 0.05))
    }

    // MARK: - Chords

    private var chordsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .bold))
                Text(showNashville ? "NASHVILLE NUMBERS" : "CHORDS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                if let song = activeSong {
                    Text("KEY: \(song.key.isEmpty ? "—" : song.key)  \(song.bpm > 0 ? "\(Int(song.bpm)) BPM" : "")  \(song.meter)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .foregroundStyle(.white.opacity(0.5))

            if activeChordDisplay.isEmpty {
                chordsEmptyHint
            } else {
                Text(activeChordDisplay)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineSpacing(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Section divider

    private var sectionDivider: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(style.color)
                .frame(width: 4, height: 22)

            Text(activeSection?.displayName.uppercased() ?? "—")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(style.color)

            Spacer()

            if let next = nextSection {
                HStack(spacing: 6) {
                    Text("NEXT:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(next.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            if let song = activeSong { sectionDots(song: song) }

            modeToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(style.color.opacity(0.15))
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleTab(label: "123", active: showNashville)
                .onTapGesture { showNashville = true }
            toggleTab(label: "ABC", active: !showNashville)
                .onTapGesture { showNashville = false }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.15), lineWidth: 1))
    }

    private func toggleTab(label: String, active: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(active ? .black : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(active ? Color.white.opacity(0.85) : Color.clear)
    }

    private func sectionDots(song: PCSong) -> some View {
        let currentIdx: Int = {
            guard let s = activeSection else { return -1 }
            return song.sections.firstIndex(where: { $0.id == s.id }) ?? -1
        }()
        return HStack(spacing: 4) {
            ForEach(Array(song.sections.prefix(16).enumerated()), id: \.offset) { idx, _ in
                Circle()
                    .fill(idx == currentIdx ? style.color : .white.opacity(0.2))
                    .frame(width: idx == currentIdx ? 8 : 5, height: idx == currentIdx ? 8 : 5)
            }
            if song.sections.count > 16 {
                Text("…").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Lyrics

    private var lyricsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 11, weight: .bold))
                    Text("LYRICS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))

                if lyrics.isEmpty {
                    lyricsEmptyHint
                } else {
                    Text(lyrics)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Arrangement mode controls

    private var advanceControls: some View {
        HStack(spacing: 0) {
            Button(action: { pc.retreatDemoSection() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("PREV")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(pc.demoSectionIndex > 0 ? .white.opacity(0.8) : .white.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .disabled(pc.demoSectionIndex <= 0)

            Divider().frame(height: 22).background(.white.opacity(0.15))

            Button(action: { pc.advanceDemoSection() }) {
                HStack(spacing: 8) {
                    Text("NEXT")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(pc.demoNextSection != nil ? .white.opacity(0.8) : .white.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .disabled(pc.demoNextSection == nil)
        }
        .background(Color.white.opacity(0.05))
    }
}
