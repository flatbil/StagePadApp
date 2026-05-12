import Foundation
import PDFKit

// MARK: - Models

struct PCSection: Identifiable {
    let id = UUID()
    let label: String
    let number: Int
    let startTime: Double?  // seconds from song start, parsed from sequence_full "t" field
    var displayName: String { number > 1 ? "\(label) \(number)" : label }
}

struct PCSong: Identifiable, Equatable {
    static func == (lhs: PCSong, rhs: PCSong) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    let title: String
    let key: String
    let bpm: Double
    let meter: String
    let length: Double       // total song length in seconds
    let sections: [PCSection]
    let chordChart: String?

    func sectionDuration(at index: Int) -> Double? {
        guard sections.indices.contains(index),
              let start = sections[index].startTime else { return nil }
        if index + 1 < sections.count, let next = sections[index + 1].startTime {
            return next - start
        }
        return length - start
    }

    var nashvilleBySection: [String: String] {
        guard let chart = chordChart, !key.isEmpty else { return [:] }
        let parsed = NashvilleConverter.parseSections(from: chart, key: key)
        return Dictionary(parsed.map { ($0.name.lowercased(), $0.nashvilleChords) },
                          uniquingKeysWith: { first, _ in first })
    }

    var rawChordsBySection: [String: String] {
        guard let chart = chordChart else { return [:] }
        let parsed = NashvilleConverter.parseRawSections(from: chart)
        return Dictionary(parsed.map { ($0.name.lowercased(), $0.chords) },
                          uniquingKeysWith: { first, _ in first })
    }

    var lyricsbySection: [String: String] {
        guard let chart = chordChart else { return [:] }
        return parseLyricSections(from: chart)
    }

    private func parseLyricSections(from text: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentKey = ""
        var currentLines: [String] = []
        let headers = ["intro","verse","chorus","pre-chorus","pre chorus","bridge",
                       "tag","outro","ending","vamp","interlude","refrain",
                       "breakdown","turnaround","post-chorus","post chorus"]

        func commitCurrent() {
            guard !currentKey.isEmpty else { return }
            result[currentKey] = joinContinuations(currentLines)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let headerText = NashvilleConverter.extractHeaderName(
                NashvilleConverter.stripSectionAbbreviation(trimmed))
            let lower = headerText.lowercased()
            if headers.contains(where: { lower.hasPrefix($0) }) {
                commitCurrent()
                currentKey = lower
                currentLines = []
            } else if !trimmed.isEmpty && !currentKey.isEmpty {
                if !NashvilleConverter.isChordOnlyLine(trimmed) {
                    currentLines.append(trimmed)
                }
            }
        }
        commitCurrent()
        return result
    }

    // Join lines that are mid-phrase splits from PDF extraction:
    // if a line doesn't end with sentence punctuation and the next starts lowercase, merge them.
    private func joinContinuations(_ lines: [String]) -> String {
        guard !lines.isEmpty else { return "" }
        var merged: [String] = []
        var buffer = lines[0]
        for i in 1..<lines.count {
            let next = lines[i]
            let endChar = buffer.last
            let endsPhrase = endChar == "." || endChar == "?" || endChar == "!" || endChar == ","
            let nextStartsLower = next.first?.isLowercase == true
            if !endsPhrase && nextStartsLower {
                buffer += " " + next
            } else {
                merged.append(buffer)
                buffer = next
            }
        }
        merged.append(buffer)
        return merged.joined(separator: "\n")
    }
}

struct PCPlanSummary: Identifiable {
    let id: String
    let title: String
    let dates: String
    let sortDate: Date
    let songCount: Int
}

struct PCServicePlan: Identifiable, Equatable {
    static func == (lhs: PCServicePlan, rhs: PCServicePlan) -> Bool { lhs.id == rhs.id }
    let id: String
    let title: String
    let dates: String
    let songs: [PCSong]
}

// MARK: - App Mode

enum AppMode: String, CaseIterable {
    case bridge = "Bridge"
    case arrangementSheet = "Arrangement Sheet"
}

// MARK: - Service

@MainActor
class PlanningCenterService: ObservableObject {
    @Published var appMode: AppMode = .arrangementSheet
    @Published var currentPlan: PCServicePlan?
    @Published var availablePlans: [PCPlanSummary] = []
    @Published var isLoading = false
    @Published var isLoadingPlans = false
    @Published var error: String?

    // Demo / Arrangement Sheet mode state
    @Published var demoSong: PCSong?
    @Published var demoSectionIndex: Int = 0
    @Published var demoSectionStartDate: Date?

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

    // MARK: - Demo mode

    func setDemoSong(_ song: PCSong) {
        demoSong = song
        demoSectionIndex = 0
        demoSectionStartDate = Date()
    }

