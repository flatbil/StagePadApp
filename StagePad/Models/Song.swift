import SwiftUI

struct BridgeTrack: Identifiable {
    let id: Int      // Ableton track index — stable for the life of the session
    let name: String
    var isMuted: Bool
}

struct Section: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let position: Double
    let cueIndex: Int

    init(name: String, position: Double, cueIndex: Int) {
        self.name = name
        self.position = position
        self.cueIndex = cueIndex
    }

    enum CodingKeys: String, CodingKey {
        case name, position
        case cueIndex = "cue_index"
    }
}

struct Song: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let position: Double
    let sections: [Section]

    init(name: String, position: Double, sections: [Section]) {
        self.name = name
        self.position = position
        self.sections = sections
    }

    enum CodingKeys: String, CodingKey {
        case name, position, sections
    }
}

// Per-song colors for the song selector pills (cycling)
extension Song {
    static let palette: [Color] = [
        Color(red: 0.13, green: 0.37, blue: 0.64),
        Color(red: 0.50, green: 0.18, blue: 0.56),
        Color(red: 0.13, green: 0.55, blue: 0.38),
        Color(red: 0.72, green: 0.33, blue: 0.12),
        Color(red: 0.60, green: 0.15, blue: 0.25),
        Color(red: 0.20, green: 0.47, blue: 0.45),
        Color(red: 0.45, green: 0.40, blue: 0.12),
        Color(red: 0.25, green: 0.25, blue: 0.55),
    ]

    static let songIcons: [String] = [
        "music.note", "guitars", "music.mic", "waveform",
        "music.quarternote.3", "metronome", "pianokeys", "music.note.list",
    ]

    static func songColor(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func songIcon(for index: Int) -> String {
        songIcons[index % songIcons.count]
    }
}

// Per-section-type color and icon (consistent across all songs)
struct SectionStyle {
    let color: Color
    let icon: String
}

extension SectionStyle {
    static func style(for sectionName: String) -> SectionStyle {
        let name = sectionName.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch true {
        case name == "start" || name == "intro":
            return SectionStyle(color: Color(red: 0.05, green: 0.55, blue: 0.55), icon: "play.circle.fill")
        case name.contains("prechorus") || name.contains("pre"):
            return SectionStyle(color: Color(red: 0.75, green: 0.55, blue: 0.05), icon: "chevron.up.2")
        case name.contains("chorus"):
            return SectionStyle(color: Color(red: 0.80, green: 0.40, blue: 0.05), icon: "star.fill")
        case name.contains("verse"):
            return SectionStyle(color: Color(red: 0.15, green: 0.40, blue: 0.75), icon: "text.alignleft")
        case name.contains("bridge"):
            return SectionStyle(color: Color(red: 0.45, green: 0.15, blue: 0.70), icon: "arrow.triangle.branch")
        case name.contains("tag"):
            return SectionStyle(color: Color(red: 0.75, green: 0.15, blue: 0.55), icon: "repeat")
        case name.contains("outro") || name.contains("ending") || name.contains("end"):
            return SectionStyle(color: Color(red: 0.65, green: 0.10, blue: 0.10), icon: "stop.circle.fill")
        case name.contains("solo") || name.contains("instrumental") || name.contains("interlude"):
            return SectionStyle(color: Color(red: 0.10, green: 0.50, blue: 0.25), icon: "guitars.fill")
        case name.contains("vamp"):
            return SectionStyle(color: Color(red: 0.65, green: 0.30, blue: 0.05), icon: "waveform")
        case name.contains("break"):
            return SectionStyle(color: Color(red: 0.30, green: 0.30, blue: 0.30), icon: "pause.circle.fill")
        default:
            return SectionStyle(color: Color(red: 0.30, green: 0.30, blue: 0.40), icon: "music.quarternote.3")
        }
    }
}
