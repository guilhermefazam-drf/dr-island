import Foundation

/// A music app the island can read and control through AppleScript.
public enum MusicPlayer: String, CaseIterable, Sendable {
    case spotify, appleMusic
    /// Anything else playing on the Mac (a browser tab, a podcast app…), read from the system's Now Playing.
    case system

    /// The players that can be asked directly through AppleScript.
    public static let scriptable: [MusicPlayer] = [.spotify, .appleMusic]

    public var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        case .system: return ""
        }
    }
    public var name: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Música"
        case .system: return "Em reprodução"
        }
    }

    /// Prints "title⇥artist⇥state⇥position⇥duration[⇥artworkURL]" (seconds; the artwork only exists in Spotify's dictionary),
    /// or nothing when stopped.
    public var infoScript: String {
        guard self != .system else { return "" }
        let duration = self == .spotify ? "(((duration of current track) / 1000) as integer) as text" : "((duration of current track) as integer) as text"
        let art = self == .spotify ? #" & tab & (artwork url of current track)"# : ""
        return """
        tell application id "\(bundleID)"
            if player state is not stopped then return (name of current track) & tab & (artist of current track) & tab & (player state as text) & tab & ((player position as integer) as text) & tab & (\(duration))\(art)
        end tell
        """
    }

    public func commandScript(_ command: String) -> String { self == .system ? "" : #"tell application id "\#(bundleID)" to \#(command)"# }
}

public struct NowPlaying: Equatable, Sendable {
    public let player: MusicPlayer
    public let title: String
    public let artist: String
    public let isPlaying: Bool
    public let artworkURL: URL?
    /// Image bytes, when the source hands them over directly instead of a URL (system Now Playing).
    public let artworkData: Data?
    /// Playback position at `asOf` and the track length, in seconds (nil when the source does not say).
    public let position: TimeInterval?
    public let duration: TimeInterval?
    public let asOf: Date
    /// The app playing, when known (used to name and open it).
    public let sourceBundleID: String?

    public init(player: MusicPlayer, title: String, artist: String, isPlaying: Bool, artworkURL: URL?, artworkData: Data? = nil,
                position: TimeInterval? = nil, duration: TimeInterval? = nil, asOf: Date = Date(), sourceBundleID: String? = nil) {
        self.player = player; self.title = title; self.artist = artist; self.isPlaying = isPlaying
        self.artworkURL = artworkURL; self.artworkData = artworkData
        self.position = position; self.duration = duration; self.asOf = asOf; self.sourceBundleID = sourceBundleID ?? (player == .system ? nil : player.bundleID)
    }

    /// The position right now: it keeps advancing between polls while playing.
    public func currentPosition(now: Date = Date()) -> TimeInterval? {
        guard let position else { return nil }
        let moved = isPlaying ? max(0, now.timeIntervalSince(asOf)) : 0
        let value = position + moved
        return duration.map { min(value, $0) } ?? value
    }

    /// Parses the JSON line printed by the system Now Playing helper; nil when nothing is loaded.
    public static func parseSystem(_ output: Data?, now: Date = Date()) -> NowPlaying? {
        guard let output, let json = (try? JSONSerialization.jsonObject(with: output)) as? [String: Any],
              let title = json["title"] as? String, !title.isEmpty else { return nil }
        let playing = (json["playing"] as? Int).map { $0 == 1 } ?? ((json["rate"] as? Double ?? 0) > 0)
        // `elapsed` was true at `timestamp`; bring it up to now when playing.
        let elapsed = json["elapsed"] as? Double
        let length = (json["duration"] as? Double).flatMap { $0 > 0 ? $0 : nil }
        let position = elapsed.map { e in
            let stamp = (json["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? now
            return e + (playing ? max(0, now.timeIntervalSince(stamp)) : 0)
        }
        return NowPlaying(player: .system, title: title, artist: json["artist"] as? String ?? "", isPlaying: playing,
                          artworkURL: nil, artworkData: (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) },
                          position: length == nil ? nil : position, duration: length, asOf: now, sourceBundleID: json["bundle"] as? String)
    }

    /// Parses the output of `MusicPlayer.infoScript`; nil when nothing is loaded.
    public static func parse(_ output: String?, player: MusicPlayer) -> NowPlaying? {
        guard let output else { return nil }
        let parts = output.trimmingCharacters(in: .newlines).components(separatedBy: "\t")
        guard parts.count >= 3, !parts[0].isEmpty else { return nil }
        // Only https artwork is fetched: the URL comes from another app.
        let art = parts.count > 5 ? URL(string: parts[5]).flatMap { $0.scheme == "https" ? $0 : nil } : nil
        let length = parts.count > 4 ? Double(parts[4]).flatMap { $0 > 0 ? $0 : nil } : nil
        let position = parts.count > 3 ? Double(parts[3]) : nil
        return NowPlaying(player: player, title: parts[0], artist: parts[1], isPlaying: parts[2] == "playing", artworkURL: art,
                          position: length == nil ? nil : position, duration: length)
    }
}
