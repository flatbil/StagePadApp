import Foundation

// MARK: - Models

struct PCSection: Identifiable {
    let id = UUID()
    let label: String
    let number: Int
    var displayName: String { number > 1 ? "\(label) \(number)" : label }
}

struct PCSong: Identifiable {
    let id = UUID()
    let title: String
    let key: String
    let bpm: Double
    let meter: String
    let sections: [PCSection]
    let chordChart: String?

    // Nashville chords per section name, parsed from chord_chart if available
    var nashvilleBySection: [String: String] {
        guard let chart = chordChart, !key.isEmpty else { return [:] }
        let parsed = NashvilleConverter.parseSections(from: chart, key: key)
        return Dictionary(parsed.map { ($0.name.lowercased(), $0.nashvilleChords) },
                          uniquingKeysWith: { first, _ in first })
    }
}

struct PCServicePlan: Identifiable {
    let id: String
    let title: String
    let dates: String
    let songs: [PCSong]
}

// MARK: - Service

@MainActor
class PlanningCenterService: ObservableObject {
    @Published var currentPlan: PCServicePlan?
    @Published var isLoading = false
    @Published var error: String?

    private let applicationID: String
    private let secret: String
    private let serviceTypeID: String
    private let base = "https://api.planningcenteronline.com/services/v2"

    init(applicationID: String = PCConfig.applicationID,
         secret: String = PCConfig.secret,
         serviceTypeID: String = PCConfig.serviceTypeID) {
        self.applicationID = applicationID
        self.secret = secret
        self.serviceTypeID = serviceTypeID
    }

    func fetchCurrentPlan() async {
        isLoading = true
        error = nil
        do {
            currentPlan = try await fetchUpcomingPlan()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // Find the song in the current plan whose title best matches the given Ableton song name
    func song(matchingAbletonName name: String) -> PCSong? {
        guard let plan = currentPlan else { return nil }
        let lower = name.lowercased()
        return plan.songs.first { $0.title.lowercased().contains(lower) || lower.contains($0.title.lowercased()) }
    }

    // Given the current section label from Ableton, return the next section in the PC arrangement
    func nextSection(after currentLabel: String, in song: PCSong) -> PCSection? {
        let lower = currentLabel.lowercased()
        guard let idx = song.sections.firstIndex(where: { $0.label.lowercased() == lower }) else { return nil }
        let nextIdx = idx + 1
        return nextIdx < song.sections.count ? song.sections[nextIdx] : nil
    }

    // MARK: - Private networking

    private func get(_ path: String) async throws -> [String: Any] {
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        let creds = Data("\(applicationID):\(secret)".utf8).base64EncodedString()
        request.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func fetchUpcomingPlan() async throws -> PCServicePlan {
        let json = try await get("/service_types/\(serviceTypeID)/plans?filter=future&per_page=1&order=sort_date")
        guard let planData = (json["data"] as? [[String: Any]])?.first else {
            throw URLError(.badServerResponse)
        }
        let planID = planData["id"] as! String
        let attrs = planData["attributes"] as? [String: Any] ?? [:]
        let title = attrs["title"] as? String ?? "Untitled"
        let dates = attrs["dates"] as? String ?? ""
        let songs = try await fetchSongs(planID: planID)
        return PCServicePlan(id: planID, title: title, dates: dates, songs: songs)
    }

    private func fetchSongs(planID: String) async throws -> [PCSong] {
        let json = try await get("/service_types/\(serviceTypeID)/plans/\(planID)/items?include=arrangement&per_page=100")
        let items = json["data"] as? [[String: Any]] ?? []
        let included = json["included"] as? [[String: Any]] ?? []

        var arrangementAttrs: [String: [String: Any]] = [:]
        for inc in included where (inc["type"] as? String) == "Arrangement" {
            if let id = inc["id"] as? String {
                arrangementAttrs[id] = inc["attributes"] as? [String: Any]
            }
        }

        var songs: [PCSong] = []
        for item in items {
            let attrs = item["attributes"] as? [String: Any] ?? [:]
            guard (attrs["item_type"] as? String) == "song" else { continue }

            let title = attrs["title"] as? String ?? "Unknown"
            let keyName = attrs["key_name"] as? String ?? ""

            let rels = item["relationships"] as? [String: Any] ?? [:]
            let arrID = ((rels["arrangement"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String ?? ""
            let arr = arrangementAttrs[arrID]

            let bpm = arr?["bpm"] as? Double ?? 0
            let meter = arr?["meter"] as? String ?? "4/4"
            let chordChart = arr?["chord_chart"] as? String

            let seqFull = arr?["sequence_full"] as? [[String: Any]] ?? []
            let sections: [PCSection] = seqFull.compactMap { s in
                guard let label = s["label"] as? String else { return nil }
                let num = Int(s["number"] as? String ?? "1") ?? 1
                return PCSection(label: label, number: num)
            }

            songs.append(PCSong(title: title, key: keyName, bpm: bpm, meter: meter,
                                sections: sections, chordChart: chordChart))
        }
        return songs
    }
}
