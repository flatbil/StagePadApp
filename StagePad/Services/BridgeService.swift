import Foundation

enum ConnectionState: Equatable {
    case disconnected, connecting, connected, rejected
}

/// A named, saved bridge IP address — lets a user store known locations
/// (e.g. "Church Tracks Computer") instead of retyping an IP every time.
struct TrustedHost: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ipAddress: String

    init(id: UUID = UUID(), name: String, ipAddress: String) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
    }
}

// Bonjour discovery — finds the bridge on whatever interface is fastest
// (USB when plugged in, WiFi otherwise) without any manual IP entry.
@MainActor
private final class BridgeDiscovery: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    var onResolved: ((String, Int) -> Void)?

    private let browser = NetServiceBrowser()
    private var pending: NetService?

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        browser.searchForServices(ofType: "_stagepad._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        pending?.stop()
        pending = nil
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        pending = service
        service.delegate = self
        service.resolve(withTimeout: 3)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        // Prefer a raw IPv4 address from the resolved addresses — avoids mDNS
        // hostname formatting issues (trailing dots, special characters) that
        // break URL construction.
        if let addresses = sender.addresses {
            for data in addresses {
                var storage = sockaddr_storage()
                (data as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
                if storage.ss_family == AF_INET {
                    var addr = withUnsafePointer(to: &storage) {
                        $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    }
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                    let ip = String(cString: buf)
                    if !ip.isEmpty && ip != "0.0.0.0" {
                        onResolved?(ip, sender.port)
                        return
                    }
                }
            }
        }
        // Fallback to hostname if no IPv4 address found
        guard var host = sender.hostName else { return }
        if host.hasSuffix(".") { host = String(host.dropLast()) }
        onResolved?(host, sender.port)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // Resolution failed — BridgeService will time out and fall back to manual host
    }
}

@MainActor
final class BridgeService: ObservableObject {
    @Published var songs: [Song] = []
    /// Display order for the song selector. Values are indices into `songs[]`.
    /// Persisted locally so the setlist survives reconnects.
    /// Reset to default order whenever the number of songs changes.
    @Published var setlistOrder: [Int] = []
    @Published var currentSongIndex: Int = -1
    @Published var currentSectionIndex: Int = -1
    @Published var position: Double = 0          // beats from set start — server-side, for measure display
    @Published var isPlaying: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    /// Human-readable description of what the connection process is doing right
    /// now (e.g. "Searching via Bonjour…", "Trying saved IP 10.0.0.101…",
    /// "Connected to 10.0.0.101") — shown in Settings so the user isn't left
    /// guessing what the app is attempting.
    @Published var connectionDetail: String = ""
    @Published var trustedHosts: [TrustedHost] = [] {
        didSet { saveTrustedHosts() }
    }
    @Published var tempo: Double = 0
    @Published var timeSignatureNumerator: Int = 4
    /// Section queued to jump to (awaiting Ableton's beat-quantized confirmation).
    /// -1 means no jump pending.
    @Published var queuedSongIndex: Int = -1
    @Published var queuedSectionIndex: Int = -1
    @Published var isDemoMode: Bool = false
    @Published var tracks: [BridgeTrack] = []
    @Published var showCueWarning: Bool = false
    @Published var cueCount: Int = 0
    /// False when this device connected as a read-only observer (another
    /// device already holds primary/control). Set from the "role" field the
    /// bridge sends on connect; defaults true so demo mode and the moment
    /// before a role arrives are fully interactive.
    @Published var isPrimary: Bool = true
    private var lastNotifiedCueCount: Int = 0

