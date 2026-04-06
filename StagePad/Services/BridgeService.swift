import Foundation
import Combine

enum ConnectionState {
    case disconnected, connecting, connected
}

@MainActor
final class BridgeService: ObservableObject {
    @Published var songs: [Song] = []
    @Published var currentSongIndex: Int = -1
    @Published var currentSectionIndex: Int = -1
    @Published var position: Double = 0
    @Published var isPlaying: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var tempo: Double = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private let session = URLSession(configuration: .default)

    var host: String {
        get { UserDefaults.standard.string(forKey: "bridge_host") ?? "10.0.0.101" }
        set { UserDefaults.standard.set(newValue, forKey: "bridge_host") }
    }

    private var url: URL {
        URL(string: "ws://\(host):8766/ws")!
    }

    func connect() {
        disconnect()
        connectionState = .connecting
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        connectionState = .connected
        receive()
    }

    func disconnect() {
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handle(text)
                    }
                    self.receive()
                case .failure:
                    self.connectionState = .disconnected
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "state", let songsData = try? JSONSerialization.data(withJSONObject: json["songs"] ?? []) {
            songs = (try? JSONDecoder().decode([Song].self, from: songsData)) ?? []
        }

        if let pos = json["position"] as? Double          { position = pos }
        if let playing = json["is_playing"] as? Bool      { isPlaying = playing }
        if let si = json["current_song_index"] as? Int    { currentSongIndex = si }
        if let sc = json["current_section_index"] as? Int { currentSectionIndex = sc }
        if let t = json["tempo"] as? Double               { tempo = t }
    }

    private func scheduleReconnect() {
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            connect()
        }
    }

    // MARK: - Commands

    func jump(songIndex: Int, sectionIndex: Int) {
        send(["type": "jump", "song_index": songIndex, "section_index": sectionIndex])
    }

    func play() {
        send(["type": "transport", "action": "play"])
    }

    func stop() {
        send(["type": "transport", "action": "stop"])
    }

    func refresh() {
        send(["type": "refresh"])
    }

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }
}
