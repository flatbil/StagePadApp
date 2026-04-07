# Developer Notes — StagePad

## Architecture overview

```
BridgeService (ObservableObject, @MainActor)
  ├── WebSocket connection management (URLSessionWebSocketTask)
  ├── Bonjour discovery (BridgeDiscovery / NetServiceBrowser)
  ├── JSON message parsing → published state
  └── Optimistic UI state updates

Views (SwiftUI)
  ├── ContentView          — root layout, wires bridge → views
  ├── InfoBarView          — song name, section, tempo, measure, connection dot
  ├── SongSelectorView     — horizontal pill list of all songs
  ├── SectionGridView      — 3-column grid of section buttons for selected song
  ├── SectionButtonWrapper — active section gets TimelineView for 30fps progress
  ├── SectionButton        — renders progress fill, glow border, dancing icon
  ├── TransportBarView     — PLAY / STOP
  └── SettingsView         — manual IP entry
```

## BridgeService state machine

### Optimistic UI

The app applies UI changes **before** waiting for server confirmation, then lets server corrections arrive naturally. This makes the interface feel instantaneous:

| Action | Optimistic change | Server corrects if wrong |
|--------|-------------------|--------------------------|
| Tap section button | `currentSong/SectionIndex` update + progress resets to 0 | Next `position` message |
| Tap PLAY | `isPlaying = true`, `sectionAnchorDate = now` | Next `is_playing` message |
| Tap STOP | `isPlaying = false`, progress freezes | Next `is_playing` message |
| Section end reached | Auto-advances to next section | Next `position` message |

### Jump suppression (`pendingJumpPosition`)

When the user taps a section, Ableton holds the new position until the next launch quantization boundary (up to 1 bar). During this hold the server keeps sending the old position. Without suppression, the progress bar would snap back.

`pendingJumpPosition` is set to the target beat on tap and cleared once the server reports a position within 1 beat of the target. While pending:
- Server position/section updates are discarded
- Progress bar is frozen at 0% (doesn't advance)

### Progress bar timing (`sectionAnchorBeat` / `sectionAnchorDate`)

Progress is computed at 30fps by `TimelineView` in `SectionButtonWrapper` using wall-clock math:

```
elapsed = now - sectionAnchorDate
currentBeat = sectionAnchorBeat + elapsed * tempo / 60
progress = (currentBeat - sectionStartBeat) / (sectionEndBeat - sectionStartBeat)
```

`sectionAnchorDate` and `sectionAnchorBeat` are updated on every server position update, keeping the interpolation anchored to real data. The `TimelineView` approach avoids `@Published` churn — progress changes at display sync rate without triggering SwiftUI diffing on every frame.

Progress advancement is gated by two flags:
- `isPlaying` — false → freeze (show current position, don't advance)
- `isJumpPending` — true → freeze (wait for Ableton to confirm launch)

### Auto-advance (`autoAdvanceTask`)

When a section becomes active, `scheduleAutoAdvance()` fires a `Task` that sleeps for exactly `(sectionEndBeat - sectionAnchorBeat) * 60 / tempo` seconds, then calls `autoAdvanceSection`. This means section transitions happen on time without waiting for the server's next beat update (which can be up to 1 second late).

`autoAdvanceSection` is a no-op if `currentSong/SectionIndex` have already been updated by the server — the guard prevents double-advancing. `activateSection` called on the new section schedules the next auto-advance, so the chain continues through the whole set automatically.

The task is cancelled on `stop()`, `disconnect()`, and whenever `activateSection` reschedules it (manual jump or server-driven section change).

### Reconnection

On any WebSocket failure, `scheduleReconnect()` retries after 3 seconds. Bonjour discovery is re-run on each `connect()` call with a 3-second timeout before falling back to the manual IP.

## Key design decisions

### No `@Published` on progress

Progress (0.0–1.0) is computed in `computedProgress(at:)` inside a `TimelineView` closure. It is never stored. This is intentional — storing it as `@Published` would trigger a SwiftUI view tree diff on every frame (30fps × N section buttons). `TimelineView` bypasses this by driving only the leaf view that actually renders the fill.

### Section colour/icon by name

`SectionStyle.style(for:)` maps section names to colours and SF Symbols using pattern matching on the lowercase name. This means musicians don't need to configure anything — "Verse 1", "verse", "VERSE" all get the same style.

### Bonjour over USB

iOS routes `.local` mDNS traffic over USB when an iPad is plugged in. The bridge registers `_stagepad._tcp.` via Zeroconf on the Mac side; `NetServiceBrowser` on the iPad side resolves it. USB gives ~1ms latency vs. ~5–20ms over WiFi.

## File map

| File | Role |
|------|------|
| `Services/BridgeService.swift` | All WebSocket, Bonjour, state, and command logic |
| `Models/Song.swift` | `Song`, `Section`, `SectionStyle` value types + palette |
| `Views/ContentView.swift` | Root view, bridge → view wiring |
| `Views/SectionButtonWrapper.swift` | TimelineView wrapper, `computedProgress` |
| `Views/SectionButton.swift` | Rendered button with progress fill and dancing icon |
| `Views/TransportBarView.swift` | PLAY / STOP bar |
| `Views/SongSelectorView.swift` | Horizontal song pill selector |
| `Views/SectionGridView.swift` | 3-column section grid |
| `Views/InfoBarView.swift` | Top info bar (song, section, tempo, measure) |
| `Views/SettingsView.swift` | Manual IP configuration |
| `Views/LaunchScreenView.swift` | Launch / connecting screen |
| `project.yml` | XcodeGen project spec (iOS 17, Swift 5.9) |
