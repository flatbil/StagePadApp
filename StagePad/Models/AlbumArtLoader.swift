import UIKit

/// Fetches and disk-caches per-song album art from Apple's iTunes Search API
/// — a hidden bonus, never something the live-show experience depends on.
/// Every failure mode (no network, no match, a slow church WiFi) just means
/// no art for that song; the color-tint background from Song Colors already
/// covers that case seamlessly, so this is purely additive.
///
/// Deliberately best-effort, not authoritative: worship song titles are
/// often generic and covered by many different artists ("Way Maker,"
/// "Goodness of God"), so the top iTunes match isn't guaranteed to be the
/// right recording — this is art as ambiance, not a guaranteed-correct
/// lookup, which is exactly why it stays silent/automatic rather than
/// something surfaced as a setting to get right.
enum AlbumArtLoader {
    private static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AlbumArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cacheFile(for songName: String) -> URL {
        // Song names can contain characters that aren't safe filenames —
        // hash instead of sanitizing so nothing is ever silently dropped or
        // collides across two differently-punctuated titles.
        let hash = String(UInt(bitPattern: songName.hashValue), radix: 16)
        return cacheDirectory.appendingPathComponent("\(hash).jpg")
    }

    /// Cached image if one exists on disk already — no network touched at
    /// all, so this is safe to call synchronously right when a song list
    /// loads, before ever considering a fetch.
    static func cachedImage(for songName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: cacheFile(for: songName)) else { return nil }
        return UIImage(data: data)
    }

    /// Looks up and caches art for a song not already cached. Silent nil on
    /// any failure whatsoever — offline, timeout, no match, bad response —
    /// deliberately no error surfaced anywhere; there is nothing a user or
    /// this app could usefully do about a missing bonus background image.
    static func fetch(for songName: String) async -> UIImage? {
        guard let query = songName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1")
        else { return nil }

        var request = URLRequest(url: searchURL)
        request.timeoutInterval = 6   // never let a dead network hold anything up

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]],
              let first = results.first,
              let thumbURLString = first["artworkUrl100"] as? String
        else { return nil }

        // iTunes serves a 100x100 thumbnail by default — swapping that
        // segment for a larger size is a well-known, stable trick against
        // their artwork CDN, not an official documented parameter.
        let fullURLString = thumbURLString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        guard let artworkURL = URL(string: fullURLString),
              let (imageData, _) = try? await URLSession.shared.data(from: artworkURL),
              let image = UIImage(data: imageData)
        else { return nil }

        try? imageData.write(to: cacheFile(for: songName))
        return image
    }
}
