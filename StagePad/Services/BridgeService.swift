import Foundation

enum ConnectionState: Equatable {
    case disconnected, connecting, connected
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
        // Extract IPv4 addresses, preferring routable ones over link-local.
        // 169.254.x.x (link-local/USB) can time out — prefer 192.168/10/172 WiFi addresses.
        var linkLocal: String? = nil

        if let addresses = sender.addresses {
            for data in addresses {
                var storage = sockaddr_storage()
                (data as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
                guard storage.ss_family == AF_INET else { continue }
                var addr = withUnsafePointer(to: &storage) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                }
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                let ip = String(cString: buf)
                guard !ip.isEmpty, ip != "0.0.0.0", ip != "127.0.0.1" else { continue }

                if ip.hasPrefix("169.254.") {
                    linkLocal = ip  // keep as fallback only
                } else {
                    onResolved?(ip, sender.port)  // routable address — use it
                    return
                }
            }
        }

        // No routable address found — try link-local, then hostname
        if let ip = linkLocal {
            onResolved?(ip, sender.port)
            return
        }
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
    @Published var tempo: Double = 0
    @Published var timeSignatureNumerator: Int = 4
    /// Section queued to jump to (awaiting Ableton's beat-quantized confirmation).
    /// -1 means no jump pending.
    @Published var queuedSongIndex: Int = -1
    @Published var queuedSectionIndex: Int = -1

    // Section timing — read by TimelineView in SectionButtonWrapper at render time.
    // Not @Published: changing these must not trigger re-renders; TimelineView polls them.
    var sectionStartBeat: Double = 0
    var sectionEndBeat: Double = 1
    var sectionAnchorBeat: Double = 0    // beat position confirmed at anchorDate
    var sectionAnchorDate: Date = Date()

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var receiveGeneration = 0
    private let session = URLSession(configuration: .default)
    private let discovery = BridgeDiscovery()

    // Pending jump — suppress server position/section updates until Ableton
    // reaches the target (avoids snap-back during launch quantization hold)
    private var pendingJumpPosition: Double? = nil

    /// True while waiting for Ableton to confirm the jump has launched.
    /// Progress bars should freeze until this clears.
    var isJumpPending: Bool { pendingJumpPosition != nil }

    // The host currently in use — set by Bonjour discovery or manual entry
    private var activeHost: String = ""
    var activeHostPublished: String { activeHost }

    var host: String {
        get { UserDefaults.standard.string(forKey: "bridge_host") ?? "192.168.4.29" }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_host") }
    }

    // MARK: - Saved devices

    struct SavedDevice: Codable, Identifiable, Equatable {
        var id: String { host }
        var name: String
        var host: String
    }

