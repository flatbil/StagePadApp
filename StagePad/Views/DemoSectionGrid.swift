import SwiftUI

struct DemoSectionGrid: View {
    @EnvironmentObject var pc: PlanningCenterService
    let song: PCSong

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(song.sections.enumerated()), id: \.offset) { idx, section in
                    DemoSectionButton(
                        section: section,
                        index: idx,
                        isActive: idx == pc.demoSectionIndex,
                        song: song
                    )
                    .onTapGesture { pc.setDemoSection(index: idx) }
                }
            }
            .padding(10)
        }
    }
}

struct DemoSectionButton: View {
    @EnvironmentObject var pc: PlanningCenterService
    let section: PCSection
    let index: Int
    let isActive: Bool
    let song: PCSong

    private var style: SectionStyle { SectionStyle.style(for: section.label) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { ctx in
            let progress = isActive ? pc.demoSectionProgress(at: ctx.date) : 0.0
            buttonContent(progress: progress)
        }
    }

    private func buttonContent(progress: Double) -> some View {
        ZStack(alignment: .leading) {
            // Base fill
            RoundedRectangle(cornerRadius: 10)
                .fill(style.color.opacity(isActive ? 1.0 : 0.45))

            // Progress bar
            if isActive && progress > 0 {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: geo.size.width * progress)
                }
            }

            // Watermark icon
            Image(systemName: style.icon)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(isActive ? 0.14 : 0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Active border
            if isActive {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
            }

            // Label
            Text(section.displayName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
