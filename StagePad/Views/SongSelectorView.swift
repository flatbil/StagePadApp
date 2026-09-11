import SwiftUI

// Reordering is a real hazard, not just a nice-to-have gate: a live set with
// nine songs named "Song 1"..."Song 9" got silently shuffled by an accidental
// touch, auto-advanced into the wrong one, and nobody noticed until it had
// already happened — no unmistakable feedback at the moment it engaged, and
// the 400ms hold that gated it wasn't enough friction on its own.
//
// Two layers now, deliberately redundant:
//   1. Dragging is only POSSIBLE at all in Edit Order mode, entered/exited
//      explicitly via the button below the pills. Outside that mode, a touch
//      can only ever be a tap-to-select — there is no gesture code path that
//      can start a reorder, not "a slow one," so a live-show touch literally
//      cannot shuffle anything no matter how it's held.
//   2. Inside Edit Order mode, a hold-then-drag gate still exists (now 700ms,
//      up from 400ms) as a second speed bump against grazing a pill while
//      just looking at the list — and the moment it actually engages gets an
//      unmissable visual pop, deliberately WITHOUT haptics (asked for none).

struct SongSelectorView: View {
    let songs: [Song]
    @Binding var setlistOrder: [Int]
    let selectedSongIndex: Int
    let currentSongIndex: Int
    let onSelect: (Int) -> Void

    @State private var isEditingOrder: Bool = false
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
                                    // Outside Edit Order mode this gesture does
                                    // nothing at all — not "waits for a longer
                                    // hold," genuinely nothing — so no touch,
                                    // however it's held, can start a reorder.
                                    guard isEditingOrder else { return }

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
                                    guard isEditingOrder else {
                                        // Any release outside Edit Order mode is
                                        // just a tap — there's no other gesture
                                        // this could have been.
                                        onSelect(songIdx)
                                        return
                                    }
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
                                    }
                                    // Quick release before the hold fired: deliberately
                                    // a no-op, not a tap-to-select — Edit Order mode
                                    // stays single-purpose so it can't also jump songs.
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
        // Whole-row tint is the "you are in a different mode right now" cue —
        // meant to be obvious even at a glance from a few feet away, not just
        // noticeable up close on the small edit button itself.
        .background(isEditingOrder ? Color.orange.opacity(0.14) : Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) { editOrderButton }
        .animation(.easeInOut(duration: 0.2), value: isEditingOrder)
    }

    // Reordering is only ever reachable through here — there is no gesture
    // path anywhere above that can start one without this being active first.
    private var editOrderButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingOrder.toggle()
            }
            if !isEditingOrder {
                // Leaving mid-drag (e.g. tapping Done with a finger still
                // down elsewhere) should abandon it, not commit a half-drag.
                pressTask?.cancel()
                pressTask = nil
                activePill = nil
                draggingPos = nil
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isEditingOrder ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                Text(isEditingOrder ? "Done" : "Reorder")
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(isEditingOrder ? .black : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(isEditingOrder ? Color.orange : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .padding(6)
    }
}

private struct SongPillButton: View {
    let song:       Song
    let index:      Int
    let isSelected: Bool
    let isActive:   Bool
    var isDragging: Bool = false

    private var color: Color { Song.songColor(for: index) }

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
