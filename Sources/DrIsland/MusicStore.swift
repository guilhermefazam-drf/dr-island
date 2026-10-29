import AppKit
import Observation
import DrIslandCore

/// What is playing in Spotify or Apple Music, read and controlled through AppleScript.
/// Only apps that are already running are asked (asking would launch them), and the first ask makes macOS
/// request Automation permission.
@MainActor
@Observable
final class MusicStore {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?

    private var loop: Task<Void, Never>?
    private var artworkKey: String?
    private var systemTitle: String?
    private var systemArtwork: Data?
    private static let queue = DispatchQueue(label: "dr-island.applescript")

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func poll() async {
        guard Settings.showMusic else { nowPlaying = nil; return }
        if needsAccessibility, MediaKeys.isAllowed { needsAccessibility = false }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var candidates: [NowPlaying] = []
        for player in MusicPlayer.scriptable where running.contains(player.bundleID) {
            if let candidate = NowPlaying.parse(await Self.run(player.infoScript), player: player) { candidates.append(candidate) }
        }
        if let system = await systemNowPlaying(), !candidates.contains(where: { $0.title == system.title }) { candidates.append(system) }
        // Prefer what is actually playing when several sources have a track loaded.
        let found = candidates.first { $0.isPlaying } ?? candidates.first
        if found != nowPlaying { nowPlaying = found }
        await loadArtwork(found)
    }

    private func loadArtwork(_ track: NowPlaying?) async {
        let key = track.map { "\($0.player.rawValue)|\($0.title)|\($0.artworkURL?.absoluteString ?? "")" }
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = track?.artworkData.flatMap(NSImage.init(data:))
        guard let url = track?.artworkURL, let (data, _) = try? await URLSession.shared.data(from: url), artworkKey == key else { return }
        artwork = NSImage(data: data)
    }

    // MARK: System Now Playing (browsers and everything else)

    /// Since macOS 15.4 the system's Now Playing only answers Apple-signed processes, so the helper library runs
    /// inside /usr/bin/perl (see helper/nowplaying.c). Without the helper (a plain `swift run`) this source is just absent.
    private static var helperPaths: (library: String, script: String)? {
        guard let dir = Bundle.main.resourceURL else { return nil }
        let library = dir.appendingPathComponent("libnowplaying.dylib").path, script = dir.appendingPathComponent("nowplaying.pl").path
        let fm = FileManager.default
        return fm.fileExists(atPath: library) && fm.fileExists(atPath: script) ? (library, script) : nil
    }

    private static func runHelper(environment: [String: String]) async -> Data? {
        guard let helper = helperPaths else { return nil }
        return await Task.detached(priority: .utility) { () -> Data? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [helper.script, helper.library]
            process.environment = environment
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return data
        }.value
    }

    /// Reads the artwork only when the track changed, so the usual poll stays small.
    private func systemNowPlaying() async -> NowPlaying? {
        guard let track = NowPlaying.parseSystem(await Self.runHelper(environment: [:])) else { systemArtwork = nil; systemTitle = nil; return nil }
        if track.title != systemTitle {
            systemTitle = track.title
            systemArtwork = NowPlaying.parseSystem(await Self.runHelper(environment: ["NP_ART": "1"]))?.artworkData
        }
        return NowPlaying(player: .system, title: track.title, artist: track.artist, isPlaying: track.isPlaying, artworkURL: nil,
                          artworkData: systemArtwork, position: track.position, duration: track.duration, asOf: track.asOf,
                          sourceBundleID: track.sourceBundleID)
    }

    private enum Command {
        case toggle, next, previous
        var script: String { self == .toggle ? "playpause" : (self == .next ? "next track" : "previous track") }
        var key: MediaKey { self == .toggle ? .playPause : (self == .next ? .next : .previous) }
    }

    /// True after a control was used on a system source without the Accessibility permission, until it is granted.
    private(set) var needsAccessibility = false

    /// True after a control on Spotify or Music was refused by Automation permission, until a command works again.
    private(set) var needsAutomation = false

    /// Asks again for whichever permission the last control was missing (the warning in the island calls this).
    func requestPermission() {
        if needsAutomation { MediaKeys.openSettings(pane: "Privacy_Automation") } else { MediaKeys.requestAccess() }
    }

    func playPause() { send(.toggle) }
    func next() { send(.next) }
    func previous() { send(.previous) }

    private func send(_ command: Command) {
        guard let player = nowPlaying?.player else { return }
        if player == .system {
            // Browsers and other apps have no script: the media keys reach them, with the Accessibility permission.
            guard MediaKeys.isAllowed else {
                needsAccessibility = true
                MediaKeys.requestAccess()
                return
            }
            needsAccessibility = false
            MediaKeys.send(command.key)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await poll()
            }
            return
        }
        Task {
            let outcome = await Self.runChecked(player.commandScript(command.script))
            // -1743: the user has not allowed (or has denied) controlling this app; macOS does not prompt twice, so open Settings.
            if outcome.errorNumber == -1743 {
                needsAutomation = true
                MediaKeys.openSettings(pane: "Privacy_Automation")
            } else if outcome.errorNumber == nil {
                needsAutomation = false
            }
            await poll()
        }
    }

    private static func runChecked(_ source: String) async -> (result: String?, errorNumber: Int?) {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                continuation.resume(returning: (result?.stringValue, error?[NSAppleScript.errorNumber] as? Int))
            }
        }
    }

    /// NSAppleScript is not thread-safe, so every script goes through one serial queue (never the main thread).
    private static func run(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                continuation.resume(returning: error == nil ? result?.stringValue : nil)
            }
        }
    }
}