    // Section timing — read by TimelineView in SectionButtonWrapper at render time.
    // Not @Published: changing these must not trigger re-renders; TimelineView polls them.
    var sectionStartBeat: Double = 0
    var sectionEndBeat: Double = 1
    var sectionAnchorBeat: Double = 0    // beat position confirmed at anchorDate
    var sectionAnchorDate: Date = Date()

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var jumpTimeoutTask: Task<Void, Never>?
    // Demo simulator ("fake bridge") state.
    private var demoTickerTask: Task<Void, Never>?
    private var demoPlayheadBeat: Double = 0
    private var demoJumpLaunchBeat: Double? = nil
    private var receiveGeneration = 0
    private let session = URLSession(configuration: .default)
    private let discovery = BridgeDiscovery()

    // Pending jump — only used in demo mode to gate the fake-bridge ticker.
    private var pendingJumpPosition: Double? = nil

    // Real-time BPM measured from consecutive beat-update timestamps.
    // More reliable than Ableton's reported tempo: auto-adapts to per-song BPM
    // changes in the arrangement without depending on AbletonOSC tempo messages.
    // Reset to 0 on song change or disconnect; falls back to reported tempo.
    var interpolationTempo: Double = 0
    private var prevAnchorPosition: Double = -1
    private var prevAnchorDate: Date = Date()

    // The host currently in use — set by Bonjour discovery or manual entry
    private var activeHost: String = ""

    var host: String {
        get { UserDefaults.standard.string(forKey: "bridge_host") ?? "192.168.4.29" }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_host") }
    }

    init() {
        loadTrustedHosts()
    }

    // MARK: - Trusted hosts (saved, named bridge IPs)

    private static let trustedHostsKey = "trustedHosts"

    private func loadTrustedHosts() {
        guard let data = UserDefaults.standard.data(forKey: Self.trustedHostsKey),
              let decoded = try? JSONDecoder().decode([TrustedHost].self, from: data) else { return }
        trustedHosts = decoded
    }

    private func saveTrustedHosts() {
        guard let data = try? JSONEncoder().encode(trustedHosts) else { return }
        UserDefaults.standard.set(data, forKey: Self.trustedHostsKey)
    }

    func addTrustedHost(name: String, ipAddress: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedIP = ipAddress.trimmingCharacters(in: .whitespaces)
        guard !trimmedIP.isEmpty else { return }
        trustedHosts.append(TrustedHost(name: trimmedName.isEmpty ? trimmedIP : trimmedName, ipAddress: trimmedIP))
    }

    func removeTrustedHost(at offsets: IndexSet) {
        trustedHosts.remove(atOffsets: offsets)
    }

    /// Make this the active connection target and reconnect to it immediately —
    /// the "obvious trusted connection" a user can tap instead of typing an IP.
    func selectTrustedHost(_ trusted: TrustedHost) {
        host = trusted.ipAddress
        connect()
    }

    private func url(for resolvedHost: String) -> URL? {
        // Strip trailing dot from mDNS hostnames (e.g. "host.local." → "host.local")
        let host = resolvedHost.hasSuffix(".") ? String(resolvedHost.dropLast()) : resolvedHost
        guard !host.isEmpty else { return nil }
        let encoded = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host
        return URL(string: "ws://\(encoded):8766/ws")
    }

    // MARK: - Connection

    func connect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel()   // no close frame — socket may already be dead
        webSocketTask = nil
        connectionState = .connecting
        connectionDetail = "Searching for bridge via Bonjour…"