    var savedDevices: [SavedDevice] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "saved_devices"),
                  let devices = try? JSONDecoder().decode([SavedDevice].self, from: data)
            else { return [] }
            return devices
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "saved_devices")
            }
        }
    }

    /// Called after a successful connection — saves the host with an auto-generated name.
    func saveCurrentDevice() {
        guard !activeHost.isEmpty else { return }
        var devices = savedDevices
        // Don't duplicate
        guard !devices.contains(where: { $0.host == activeHost }) else { return }
        // Derive a friendly name from the hostname (strip .local suffix)
        var name = activeHost
        if name.hasSuffix(".local") { name = String(name.dropLast(6)) }
        name = name.replacingOccurrences(of: "-", with: " ").capitalized
        if name.isEmpty || name == activeHost { name = "Bridge (\(activeHost))" }
        devices.append(SavedDevice(name: name, host: activeHost))
        savedDevices = devices
    }

    func deleteDevice(_ device: SavedDevice) {
        savedDevices = savedDevices.filter { $0.host != device.host }
    }

    func renameDevice(_ device: SavedDevice, to name: String) {
        var devices = savedDevices
        if let idx = devices.firstIndex(where: { $0.host == device.host }) {
            devices[idx].name = name
            savedDevices = devices
        }
    }

    func connect(to device: SavedDevice) {
        host = device.host
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .connecting

        #if targetEnvironment(simulator)
        // In the Simulator, use preview data only — no live bridge connection.
        // This gives clean, consistent screenshots without needing Ableton running.
        songs = Song.previewSongs
        setlistOrder = Array(songs.indices)
        currentSongIndex = 0
        currentSectionIndex = 2  // land on "Chorus" of first song
        tempo = 76
        timeSignatureNumerator = 4
        isPlaying = true
        connectionState = .connected
        activateSection(songIndex: 0, sectionIndex: 2, fromBeat: 24)
        #else
        // Try Bonjour first — resolves to USB interface when iPad is plugged in,
        // WiFi otherwise. Falls back to manual host after 3 seconds.
        discovery.stop()
        discovery.onResolved = { [weak self] resolvedHost, _ in
            guard let self else { return }
            self.discovery.stop()
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
                openSocket(to: host)
            }
        }
        #endif
    }

    private func openSocket(to resolvedHost: String) {
        // Cancel the fallback timer if Bonjour beat it
        reconnectTask?.cancel()
        reconnectTask = nil

        guard let socketURL = url(for: resolvedHost) else {
            connectionState = .disconnected
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
                    self.saveCurrentDevice()
                } else {
                    self.connectionState = .disconnected
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
        discovery.stop()
        receiveGeneration += 1
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
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
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil else { return }
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
        guard isPlaying, tempo > 0 else { return }

        // Estimate where we are right now using elapsed wall-clock time since
        // the last server-confirmed anchor. This keeps the timer accurate after
        // a tempo change — the old task used the stale bpm and would fire early.
        let elapsed = Date().timeIntervalSince(sectionAnchorDate)
        let estimatedBeat = sectionAnchorBeat + elapsed * tempo / 60.0
        guard sectionEndBeat > estimatedBeat else { return }

        let secondsRemaining = (sectionEndBeat - estimatedBeat) * 60.0 / tempo
        let fromSong    = currentSongIndex
        let fromSection = currentSectionIndex
        autoAdvanceTask = Task {
            try? await Task.sleep(for: .seconds(secondsRemaining))
            guard !Task.isCancelled else { return }
            self.autoAdvanceSection(fromSong: fromSong, fromSection: fromSection)
        }
    }

    private func autoAdvanceSection(fromSong: Int, fromSection: Int) {
        if songs.indices.contains(fromSong),
           songs[fromSong].sections.indices.contains(fromSection + 1) {
            // ── Next section within the same song ─────────────────────────
            // Guard here: server may have already moved us — don't go backwards.
            guard currentSongIndex == fromSong, currentSectionIndex == fromSection else { return }
            let nextSection = fromSection + 1
            currentSongIndex = fromSong
            currentSectionIndex = nextSection
            activateSection(songIndex: fromSong, sectionIndex: nextSection, fromBeat: sectionEndBeat)

        } else {
            // ── End of song — always apply setlist order ──────────────────
            // Don't guard on currentSongIndex here: the server may have already
            // updated it (Ableton plays through), but setlist-order redirect
            // must still fire.
            guard let posInSetlist = setlistOrder.firstIndex(of: fromSong),
                  posInSetlist + 1 < setlistOrder.count else { return }
            let nextSongIdx = setlistOrder[posInSetlist + 1]

            if nextSongIdx == fromSong + 1 {
                // Setlist matches arrangement — Ableton plays through naturally.
                // Only update UI if server hasn't already moved us past this point.
                if currentSongIndex <= fromSong {
                    currentSongIndex = nextSongIdx
                    currentSectionIndex = 0
                    activateSection(songIndex: nextSongIdx, sectionIndex: 0, fromBeat: sectionEndBeat)
                }
            } else {
                // Setlist order differs — jump Ableton to the correct next song.
                jump(songIndex: nextSongIdx, sectionIndex: 0)
            }
        }
    }

    // MARK: - Message handling

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        // 1. Song list (state message only)
        if type == "state", let songsData = try? JSONSerialization.data(withJSONObject: json["songs"] ?? []) {
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
        }

        // 2. Metadata first (tempo needed before activateSection)
        let prevTempo = tempo
        if let t = json["tempo"] as? Double                  { tempo = t }
        if let n = json["time_signature_numerator"] as? Int  { timeSignatureNumerator = n }

        // 3. Position — update anchor for TimelineView interpolation
        if let pos = json["position"] as? Double {
            if let target = pendingJumpPosition {
                // Still waiting for Ableton's beat-quantized jump to fire
                if pos >= target - 1.0 {
                    pendingJumpPosition = nil
                    queuedSongIndex = -1
                    queuedSectionIndex = -1
                    position = pos
                    sectionAnchorBeat = pos
                    sectionAnchorDate = Date()
                }
                // else: not there yet — keep current section active, discard update
            } else {
                position = pos
                sectionAnchorBeat = pos
                sectionAnchorDate = Date()
            }
        }

        // 4. Playing state
        if let playing = json["is_playing"] as? Bool {
            let wasPlaying = isPlaying
            isPlaying = playing
            if !playing && wasPlaying {
                // Stopped: freeze anchor at current server position
                sectionAnchorBeat = position
                sectionAnchorDate = Date()
            }
        }

        // 4b. If tempo changed, reschedule auto-advance with the new rate.
        // Position anchor was just refreshed above so the estimate will be accurate.
        if tempo != prevTempo { scheduleAutoAdvance() }

        // 5. Section indices — trigger activateSection on organic change
        if pendingJumpPosition == nil {
            let prevSong = currentSongIndex
            let prevSection = currentSectionIndex
            if let si = json["current_song_index"] as? Int    { currentSongIndex = si }
            if let sc = json["current_section_index"] as? Int { currentSectionIndex = sc }
            if (currentSongIndex != prevSong || currentSectionIndex != prevSection),
               currentSongIndex >= 0, currentSectionIndex >= 0 {
                activateSection(songIndex: currentSongIndex, sectionIndex: currentSectionIndex, fromBeat: position)
            }
        }
    }

    // MARK: - Commands

    func jump(songIndex: Int, sectionIndex: Int) {
        if isPlaying {
            // Queue the jump — let Ableton's launch quantization fire on beat.
            // Keep the current section active in the UI until Ableton confirms.
            queuedSongIndex = songIndex
            queuedSectionIndex = sectionIndex
            if songs.indices.contains(songIndex),
               songs[songIndex].sections.indices.contains(sectionIndex) {
                pendingJumpPosition = songs[songIndex].sections[sectionIndex].position
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
                pendingJumpPosition = targetPosition
                position = targetPosition
                activateSection(songIndex: songIndex, sectionIndex: sectionIndex, fromBeat: targetPosition)
            }
        }
        send(["type": "jump", "song_index": songIndex, "section_index": sectionIndex])
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
        send(["type": "generate_cues", "track_name": trackName])
    }

    func play() {
        isPlaying = true
        sectionAnchorDate = Date()   // restart elapsed-time from now so progress doesn't jump
        scheduleAutoAdvance()
        send(["type": "transport", "action": "play"])
    }

    func stop() {
        isPlaying = false
        sectionAnchorBeat = position // freeze progress at current position
        autoAdvanceTask?.cancel()
        send(["type": "transport", "action": "stop"])
    }

    func refresh() { send(["type": "refresh"]) }

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