    func setDemoSection(index: Int) {
        guard let song = demoSong, song.sections.indices.contains(index) else { return }
        demoSectionIndex = index
        demoSectionStartDate = Date()
    }

    func advanceDemoSection() {
        guard let song = demoSong else { return }
        let next = demoSectionIndex + 1
        if next < song.sections.count { setDemoSection(index: next) }
    }

    func retreatDemoSection() {
        let prev = demoSectionIndex - 1
        if prev >= 0 { setDemoSection(index: prev) }
    }

    var demoCurrentSection: PCSection? {
        guard let song = demoSong, song.sections.indices.contains(demoSectionIndex) else { return nil }
        return song.sections[demoSectionIndex]
    }

    var demoNextSection: PCSection? {
        guard let song = demoSong else { return nil }
        let next = demoSectionIndex + 1
        return next < song.sections.count ? song.sections[next] : nil
    }

    // Progress 0.0-1.0 for current demo section based on wall-clock time
    func demoSectionProgress(at now: Date) -> Double {
        guard let song = demoSong,
              let startDate = demoSectionStartDate,
              let duration = song.sectionDuration(at: demoSectionIndex),
              duration > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(startDate)
        return min(elapsed / duration, 1.0)
    }

    // MARK: - Plan fetching

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

    func fetchAvailablePlans() async {
        isLoadingPlans = true
        do {
            let upcoming = try await fetchPlanSummaries(filter: "future", order: "sort_date", limit: 10)
            let past = try await fetchPlanSummaries(filter: "past", order: "-sort_date", limit: 25)
            availablePlans = upcoming + past
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingPlans = false
    }

    func loadPlan(id: String) async {
        isLoading = true
        error = nil
        do {
            let songs = try await fetchSongs(planID: id)
            if let summary = availablePlans.first(where: { $0.id == id }) {
                currentPlan = PCServicePlan(id: id, title: summary.title, dates: summary.dates, songs: songs)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Ableton matching helpers

    func song(matchingAbletonName name: String) -> PCSong? {
        guard let plan = currentPlan else { return nil }
        let lower = name.lowercased()
        return plan.songs.first { $0.title.lowercased().contains(lower) || lower.contains($0.title.lowercased()) }
    }

    func nextSection(after currentLabel: String, in song: PCSong) -> PCSection? {
        let lower = currentLabel.lowercased()
        guard let idx = song.sections.firstIndex(where: { $0.label.lowercased() == lower }) else { return nil }
        let next = idx + 1
        return next < song.sections.count ? song.sections[next] : nil
    }

    // MARK: - Networking

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

    private func fetchPlanSummaries(filter: String, order: String, limit: Int) async throws -> [PCPlanSummary] {
        let json = try await get("/service_types/\(serviceTypeID)/plans?filter=\(filter)&order=\(order)&per_page=\(limit)")
        let items = json["data"] as? [[String: Any]] ?? []
        let fmt = ISO8601DateFormatter()
        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let attrs = item["attributes"] as? [String: Any] else { return nil }
            let title = attrs["title"] as? String ?? "Untitled"
            let dates = attrs["dates"] as? String ?? ""
            let sortStr = attrs["sort_date"] as? String ?? ""
            let sortDate = fmt.date(from: sortStr) ?? Date.distantPast
            let songCount = attrs["items_count"] as? Int ?? 0
            return PCPlanSummary(id: id, title: title, dates: dates, sortDate: sortDate, songCount: songCount)
        }
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

        // Collect song items first so we can fetch PDF attachments per item
        struct RawItem {
            let itemID: String; let title: String; let keyName: String; let arrID: String
        }
        var rawItems: [RawItem] = []
        for item in items {
            let attrs = item["attributes"] as? [String: Any] ?? [:]
            guard (attrs["item_type"] as? String) == "song",
                  let itemID = item["id"] as? String else { continue }
            let title   = attrs["title"]    as? String ?? "Unknown"
            let keyName = attrs["key_name"] as? String ?? ""
            let rels    = item["relationships"] as? [String: Any] ?? [:]
            let arrID   = ((rels["arrangement"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String ?? ""
            rawItems.append(RawItem(itemID: itemID, title: title, keyName: keyName, arrID: arrID))
        }

        // Fetch PDF attachments sequentially (one request per song item)
        var pdfChartByArrID: [String: String] = [:]
        for raw in rawItems {
            if let text = try? await fetchPDFChartText(itemID: raw.itemID, planID: planID) {
                pdfChartByArrID[raw.arrID] = text
            }
        }

        return rawItems.map { raw in
            let arr = arrangementAttrs[raw.arrID]
            let bpm    = arr?["bpm"]    as? Double ?? 0
            let meter  = arr?["meter"]  as? String ?? "4/4"
            let length = Double(arr?["length"] as? Int ?? 0)

            // Text chord chart takes priority; PDF extraction is the fallback
            let textChart = arr?["chord_chart"] as? String
            let chordChart: String? = (textChart != nil && !textChart!.isEmpty)
                ? textChart : pdfChartByArrID[raw.arrID]

            print("[PC] \(raw.title) | key=\(raw.keyName) | chart=\(chordChart.map { "\($0.count) chars" } ?? "nil")")

            let seqFull = arr?["sequence_full"] as? [[String: Any]] ?? []
            let sections: [PCSection] = seqFull.compactMap { s in
                guard let label = s["label"] as? String else { return nil }
                let num = Int(s["number"] as? String ?? "1") ?? 1
                let startTime = (s["t"] as? String).flatMap { parsePCTime($0) }
                return PCSection(label: label, number: num, startTime: startTime)
            }
            return PCSong(title: raw.title, key: raw.keyName, bpm: bpm, meter: meter,
                          length: length, sections: sections, chordChart: chordChart)
        }
    }

    // Fetch the first PDF attachment for a plan item and extract its text
    private func fetchPDFChartText(itemID: String, planID: String) async throws -> String? {
        let json = try await get("/service_types/\(serviceTypeID)/plans/\(planID)/items/\(itemID)/attachments")
        let attachments = json["data"] as? [[String: Any]] ?? []

        for attachment in attachments {
            let attrs       = attachment["attributes"] as? [String: Any] ?? [:]
            let attachmentID = attachment["id"] as? String ?? ""
            let filename    = attrs["filename"]     as? String ?? ""
            let contentType = attrs["content_type"] as? String ?? ""

            guard filename.lowercased().hasSuffix(".pdf") || contentType == "application/pdf" else { continue }

            // Use the API /open action — returns 302 redirect to a signed S3 URL
            let apiPath = "/service_types/\(serviceTypeID)/plans/\(planID)/items/\(itemID)/attachments/\(attachmentID)/open"
            guard let openURL = URL(string: "https://api.planningcenteronline.com/services/v2" + apiPath) else { continue }
            print("[PC] Fetching PDF via API open: \(filename)")

            var request = URLRequest(url: openURL)
            request.httpMethod = "POST"
            let creds = Data("\(applicationID):\(secret)".utf8).base64EncodedString()
            request.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (openData, _) = try await URLSession.shared.data(for: request)
            guard let openJSON = try? JSONSerialization.jsonObject(with: openData) as? [String: Any],
                  let s3UrlStr = ((openJSON["data"] as? [String: Any])?["attributes"] as? [String: Any])?["attachment_url"] as? String,
                  let s3URL = URL(string: s3UrlStr) else {
                print("[PC] Could not parse attachment_url from open response")
                continue
            }

            print("[PC] Downloading PDF from S3: \(filename)")
            let (data, response) = try await URLSession.shared.data(from: s3URL)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let firstBytes = data.prefix(5).map { String(format: "%02x", $0) }.joined()
            print("[PC] S3 status=\(statusCode) size=\(data.count) first=\(firstBytes)")

            if let text = extractPDFText(data: data), !text.isEmpty {
                print("[PC] PDF extracted \(text.count) chars:\n---\n\(text)\n---")
                return text
            } else {
                print("[PC] PDF text extraction failed — may be image-based or encrypted")
            }
        }
        return nil
    }

    // Extract text column-by-column from a PDF so two-column chord charts parse correctly
    private func extractPDFText(data: Data) -> String? {
        guard let pdf = PDFDocument(data: data) else {
            print("[PC] PDFDocument init failed — data may not be a PDF (\(data.prefix(5).map { String(format:"%02x",$0) }.joined()))")
            return nil
        }
        var result = ""
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let midX = bounds.midX

            // Left column then right column — preserves section reading order
            let leftRect  = CGRect(x: bounds.minX, y: bounds.minY,
                                   width: midX - bounds.minX, height: bounds.height)
            let rightRect = CGRect(x: midX, y: bounds.minY,
                                   width: bounds.maxX - midX, height: bounds.height)
            let left  = page.selection(for: leftRect)?.string  ?? ""
            let right = page.selection(for: rightRect)?.string ?? ""

            if left.isEmpty && right.isEmpty {
                result += (page.string ?? "") + "\n"   // single-column fallback
            } else {
                if !left.isEmpty  { result += left  + "\n" }
                if !right.isEmpty { result += right + "\n" }
            }
        }
        return result.isEmpty ? nil : result
    }

    // Planning Center "t" field format: "MM:SS:mmm" (minutes:seconds:milliseconds)
    private func parsePCTime(_ t: String) -> Double? {
        let parts = t.split(separator: ":").map(String.init)
        guard parts.count == 3,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]),
              let ms = Double(parts[2]) else { return nil }
        return minutes * 60 + seconds + ms / 1000
    }
}
