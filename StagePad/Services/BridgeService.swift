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
        guard let host = sender.hostName else { return }
        onResolved?(host, sender.port)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // Resolution failed — BridgeService will time out and fall back to manual host
    }
}

@MainActor
final class BridgeService: ObservableObject {
    @Published var songs: [Song] = []
    @Published var currentSongIndex: Int = -1
    @Published var currentSectionIndex: Int = -1
    @Published var position: Double = 0          // beats from set start — server-side, for measure display
    @Published var isPlaying: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var tempo: Double = 0
    @Published var timeSignatureNumerator: Int = 4

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

    var host: String {
        get { UserDefaults.standard.string(forKey: "bridge_host") ?? "192.168.4.29" }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_host") }
    }

    private func url(for resolvedHost: String) -> URL {
        URL(string: "ws://\(resolvedHost):8766/ws")!
    }

    // MARK: - Connection

    func connect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .connecting

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
    }

    private func openSocket(to resolvedHost: String) {
        // Cancel the fallback timer if Bonjour beat it
        reconnectTask?.cancel()
        reconnectTask = nil

        activeHost = resolvedHost
        receiveGeneration += 1
        let generation = receiveGeneration

        let task = session.webSocketTask(with: url(for: resolvedHost))
        webSocketTask = task
        task.resume()

        task.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.receiveGeneration == generation else { return }
                if error == nil {
                    self.connectionState = .connected
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
        guard isPlaying, tempo > 0, sectionEndBeat > sectionAnchorBeat else { return }
        let secondsRemaining = (sectionEndBeat - sectionAnchorBeat) * 60.0 / tempo
        let fromSong = currentSongIndex
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

        let nextSong: Int
        let nextSection: Int
        if songs.indices.contains(fromSong),
           songs[fromSong].sections.indices.contains(fromSection + 1) {
            nextSong = fromSong
            nextSection = fromSection + 1
        } else if songs.indices.contains(fromSong + 1) {
            nextSong = fromSong + 1
            nextSection = 0
        } else {
            return  // last section of last song
        }

        currentSongIndex = nextSong
        currentSectionIndex = nextSection
        // fromBeat = sectionEndBeat so the new section starts exactly at its boundary
        activateSection(songIndex: nextSong, sectionIndex: nextSection, fromBeat: sectionEndBeat)
    }

    // MARK: - Message handling

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        // 1. Song list (state message only)
        if type == "state", let songsData = try? JSONSerialization.data(withJSONObject: json["songs"] ?? []) {
            songs = (try? JSONDecoder().decode([Song].self, from: songsData)) ?? []
        }

        // 2. Metadata first (tempo needed before activateSection)
        if let t = json["tempo"] as? Double                  { tempo = t }
        if let n = json["time_signature_numerator"] as? Int  { timeSignatureNumerator = n }

        // 3. Position — update anchor for TimelineView interpolation
        if let pos = json["position"] as? Double {
            if let target = pendingJumpPosition {
                // Still waiting for quantization hold to resolve
                if pos >= target - 1.0 {
                    pendingJumpPosition = nil
                    position = pos
                    sectionAnchorBeat = pos
                    sectionAnchorDate = Date()
                }
                // else: discard — keep optimistic anchor
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
        currentSongIndex = songIndex
        currentSectionIndex = sectionIndex
        if songs.indices.contains(songIndex),
           songs[songIndex].sections.indices.contains(sectionIndex) {
            let targetPosition = songs[songIndex].sections[sectionIndex].position
            pendingJumpPosition = targetPosition
            position = targetPosition
            activateSection(songIndex: songIndex, sectionIndex: sectionIndex, fromBeat: targetPosition)
        }
        send(["type": "jump", "song_index": songIndex, "section_index": sectionIndex])
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
