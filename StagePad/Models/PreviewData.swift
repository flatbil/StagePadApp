import Foundation

extension Song {
    static let previewSongs: [Song] = [
        Song(
            name: "How Great Thou Art",
            position: 0,
            sections: [
                Section(name: "Intro",    position: 0,   cueIndex: 1),
                Section(name: "Verse 1",  position: 8,   cueIndex: 2),
                Section(name: "Verse 2",  position: 16,  cueIndex: 3),
                Section(name: "Chorus",   position: 24,  cueIndex: 4),
                Section(name: "Verse 3",  position: 32,  cueIndex: 5),
                Section(name: "Chorus",   position: 40,  cueIndex: 6),
                Section(name: "Outro",    position: 48,  cueIndex: 7),
            ]
        ),
        Song(
            name: "Build My Life",
            position: 56,
            sections: [
                Section(name: "Verse 1",    position: 56,  cueIndex: 8),
                Section(name: "Pre-Chorus", position: 64,  cueIndex: 9),
                Section(name: "Chorus",     position: 72,  cueIndex: 10),
                Section(name: "Verse 2",    position: 80,  cueIndex: 11),
                Section(name: "Pre-Chorus", position: 88,  cueIndex: 12),
                Section(name: "Chorus",     position: 96,  cueIndex: 13),
                Section(name: "Bridge",     position: 104, cueIndex: 14),
                Section(name: "Chorus",     position: 112, cueIndex: 15),
            ]
        ),
        Song(
            name: "Amazing Grace",
            position: 120,
            sections: [
                Section(name: "Intro",   position: 120, cueIndex: 16),
                Section(name: "Verse 1", position: 128, cueIndex: 17),
                Section(name: "Verse 2", position: 136, cueIndex: 18),
                Section(name: "Chorus",  position: 144, cueIndex: 19),
                Section(name: "Verse 3", position: 152, cueIndex: 20),
                Section(name: "Outro",   position: 160, cueIndex: 21),
            ]
        ),
        Song(
            name: "Oceans",
            position: 168,
            sections: [
                Section(name: "Intro",      position: 168, cueIndex: 22),
                Section(name: "Verse 1",    position: 176, cueIndex: 23),
                Section(name: "Chorus",     position: 184, cueIndex: 24),
                Section(name: "Verse 2",    position: 192, cueIndex: 25),
                Section(name: "Chorus",     position: 200, cueIndex: 26),
                Section(name: "Bridge",     position: 208, cueIndex: 27),
                Section(name: "Tag",        position: 224, cueIndex: 28),
                Section(name: "Outro",      position: 232, cueIndex: 29),
            ]
        ),
        Song(
            name: "Great Are You Lord",
            position: 240,
            sections: [
                Section(name: "Intro",   position: 240, cueIndex: 30),
                Section(name: "Verse 1", position: 248, cueIndex: 31),
                Section(name: "Chorus",  position: 256, cueIndex: 32),
                Section(name: "Verse 2", position: 264, cueIndex: 33),
                Section(name: "Chorus",  position: 272, cueIndex: 34),
                Section(name: "Bridge",  position: 280, cueIndex: 35),
                Section(name: "Chorus",  position: 296, cueIndex: 36),
                Section(name: "Outro",   position: 304, cueIndex: 37),
            ]
        ),
    ]
}
