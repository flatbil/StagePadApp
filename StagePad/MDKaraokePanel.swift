import SwiftUI

struct MDKaraokePanel: View {
    @EnvironmentObject var pc: PlanningCenterService
    let isExpanded: Bool

    private var song: PCSong? { pc.demoSong }
    private var section: PCSection? { pc.demoCurrentSection }
    private var nextSection: PCSection? { pc.demoNextSection }

    private var sectionStyle: SectionStyle {
        SectionStyle.style(for: section?.label ?? "")
    }

    private var nashvilleChords: String {
        guard let song, let section else { return "" }
        return song.nashvilleBySection[section.label.lowercased()] ?? ""
    }

    private var lyrics: String {
        guard let song, let section else { return "" }
        return song.lyricsbySection[section.label.lowercased()] ?? ""
    }

    var body: some View {
        if isExpanded, song != nil {
            VStack(spacing: 0) {
                chordsPanel
                sectionDivider
                lyricsPanel
                advanceControls
            }
            .background(Color.black)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Subviews

    private var chordsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("NASHVILLE", systemImage: "music.note")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))

            if nashvilleChords.isEmpty {
                Text("No chord data for this section")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .italic()
            } else {
                Text(nashvilleChords)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
            }

            if let song {
                HStack(spacing: 16) {
                    Text("KEY: \(song.key.isEmpty ? "—" : song.key)")
                    Text("BPM: \(song.bpm > 0 ? String(Int(song.bpm)) : "—")")
                    Text(song.meter)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
    }

    private var sectionDivider: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sectionStyle.color)
                .frame(width: 4, height: 20)

            Text(section?.displayName.uppercased() ?? "")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(sectionStyle.color)

            Spacer()

            if let next = nextSection {
                HStack(spacing: 6) {
                    Text("NEXT:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(next.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }

            // Section progress dots
            if let song {
                sectionDots(song: song)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(sectionStyle.color.opacity(0.12))
    }

    private func sectionDots(song: PCSong) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(song.sections.prefix(12).enumerated()), id: \.offset) { idx, _ in
                Circle()
                    .fill(idx == pc.demoSectionIndex ? sectionStyle.color : .white.opacity(0.2))
                    .frame(width: idx == pc.demoSectionIndex ? 8 : 5, height: idx == pc.demoSectionIndex ? 8 : 5)
            }
            if song.sections.count > 12 {
                Text("…")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var lyricsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Label("LYRICS", systemImage: "text.alignleft")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 4)

                if lyrics.isEmpty {
                    Text("No lyrics available for this section")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.2))
                        .italic()
                } else {
                    Text(lyrics)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxHeight: .infinity)
    }

    private var advanceControls: some View {
        HStack(spacing: 0) {
            Button(action: { pc.retreatDemoSection() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("PREV")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(pc.demoSectionIndex > 0 ? .white.opacity(0.7) : .white.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(pc.demoSectionIndex <= 0)

            Divider().frame(height: 24).background(.white.opacity(0.15))

            Button(action: { pc.advanceDemoSection() }) {
                HStack(spacing: 8) {
                    Text("NEXT")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(pc.demoNextSection != nil ? .white.opacity(0.7) : .white.opacity(0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(pc.demoNextSection == nil)
        }
        .background(Color.white.opacity(0.04))
    }
}
