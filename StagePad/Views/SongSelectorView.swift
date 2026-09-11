import SwiftUI

// Single DragGesture(minimumDistance: 0) handles both tap and long-press+drag.
// Quick release = tap (onSelect). Hold 0.4 s then move = reorder drag.
// No LongPressGesture/TapGesture conflicts possible.

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
                                            try? await Task.sleep(nanoseconds: 400_000_000)
                                            guard !Task.isCancelled else { return }
                                            await MainActor.run {
                                                let pos = setlistOrder.firstIndex(of: capturedIdx) ?? 0
                                                withAnimation(.spring(response: 0.2)) {
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
                                        // ── Quick release — treat as tap ──
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
                }
            }
            .coordinateSpace(name: "pillRow")
        }
        .frame(height: 72)
        .background(Color.white.opacity(0.03))
        .contentShape(Rectangle())
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
