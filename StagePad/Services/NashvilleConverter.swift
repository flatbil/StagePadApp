import Foundation

enum NashvilleConverter {
    private static let chromatic = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let enharmonic: [String: String] = [
        "Db": "C#", "Eb": "D#", "Fb": "E", "Gb": "F#", "Ab": "G#", "Bb": "A#", "Cb": "B"
    ]
    // Intervals of the major scale from root
    private static let majorIntervals = [0, 2, 4, 5, 7, 9, 11]

    static func convert(chord: String, inKey key: String) -> String {
        let (root, quality) = parseChord(chord)
        guard !root.isEmpty else { return chord }
        guard let keyIdx = chromaticIndex(for: key),
              let rootIdx = chromaticIndex(for: root) else { return chord }

        let distance = (rootIdx - keyIdx + 12) % 12

        if let degree = majorIntervals.firstIndex(of: distance) {
            return "\(degree + 1)\(quality)"
        }
        // Chromatic — prefix with b
        let flatDistance = (distance + 1) % 12
        if let degree = majorIntervals.firstIndex(of: flatDistance) {
            return "b\(degree + 1)\(quality)"
        }
        return chord
    }

    // Convert a line of chords (space-separated) to Nashville numbers
    static func convertLine(_ line: String, inKey key: String) -> String {
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        return tokens.map { convert(chord: $0, inKey: key) }.joined(separator: " ")
    }

    // Parse sections from a Planning Center chord chart text
    // Returns [(sectionName, chords)] where chords is the Nashville-converted chord line per section
    static func parseSections(from chartText: String, key: String) -> [(name: String, nashvilleChords: String)] {
        var results: [(name: String, nashvilleChords: String)] = []
        var currentSection = ""
        var currentChords: [String] = []

        let lines = chartText.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Detect section headers (lines with no chords, often title-cased)
            if looksLikeSectionHeader(trimmed) {
                if !currentSection.isEmpty {
                    results.append((currentSection, currentChords.joined(separator: " | ")))
                }
                currentSection = trimmed
                currentChords = []
            } else if looksLikeChordLine(trimmed) {
                let converted = convertLine(trimmed, inKey: key)
                if !converted.isEmpty { currentChords.append(converted) }
            }
        }
        if !currentSection.isEmpty {
            results.append((currentSection, currentChords.joined(separator: " | ")))
        }
        return results
    }

    private static func looksLikeSectionHeader(_ line: String) -> Bool {
        let headers = ["intro", "verse", "chorus", "pre-chorus", "pre chorus", "bridge",
                       "tag", "outro", "ending", "vamp", "interlude", "refrain",
                       "breakdown", "turnaround", "post-chorus", "post chorus"]
        let lower = line.lowercased()
        return headers.contains(where: { lower.hasPrefix($0) })
    }

    private static func looksLikeChordLine(_ line: String) -> Bool {
        // A chord line has mostly chord tokens (starts with A-G optionally followed by #/b)
        let tokens = line.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return false }
        let chordCount = tokens.filter { isChord($0) }.count
        return Double(chordCount) / Double(tokens.count) >= 0.5
    }

    private static func isChord(_ token: String) -> Bool {
        guard let first = token.first, "ABCDEFG".contains(first) else { return false }
        return chromaticIndex(for: String(parseChord(token).0)) != nil
    }

    private static func parseChord(_ chord: String) -> (root: String, quality: String) {
        var i = chord.startIndex
        guard i < chord.endIndex else { return ("", "") }
        var root = String(chord[i])
        chord.formIndex(after: &i)
        if i < chord.endIndex, chord[i] == "#" || chord[i] == "b" {
            root += String(chord[i])
            chord.formIndex(after: &i)
        }
        return (root, String(chord[i...]))
    }

    private static func chromaticIndex(for note: String) -> Int? {
        chromatic.firstIndex(of: enharmonic[note] ?? note)
    }
}
