import SwiftUI

// Reordering: hold a pill to pick it up and drag, tap to select — no
// separate "Edit Order" mode button.
//
// NOTE — this reverts part of a deliberate safety fix (2026-09-11, see
// PROJECT git history "Require explicit Edit Order mode before setlist
// reordering is possible"): a live 9-song set got silently reordered by an
// accidental touch mid-service, auto-advanced into the wrong song, and
// nobody noticed until after. The Edit Order mode gate made reordering
// physically unreachable outside an explicit toggle, which fully closed
// that hole. Removed 2026-09-12 at the user's request (the button's
// placement was also overlapping the last pill — see git history) in favor
// of the simpler, pre-incident long-press-to-drag gesture. The 700ms hold
// (up from the original 400ms) is kept as the only remaining friction
// against an accidental touch — this is real risk reintroduced, not a
// wash: worth confirming this tradeoff is intentional before a live show.
struct SongSelectorView: View {
    let songs: [Song]
    @Binding var setlistOrder: [Int]
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let onSelect: (Int) -> Void

    @State private var draggingPos: Int? = nil      // index in setlistOrder being dragged
    @State private var fingerX:     CGFloat = 0     // finger X in "pillRow" coord space
    @State private var pillWidth:   CGFloat = 100   // captured at drag start
    @State private var activePill:  Int?    = nil   // songIdx currently touched
    @State private var pressTask:   Task<Void, Never>? = nil  // long-press timer

    private let spacing: CGFloat = 8
    private let hPad:    CGFloat = 14
    private let holdDuration: UInt64 = 700_000_000  // ns — see header note

    private func targetPos() -> Int {
        let unit = pillWidth + spacing
        let raw  = Int(((fingerX - hPad) / unit).rounded())
        return max(0, min(setlistOrder.count - 1, raw))
    }

    // Visual order while dragging (other pills slide to make room)
    private func displayOrder() -> [Int] {
        guard let from = draggingPos else { return setlistOrder }
        let to = targetPos()
        guard from != to else { return setlistOrder }
        var order = setlistOrder
        let item  = order.remove(at: from)
        order.insert(item, at: to)
        return order
    }

    var body: some View {
        GeometryReader { geo in
            let n = max(1, setlistOrder.count)
            let w = (geo.size.width - hPad * 2 - spacing * CGFloat(n - 1)) / CGFloat(n)

            ZStack(alignment: .topLeading) {

                // ── Pill row ──────────────────────────────────────────────
                HStack(spacing: spacing) {
                    ForEach(displayOrder(), id: \.self) { songIdx in
                        let originalPos = setlistOrder.firstIndex(of: songIdx) ?? 0
                        let isGhost     = draggingPos == originalPos

                        SongPillButton(
                            song:      songs[songIdx],
                            index:     songIdx,
                            isSelected: songIdx == selectedSongIndex,
                            isActive:  songIdx == currentSongIndex,
                            isDragging: false
                        )
                        .opacity(isGhost ? 0.2 : 1.0)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0,
                                        coordinateSpace: .named("pillRow"))
                                .onChanged { value in
                                    // ── Touch-down (first event) ──────────
                                    if activePill == nil {
                                        activePill = songIdx
                                        pillWidth  = w
                                        fingerX    = value.location.x

                                        // Start long-press countdown
                                        pressTask?.cancel()
                                        let capturedIdx = songIdx
                                        pressTask = Task {
                                            try? await Task.sleep(nanoseconds: holdDuration)
                                            guard !Task.isCancelled else { return }
                                            await MainActor.run {
                                                let pos = setlistOrder.firstIndex(of: capturedIdx) ?? 0
                                                // Bouncier than a settle-in spring on purpose —
                                                // this IS the "you just picked one up" feedback,
                                                // standing in for the haptic we deliberately don't fire.
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                                    draggingPos = pos
                                                }
                                            }
                                        }
                                    }

                                    // ── Finger moving ─────────────────────
                                    guard activePill == songIdx else { return }
                                    let lo = hPad + pillWidth / 2
                                    let hi = geo.size.width - hPad - pillWidth / 2
                                    fingerX = min(max(value.location.x, lo), hi)
                                }
                                .onEnded { _ in
                                    guard activePill == songIdx else { return }
                                    pressTask?.cancel()
                                    pressTask = nil

                                    if let pos = draggingPos {
                                        // ── Drag ended — commit reorder ───
                                        let to = targetPos()
                                        withAnimation(.spring(response: 0.25)) {
                                            draggingPos = nil
                                        }
                                        if pos != to {
                                            var order = setlistOrder
                                            let item  = order.remove(at: pos)
                                            order.insert(item, at: to)
                                            setlistOrder = order
                                            UserDefaults.standard.set(
                                                order,
                                                forKey: "setlistOrder_\(order.count)")
                                        }
                                    } else {
                                        // Released before the hold fired — a tap, not a drag.
                                        onSelect(songIdx)
                                    }
                                    activePill = nil
                                }
                        )
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, 10)
                .animation(.spring(response: 0.25, dampingFraction: 0.8),
                           value: displayOrder())

                // ── Floating pill (follows finger during drag) ────────────
                if let fromPos = draggingPos, setlistOrder.indices.contains(fromPos) {
                    let songIdx   = setlistOrder[fromPos]
                    let leftEdge  = min(max(fingerX - pillWidth / 2, hPad),
                                        geo.size.width - hPad - pillWidth)

                    SongPillButton(
                        song:      songs[songIdx],
                        index:     songIdx,
                        isSelected: songIdx == selectedSongIndex,
                        isActive:  songIdx == currentSongIndex,
                        isDragging: true
                    )
                    .frame(width: pillWidth, height: 52)
                    .offset(x: leftEdge, y: 10)
                    .scaleEffect(1.06)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                    .allowsHitTesting(false)
                    // Pops in from oversized rather than fading in at final
                    // size — this transition IS the "you just picked one up"
                    // moment; see the bouncy spring where draggingPos gets set.
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "pillRow")
        }
        .frame(height: 72)
        .background(Color.white.opacity(0.03))
    }
}

private struct SongPillButton: View {
    @EnvironmentObject var bridge: BridgeService

    let song:       Song
    let index:      Int
    let isSelected: Bool
    let isActive:   Bool
    var isDragging: Bool = false

    private var color: Color { bridge.resolvedColor(for: song, index: index) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: Song.songIcon(for: index))
                .font(.system(size: 14))
            Text(song.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? color : color.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isActive   ? Color.white.opacity(0.7) : .clear, lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isDragging ? Color.white.opacity(0.5) : .clear, lineWidth: 1.5))
        .shadow(color: isDragging ? .black.opacity(0.4) : .clear, radius: 8, y: 4)
        .contentShape(Rectangle())
    }
}
