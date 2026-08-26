import SwiftUI

struct InfoBarView: View {
    let isPlaying: Bool
    let currentSongName: String
    let currentSectionName: String
    let tempo: Double
    let measure: Int
    let statusColor: Color
    var isDemo: Bool = false
    var isObserver: Bool = false
    let onSettingsTap: () -> Void
    let onTracksTap: () -> Void
    var onDemoTap: (() -> Void)? = nil

    @State private var pingingPlaying = false
    @State private var songScale: CGFloat = 1.0
    @State private var songOffset: CGFloat = 0.0
    @State private var sectionScale: CGFloat = 1.0
    @State private var sectionOffset: CGFloat = 0.0

    // iPhone-width layout: the iPad-tuned fixed-width cells (indicator, tracks
    // label, BPM, BAR) left zero room for SONG/SECTION on a ~440pt-wide iPhone
    // — they rendered completely blank. Compact width drops BAR, shrinks the
    // rest, and goes icon-only on TRACKS to give SONG/SECTION real estate back.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        HStack(spacing: 0) {
            playingIndicator
            if isDemo {
                demoBadge
            }
            if isObserver {
                observerBadge
            }
            tracksButton
            divider
            bouncingCell(label: "SONG", value: currentSongName, scale: songScale, offset: songOffset)
            divider
            bouncingCell(label: "SECTION", value: currentSectionName, scale: sectionScale, offset: sectionOffset)
            divider
            infoCell(label: "BPM", value: tempo > 0 ? String(format: "%.1f", tempo) : "—")
                .frame(width: isCompact ? 60 : 90)
            if !isCompact {
                divider
                infoCell(label: "BAR", value: "\(measure)")
                    .frame(width: 90)
            }
            divider
            controls
        }
        .padding(.horizontal, isCompact ? 10 : 16)
        .frame(height: 70)
        .background(Color.white.opacity(0.05))
        .onChange(of: currentSongName) { _, _ in bounce(scale: $songScale, offset: $songOffset) }
        .onChange(of: currentSectionName) { _, _ in bounce(scale: $sectionScale, offset: $sectionOffset) }
    }

    // Demo-mode indicator. Tapping it leaves demo mode and returns to the
    // launch menu, where the user can choose to search for the bridge again.
    private var demoBadge: some View {
        Button { onDemoTap?() } label: {
            VStack(spacing: 1) {
                Text("DEMO")
                    .font(.system(size: isCompact ? 10 : 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, isCompact ? 6 : 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.orange))
                if !isCompact {
                    Text("tap to exit")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, isCompact ? 6 : 10)
    }

    // Read-only indicator — another device holds primary control. Not tappable;
    // there's no "take control" action, matching the "first to connect is
    // primary" model documented in the wiki.
    private var observerBadge: some View {
        VStack(spacing: 1) {
            Text("OBSERVER")
                .font(.system(size: isCompact ? 10 : 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, isCompact ? 6 : 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.cyan))
            if !isCompact {
                Text("view only")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.85))
            }
        }
        .padding(.leading, isCompact ? 6 : 10)
    }

    private func bounce(scale: Binding<CGFloat>, offset: Binding<CGFloat>) {
        // Pop up, overshoot, settle
        withAnimation(.easeOut(duration: 0.1)) {
            offset.wrappedValue = -10
            scale.wrappedValue = 1.25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                offset.wrappedValue = 0
                scale.wrappedValue = 1.0
            }
        }
    }

    private var playingIndicator: some View {
        HStack(spacing: 8) {
            ZStack {
                if isPlaying {
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 22, height: 22)
                        .scaleEffect(pingingPlaying ? 1.8 : 1.0)
                        .opacity(pingingPlaying ? 0 : 0.6)
                        .animation(.easeOut(duration: 0.9).repeatForever(autoreverses: false), value: pingingPlaying)
                }
                Circle()
                    .fill(isPlaying ? Color.green : Color.red.opacity(0.7))
                    .frame(width: 12, height: 12)
                    .shadow(color: isPlaying ? .green : .clear, radius: 6)
            }
            .frame(width: 22)

            Text(isPlaying ? "PLAYING" : "STOPPED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isPlaying ? .green : .white.opacity(0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: isCompact ? 66 : 90, alignment: .leading)
        .onChange(of: isPlaying) { _, playing in pingingPlaying = playing }
        .onAppear { pingingPlaying = isPlaying }
    }

    private var divider: some View {
        Divider().frame(height: 30).background(.white.opacity(0.15))
    }

    private var tracksButton: some View {
        Button(action: onTracksTap) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                // Label dropped on compact width — icon alone stays
                // recognizable and the label was the biggest single space cost
                // on iPhone, where it was crowding SONG/SECTION out entirely.
                if !isCompact {
                    Text("TRACKS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
            .foregroundStyle(.white.opacity(0.6))
            // Wider on iPad so the label reads clearly at a glance, not cramped
            // under a small icon. Height keeps Apple's 44pt tap-target minimum.
            .frame(width: isCompact ? 44 : 88, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Button(action: onSettingsTap) {
                Image(systemName: "gear")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                    // Apple's 44pt minimum tap target — the icon glyph alone was ~18pt.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .frame(width: 70, alignment: .trailing)
    }

    private func bouncingCell(label: String, value: String, scale: CGFloat, offset: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .scaleEffect(scale)
                .offset(y: offset)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoCell(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}
