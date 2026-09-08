import SwiftUI

/// A visual metronome — flashes on the beat, predicted locally rather than
/// reacting to each incoming beat message directly.
///
/// Flashing reactively (on the instant a beat message arrives) would bake in
/// the WebSocket round-trip's jitter every single time — not a fixed offset
/// the eye adjusts to, but an inconsistent one that reads as "wrong" on
/// stage. Instead this predicts the current beat position by dead-reckoning
/// from the same measured-tempo anchor everything else in this app already
/// uses (BridgeService.sectionAnchorBeat/sectionAnchorDate, resynced fresh on
/// every real beat arrival) and flashes whenever that estimate crosses an
/// integer beat — smoothing out network jitter instead of being at its mercy.
struct TempoLightView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let lit = isOnBeat(at: tl.date)
            Circle()
                .fill(Color.orange)
                .frame(width: 12, height: 12)
                .opacity(lit ? 1.0 : 0.22)
                .scaleEffect(lit ? 1.0 : 0.82)
                .shadow(color: lit ? .orange.opacity(0.8) : .clear, radius: 5)
        }
    }

    /// A short flash right after crossing each integer beat. The flash
    /// window is a *fraction* of a beat (not a fixed millisecond count) so it
    /// scales with tempo automatically — snappy at a fast tempo, still
    /// clearly visible at a slow one, without needing to know BPM up front.
    private func isOnBeat(at now: Date) -> Bool {
        guard bridge.isPlaying else { return false }
        let bpm = bridge.interpolationTempo > 0 ? bridge.interpolationTempo : bridge.tempo
        guard bpm > 0 else { return false }
        let elapsed = max(0, now.timeIntervalSince(bridge.sectionAnchorDate))
        let beat = bridge.sectionAnchorBeat + elapsed * bpm / 60.0
        let fractional = beat - beat.rounded(.down)
        return fractional < 0.15
    }
}
