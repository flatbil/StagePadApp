import SwiftUI

struct SongChartView: View {
    let song: PCSong
    let currentSectionLabel: String  // from Ableton (may be empty)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(.white.opacity(0.1))
                sectionList
            }
        }
        .background(Color.black)
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 24) {
            chip(label: "KEY", value: song.key.isEmpty ? "—" : song.key)
            chip(label: "BPM", value: song.bpm > 0 ? String(format: "%.0f", song.bpm) : "—")
            chip(label: "TIME", value: song.meter)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func chip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var sectionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(song.sections.enumerated()), id: \.offset) { idx, section in
                sectionRow(section: section, index: idx)
                Divider().background(.white.opacity(0.07)).padding(.leading, 20)
            }
        }
        .padding(.bottom, 20)
    }

    private func sectionRow(section: PCSection, index: Int) -> some View {
        let isCurrent = section.label.lowercased() == currentSectionLabel.lowercased()
        let style = SectionStyle.style(for: section.label)
        let nashvilleKey = section.label.lowercased()
        let nashvilleChords = song.nashvilleBySection[nashvilleKey] ?? ""
        let isNext = nextIndex == index

        return HStack(spacing: 14) {
            // Position dot
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 24, alignment: .trailing)

            // Color stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(style.color)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(section.displayName)
                        .font(.system(size: 15, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.75))

                    if isNext {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if !nashvilleChords.isEmpty {
                    Text(nashvilleChords)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(style.color)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isCurrent ? style.color.opacity(0.12) : Color.clear)
    }

    // Index of the section that comes after the current one
    private var nextIndex: Int? {
        guard !currentSectionLabel.isEmpty else { return nil }
        let lower = currentSectionLabel.lowercased()
        guard let idx = song.sections.firstIndex(where: { $0.label.lowercased() == lower }) else { return nil }
        let next = idx + 1
        return next < song.sections.count ? next : nil
    }
}