        // Try Bonjour first — resolves to USB interface when iPad is plugged in,
        // WiFi otherwise. Falls back to manual host after 3 seconds.
        discovery.stop()
        discovery.onResolved = { [weak self] resolvedHost, _ in
            guard let self else { return }
            self.discovery.stop()
            self.connectionDetail = "Found via Bonjour — connecting to \(resolvedHost)…"
            self.openSocket(to: resolvedHost)
        }
        discovery.start()

        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            reconnectTask = nil
            // No Bonjour response yet — connect to manually configured host
            if connectionState == .connecting {
                discovery.stop()
                connectionDetail = "Bonjour timed out — trying saved IP \(host)…"
                openSocket(to: host)
            }
        }
    }

    private func openSocket(to resolvedHost: String) {
        // Cancel the fallback timer if Bonjour beat it
        reconnectTask?.cancel()
        reconnectTask = nil

        guard let socketURL = url(for: resolvedHost) else {
            connectionState = .disconnected
            connectionDetail = "\"\(resolvedHost)\" isn't a valid address"
            scheduleReconnect()
            return
        }

        activeHost = resolvedHost
        receiveGeneration += 1
        let generation = receiveGeneration

        let task = session.webSocketTask(with: socketURL)
        webSocketTask = task
        task.resume()

        task.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.receiveGeneration == generation else { return }
                if error == nil {
                    self.connectionState = .connected
                    self.connectionDetail = "Connected to \(resolvedHost)"
                } else {
                    self.connectionState = .disconnected
                    self.connectionDetail = "Could not reach \(resolvedHost)"
                    self.scheduleReconnect()
                }
            }
        }

        receive(generation: generation)
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        demoTickerTask?.cancel()
        demoTickerTask = nil
        discovery.stop()
        receiveGeneration += 1
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        connectionDetail = ""
        interpolationTempo = 0
        prevAnchorPosition = -1
    }

    /// Load preview data so the UI is explorable without a bridge connection.
    /// Does not interrupt the reconnect loop — the app will connect automatically
    /// when the bridge comes online and real data will replace demo data.
    func enterDemoMode() {
        isDemoMode = true
        isPrimary = true
        songs = Song.previewSongs
        tracks = BridgeTrack.previewTracks
        setlistOrder = Array(songs.indices)
        tempo = 120
        timeSignatureNumerator = 4
        isPlaying = false
        pendingJumpPosition = nil
        queuedSongIndex = -1
        queuedSectionIndex = -1
        demoPlayheadBeat = 0
        demoJumpLaunchBeat = nil
        // Seed the starting section through the shared transport path, then run
        // the fake bridge that streams position updates through the same path.
        let (si, sc) = demoIndices(at: demoPlayheadBeat)
        applyTransport(tempo: 120, timeSigNum: 4, position: 0, isPlaying: false, songIndex: si, sectionIndex: sc)
        startDemoTicker()
    }

    /// Leave demo mode and tear down its state so the launch menu can offer a
    /// fresh choice (search for the bridge, or re-enter demo).
    func exitDemoMode() {
        stopDemoTicker()
        isDemoMode = false
        disconnect()               // cancels tasks/socket, sets .disconnected
        isPlaying = false
        songs = []
        setlistOrder = []
        currentSongIndex = -1
        currentSectionIndex = -1
        queuedSongIndex = -1
        queuedSectionIndex = -1
        position = 0
        tempo = 0
    }

    // MARK: - Demo simulator (a fake bridge feeding applyTransport)

    private func startDemoTicker() {
        demoTickerTask?.cancel()
        demoTickerTask = Task { [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))   // ~30 Hz, like the bridge's position stream
                guard let self, self.isDemoMode else { return }
                let now = Date()
                let dt = now.timeIntervalSince(last)
                last = now
                self.demoTick(dt: dt)
            }
        }
    }

    private func stopDemoTicker() {
        demoTickerTask?.cancel()
        demoTickerTask = nil
    }

    /// One frame of the fake bridge: advance the playhead, apply a launch-quantized
    /// jump if one is due, then emit the transport snapshot a real "position"
    /// message would carry — so the UI runs identical code in demo and live modes.
    private func demoTick(dt: Double) {
        guard isPlaying, tempo > 0 else { return }
        demoPlayheadBeat += dt * tempo / 60.0

        // Launch quantization: while a jump is queued, hold (keep the current
        // section active, queued section pulsing) until the playhead reaches the
        // launch beat, then snap straight to the target — in ANY song, forward or
        // back — and emit immediately. We must return here so the setlist-order
        // boundary logic below doesn't run this tick; otherwise a forward
        // cross-song target (now past the old song's end) would be clobbered by
        // the boundary redirect, leaving the jump stuck.
        if let launch = demoJumpLaunchBeat {
            guard demoPlayheadBeat >= launch else { return }   // still counting in
            if songs.indices.contains(queuedSongIndex),
               songs[queuedSongIndex].sections.indices.contains(queuedSectionIndex) {
                demoPlayheadBeat = songs[queuedSongIndex].sections[queuedSectionIndex].position
            }
            demoJumpLaunchBeat = nil
            emitDemoTransport()
            return
        }

        // Natural advancement only: at a song boundary, continue in SETLIST order
        // (not arrangement order), matching the live path's autoAdvanceSection.
        if songs.indices.contains(currentSongIndex) {
            let songEnd = (currentSongIndex + 1 < songs.count)
                ? songs[currentSongIndex + 1].position
                : demoSetEndBeat()
            if demoPlayheadBeat >= songEnd {
                demoPlayheadBeat = songs[nextSetlistSong(after: currentSongIndex)].position
            }
        }

        emitDemoTransport()
    }

    private func emitDemoTransport() {
        let (si, sc) = demoIndices(at: demoPlayheadBeat)
        applyTransport(tempo: nil, timeSigNum: nil, position: demoPlayheadBeat,
                       isPlaying: true, songIndex: si, sectionIndex: sc)
    }

    /// The arrangement index of the song that follows `arrangementIndex` in the
    /// current setlist order, wrapping to the first setlist song at the end.
    private func nextSetlistSong(after arrangementIndex: Int) -> Int {
        guard !setlistOrder.isEmpty,
              let pos = setlistOrder.firstIndex(of: arrangementIndex) else { return 0 }
        let next = pos + 1 < setlistOrder.count ? setlistOrder[pos + 1] : setlistOrder[0]
        return songs.indices.contains(next) ? next : 0
    }

    /// Current (song, section) for an absolute beat — mirrors the bridge's
    /// parser.find_current_indices so demo advancement matches live behavior.
    private func demoIndices(at beat: Double) -> (Int, Int) {
        var songIdx = -1
        var sectionIdx = -1
        for (si, song) in songs.enumerated() where beat >= song.position {
            songIdx = si
            sectionIdx = -1
            for (sci, section) in song.sections.enumerated() {
                if beat >= section.position { sectionIdx = sci } else { break }
            }
        }
        return (songIdx, sectionIdx)
    }

    private func demoSetEndBeat() -> Double {
        guard let lastSong = songs.last, let lastSection = lastSong.sections.last else { return 0 }
        return lastSection.position + Double(timeSignatureNumerator) * 4   // + 4 bars of tail
    }

    private func receive(generation: Int) {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.receiveGeneration == generation else { return }
                switch result {
                case .success(let message):
                    self.connectionState = .connected
                    if case .string(let text) = message { self.handle(text) }
                    self.receive(generation: generation)
                case .failure:
                    self.connectionState = .disconnected
                    self.connectionDetail = "Connection lost — reconnecting…"
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleJumpTimeout() {
        jumpTimeoutTask?.cancel()
        jumpTimeoutTask = Task {
            // 6 seconds covers 2 bars even at 40 BPM — if Ableton hasn't moved to
            // the queued section by then, clear the queued state and let the UI rest.
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            pendingJumpPosition = nil
            queuedSongIndex = -1
            queuedSectionIndex = -1
        }
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil, connectionState != .rejected else { return }
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            reconnectTask = nil
            connect()
        }
    }

    // MARK: - Section timing

    /// Updates the section timing metadata used by TimelineView for smooth progress rendering.
    /// fromBeat is the current beat position at the moment this section becomes active.
    private func activateSection(songIndex: Int, sectionIndex: Int, fromBeat: Double) {
        guard songs.indices.contains(songIndex),
              songs[songIndex].sections.indices.contains(sectionIndex) else { return }

        let sections = songs[songIndex].sections
        sectionStartBeat = sections[sectionIndex].position

        if sections.indices.contains(sectionIndex + 1) {
            sectionEndBeat = sections[sectionIndex + 1].position
        } else if songs.indices.contains(songIndex + 1) {
            sectionEndBeat = songs[songIndex + 1].position
        } else {
            // Last section of last song — assume 4 bars
            sectionEndBeat = sectionStartBeat + Double(timeSignatureNumerator) * 4
        }

        sectionAnchorBeat = max(sectionStartBeat, min(fromBeat, sectionEndBeat))
        sectionAnchorDate = Date()

        scheduleAutoAdvance()
    }

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        // In demo mode the fake-bridge ticker drives section changes directly, so
        // the client-side prediction is unnecessary and would double-advance.
        guard !isDemoMode, isPlaying, tempo > 0 else { return }

        // Use measured tempo when available — it's derived from actual beat timing
        // and adapts to per-song BPM changes faster than the reported value.
        let effectiveTempo = interpolationTempo > 0 ? interpolationTempo : tempo

        let elapsed = Date().timeIntervalSince(sectionAnchorDate)
        let estimatedBeat = sectionAnchorBeat + elapsed * effectiveTempo / 60.0
        guard sectionEndBeat > estimatedBeat else { return }

        let secondsRemaining = (sectionEndBeat - estimatedBeat) * 60.0 / effectiveTempo
        let fromSong    = currentSongIndex
        let fromSection = currentSectionIndex
        autoAdvanceTask = Task {
            try? await Task.sleep(for: .seconds(secondsRemaining))
            guard !Task.isCancelled else { return }
            self.autoAdvanceSection(fromSong: fromSong, fromSection: fromSection)
        }
    }

    private func autoAdvanceSection(fromSong: Int, fromSection: Int) {
        // No-op if server already moved us on (guard against double-advance)
        guard currentSongIndex == fromSong, currentSectionIndex == fromSection else { return }

        if songs.indices.contains(fromSong),
           songs[fromSong].sections.indices.contains(fromSection + 1) {
            // ── Next section within the same song ─────────────────────────
            // Ableton plays through naturally; just advance the UI.
            let nextSection = fromSection + 1
            currentSongIndex = fromSong
            currentSectionIndex = nextSection
            activateSection(songIndex: fromSong, sectionIndex: nextSection, fromBeat: sectionEndBeat)

        } else {
            // ── End of song — find the next song via setlist order ────────
            guard let posInSetlist = setlistOrder.firstIndex(of: fromSong),
                  posInSetlist + 1 < setlistOrder.count else { return }
            let nextSongIdx = setlistOrder[posInSetlist + 1]

            if nextSongIdx == fromSong + 1 {
                // Next setlist song is also the next song in Ableton's arrangement,
                // so Ableton will play into it seamlessly — just update the UI.
                currentSongIndex = nextSongIdx
                currentSectionIndex = 0
                activateSection(songIndex: nextSongIdx, sectionIndex: 0, fromBeat: sectionEndBeat)
            } else {
                // Setlist order differs from arrangement order — jump Ableton
                // to the first section of the next setlist song.
                jump(songIndex: nextSongIdx, sectionIndex: 0)
            }
        }
    }

    // MARK: - Message handling

    private func handle(_ text: String) {
        if isDemoMode { isDemoMode = false }
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "connection_rejected" {
            // Another device holds primary control — stop all reconnect attempts
            receiveGeneration += 1
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            reconnectTask?.cancel()
            reconnectTask = nil
            connectionState = .rejected
            return
        }

        if type == "control_released" {
            // Primary gave up control — reconnect immediately to take over
            receiveGeneration += 1
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            connectionState = .disconnected
            connect()
            return
        }

        // 1. Song list (state message only)
        if type == "state", let songsData = try? JSONSerialization.data(withJSONObject: json["songs"] ?? []) {
            if let role = json["role"] as? String { isPrimary = (role == "primary") }
            let newSongs = (try? JSONDecoder().decode([Song].self, from: songsData)) ?? []
            songs = newSongs
            // Reset setlist order when song count changes (new set loaded).
            // Preserve a custom order if the count is unchanged (e.g., cue rename).
            if newSongs.count != setlistOrder.count {
                if let saved = UserDefaults.standard.array(forKey: "setlistOrder_\(newSongs.count)") as? [Int],
                   Set(saved) == Set(newSongs.indices) {
                    setlistOrder = saved
                } else {
                    setlistOrder = Array(newSongs.indices)
                }
            }

            // Warn when cue count grows past the threshold — fires each time a new
            // marker is added while already over the limit.
            if let count = json["cue_count"] as? Int,
               let isWarning = json["cue_warning"] as? Bool,
               isWarning, count > lastNotifiedCueCount {
                cueCount = count
                lastNotifiedCueCount = count
                showCueWarning = true
            } else if let count = json["cue_count"] as? Int {
                cueCount = count
            }
        }

        // 2. Track list — present in state messages and dedicated tracks messages.
        let rawTracks = json["tracks"] as? [[String: Any]]
        if let rawTracks {
            applyTracks(rawTracks, applyPreset: type == "state")
        }

        // 3. Lightweight tracks-only update (mute toggle confirmed by bridge).
        if type == "tracks" { return }

        // Metadata, position, playing state, and section indices are applied
        // through applyTransport — the single path shared with the demo simulator.
        // forceActivate on state messages ensures section bounds are refreshed
        // after reconnects or mid-set cue edits, even if indices didn't change.
        applyTransport(
            tempo: json["tempo"] as? Double,
            timeSigNum: json["time_signature_numerator"] as? Int,
            position: json["position"] as? Double,
            isPlaying: json["is_playing"] as? Bool,
            songIndex: json["current_song_index"] as? Int,
            sectionIndex: json["current_section_index"] as? Int,
            forceActivate: type == "state"
        )
    }

    private func applyTracks(_ raw: [[String: Any]], applyPreset: Bool) {
        tracks = raw.compactMap { d in
            guard let idx = d["index"] as? Int,
                  let name = d["name"] as? String,
                  let muted = d["muted"] as? Bool else { return nil }
            return BridgeTrack(id: idx, name: name, isMuted: muted)
        }
        if applyPreset, currentSongIndex >= 0, songs.indices.contains(currentSongIndex) {
            applyTrackPreset(for: songs[currentSongIndex].name)
        }
    }

    /// Apply a transport snapshot to published state. Both the live bridge message
    /// handler and the demo simulator feed this one path, so jump-quantization
    /// suppression, section activation, and progress behave identically in both.
    /// forceActivate re-runs activateSection even when indices are unchanged —
    /// needed after a state message refreshes the song list (cue positions may differ).
    private func applyTransport(tempo t: Double?, timeSigNum: Int?, position pos: Double?,
                                isPlaying playing: Bool?, songIndex: Int?, sectionIndex: Int?,
                                forceActivate: Bool = false) {
        // Tempo / time signature (needed before activateSection).
        let prevTempo = tempo
        if let t { tempo = t }
        if let timeSigNum { timeSignatureNumerator = timeSigNum }

        // Position — with beat-quantized jump suppression.
        if let pos {
            if let target = pendingJumpPosition {
                // The launch has fired only once the playhead lands near the target.
                // Use distance (not pos >= target - 1) so backward jumps aren't
                // falsely confirmed while the transport is still ahead of the target.
                if abs(pos - target) < 1.0 {
                    pendingJumpPosition = nil
                    queuedSongIndex = -1
                    queuedSectionIndex = -1
                    jumpTimeoutTask?.cancel()
                    jumpTimeoutTask = nil
                    position = pos
                    sectionAnchorBeat = pos
                    sectionAnchorDate = Date()
                }
                // else: not there yet — hold the current section, discard update
            } else {
                let now = Date()
                // Measure real BPM from consecutive beat-level updates.
                // Beat updates advance position by ~1 beat; filter out sub-beat
                // current_song_time updates (dp < 0.5) and position resets (dp < 0).
                let dp = pos - prevAnchorPosition
                let dt = now.timeIntervalSince(prevAnchorDate)
                if prevAnchorPosition >= 0, dp > 0.5, dp < 4.0, dt > 0.1, dt < 4.0 {
                    let measured = dp / dt * 60.0
                    if measured > 20 && measured < 300 { interpolationTempo = measured }
                }
                prevAnchorPosition = pos
                prevAnchorDate = now
                position = pos
                sectionAnchorBeat = pos
                sectionAnchorDate = now
            }
        }

        // Playing state.
        if let playing {
            let wasPlaying = isPlaying
            isPlaying = playing
            if !playing && wasPlaying {
                sectionAnchorBeat = position
                sectionAnchorDate = Date()
            }
        }

        if tempo != prevTempo { scheduleAutoAdvance() }

        // Section indices — suppressed only in demo mode while a fake-bridge jump
        // is pending (pendingJumpPosition is never set in live bridge mode).
        if pendingJumpPosition == nil {
            let prevSong = currentSongIndex
            let prevSection = currentSectionIndex
            if let songIndex { currentSongIndex = songIndex }
            if let sectionIndex { currentSectionIndex = sectionIndex }
            if (currentSongIndex != prevSong || currentSectionIndex != prevSection || forceActivate),
               currentSongIndex >= 0, currentSectionIndex >= 0 {
                // New song → reset measured tempo and apply saved track preset.
                if currentSongIndex != prevSong {
                    interpolationTempo = 0
                    if songs.indices.contains(currentSongIndex) {
                        applyTrackPreset(for: songs[currentSongIndex].name)
                    }
                }
                // In live mode the section arriving at the queued target IS the confirmation.
                if currentSongIndex == queuedSongIndex && currentSectionIndex == queuedSectionIndex {
                    queuedSongIndex = -1
                    queuedSectionIndex = -1
                    jumpTimeoutTask?.cancel()
                    jumpTimeoutTask = nil
                }
                activateSection(songIndex: currentSongIndex, sectionIndex: currentSectionIndex, fromBeat: position)
            }
        }
    }

    // MARK: - Commands

    func jump(songIndex: Int, sectionIndex: Int) {
        guard isPrimary else { return }   // observers can look ahead but not jump
        // Cancel any pending auto-advance immediately. Without this, a section near
        // its end auto-advances in the UI before Ableton confirms the jump, flashing
        // the wrong section. The new auto-advance is rescheduled once the jump lands.
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil

        if isPlaying {
            if !isDemoMode && songIndex == currentSongIndex && sectionIndex == currentSectionIndex {
                // Same-section re-jump in live mode: reset the progress anchor now so
                // the bar starts over from 0 immediately instead of counting up then
                // snapping back when Ableton's position update arrives.
                sectionAnchorBeat = sectionStartBeat
                sectionAnchorDate = Date()
                scheduleAutoAdvance()
            } else {
                queuedSongIndex = songIndex
                queuedSectionIndex = sectionIndex
                if isDemoMode {
                    // Demo: pendingJumpPosition gates the fake-bridge ticker until the
                    // simulated launch-quantization beat is reached.
                    if songs.indices.contains(songIndex),
                       songs[songIndex].sections.indices.contains(sectionIndex) {
                        pendingJumpPosition = songs[songIndex].sections[sectionIndex].position
                    }
                    let beatsPerBar = Double(timeSignatureNumerator)
                    demoJumpLaunchBeat = (floor(demoPlayheadBeat / beatsPerBar) + 1) * beatsPerBar
                } else {
                    // Live bridge: don't set pendingJumpPosition — position updates must
                    // keep flowing so the anchor stays fresh and the bar doesn't snap.
                    // The section changing to the queued target is confirmation enough.
                    scheduleJumpTimeout()
                }
            }
        } else {
            // Stopped — snap the UI immediately, no quantization needed.
            queuedSongIndex = -1
            queuedSectionIndex = -1
            currentSongIndex = songIndex
            currentSectionIndex = sectionIndex
            if songs.indices.contains(songIndex),
               songs[songIndex].sections.indices.contains(sectionIndex) {
                let targetPosition = songs[songIndex].sections[sectionIndex].position
                if isDemoMode { pendingJumpPosition = targetPosition }
                position = targetPosition
                demoPlayheadBeat = targetPosition
                activateSection(songIndex: songIndex, sectionIndex: sectionIndex, fromBeat: targetPosition)
            }
        }
        send(["type": "jump", "song_index": songIndex, "section_index": sectionIndex])
    }

    func toggleTrackMute(trackIndex: Int) {
        guard isPrimary else { return }
        guard let idx = tracks.firstIndex(where: { $0.id == trackIndex }) else { return }
        let newMuted = !tracks[idx].isMuted
        tracks[idx].isMuted = newMuted
        send(["type": "mute_track", "track_index": trackIndex, "muted": newMuted])
        saveTrackPreset()
    }

    private func saveTrackPreset() {
        guard currentSongIndex >= 0, songs.indices.contains(currentSongIndex) else { return }
        let key = "trackMutes_\(songs[currentSongIndex].name)"
        UserDefaults.standard.set(tracks.map(\.isMuted), forKey: key)
    }

    private func applyTrackPreset(for songName: String) {
        let key = "trackMutes_\(songName)"
        guard let saved = UserDefaults.standard.array(forKey: key) as? [Bool],
              !tracks.isEmpty else { return }
        for (i, muted) in saved.enumerated() {
            guard i < tracks.count else { break }
            guard tracks[i].isMuted != muted else { continue }
            tracks[i].isMuted = muted
            send(["type": "mute_track", "track_index": tracks[i].id, "muted": muted])
        }
    }

    func reorderSetlist(from source: Int, to destination: Int) {
        guard source != destination,
              setlistOrder.indices.contains(source),
              (0...setlistOrder.count).contains(destination) else { return }
        var order = setlistOrder
        let item = order.remove(at: source)
        let adjusted = destination > source ? destination - 1 : destination
        order.insert(item, at: adjusted)
        setlistOrder = order
        UserDefaults.standard.set(order, forKey: "setlistOrder_\(order.count)")
    }

    func generateCues(trackName: String = "Cues") {
        guard isPrimary else { return }
        send(["type": "generate_cues", "track_name": trackName])
    }

    func play() {
        guard isPrimary else { return }
        isPlaying = true
        sectionAnchorDate = Date()   // restart elapsed-time from now so progress doesn't jump
        scheduleAutoAdvance()
        send(["type": "transport", "action": "play"])
    }

    func stop() {
        guard isPrimary else { return }
        isPlaying = false
        sectionAnchorBeat = position // freeze progress at current position
        autoAdvanceTask?.cancel()
        if webSocketTask == nil {
            // Clear any pending offline jump so it doesn't keep pulsing while stopped.
            queuedSongIndex = -1
            queuedSectionIndex = -1
            pendingJumpPosition = nil
            demoJumpLaunchBeat = nil
        }
        send(["type": "transport", "action": "stop"])
    }

    func refresh() { send(["type": "refresh"]) }

    func releaseControl() {
        guard isPrimary else { return }
        send(["type": "release_control"])
    }

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { [weak self] error in
            if error != nil {
                Task { @MainActor [weak self] in
                    guard let self, self.connectionState == .connected else { return }
                    self.connectionState = .disconnected
                    self.scheduleReconnect()
                }
            }
        }
    }
}
