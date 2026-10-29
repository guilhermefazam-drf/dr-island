import AppKit
import Foundation

/// A plain-text error log in ~/Library/Logs/DrIsland, so a freeze or a failing source leaves something to read afterwards.
enum ErrorLog {
    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DrIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("errors.log")
    }()

    private static let queue = DispatchQueue(label: "dr-island.errorlog")
    private static let maxBytes = 512 * 1024
    /// A value type, so `record` can run on any thread (same text as ISO8601DateFormatter with the local time zone).
    private static let stamp = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: .current)

    /// Appends one line, `source` being the part of the app it came from ("Jira", "Interface"…).
    static func record(_ source: String, _ message: String) {
        let line = "\(Date.now.formatted(stamp)) [\(source)] \(message.replacingOccurrences(of: "\n", with: " ⏎ "))\n"
        queue.async { append(line) }
    }

    static func record(_ source: String, error: Error) {
        record(source, "\(type(of: error)): \(error)")
    }

    /// The last `count` lines, newest last.
    static func tail(_ count: Int = 300) -> String {
        queue.sync {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
            return text.split(separator: "\n", omittingEmptySubsequences: true).suffix(count).joined(separator: "\n")
        }
    }

    static func clear() {
        queue.sync { try? Data().write(to: fileURL) }
    }

    private static func append(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? Int, size > maxBytes,
           let old = try? String(contentsOf: fileURL, encoding: .utf8) {
            // Keep the newer half instead of growing forever.
            let kept = old.split(separator: "\n", omittingEmptySubsequences: true).suffix(1500).joined(separator: "\n") + "\n"
            try? kept.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    // MARK: Crashes and freezes

    /// Logs uncaught Objective-C exceptions, fatal signals and main-thread freezes. Call once at launch.
    static func install() {
        record("App", "Arranque (versão \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"), pid \(ProcessInfo.processInfo.processIdentifier))")
        NSSetUncaughtExceptionHandler { exception in
            ErrorLog.record("Exceção", "\(exception.name.rawValue): \(exception.reason ?? "") | \(exception.callStackSymbols.prefix(12).joined(separator: " ← "))")
            ErrorLog.queue.sync {}   // let the line reach the disk before the process dies
        }
        for sig in [SIGSEGV, SIGABRT, SIGILL, SIGBUS, SIGTRAP] {
            signal(sig) { number in
                // Async-signal-safe enough for a last words: one write(2) on a descriptor opened here.
                let text = "\(Date()) [Crash] sinal \(number)\n"
                let fd = open(ErrorLog.fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
                if fd >= 0 { _ = text.withCString { write(fd, $0, strlen($0)) }; close(fd) }
                signal(number, SIG_DFL)
                raise(number)
            }
        }
        startWatchdog()
    }

    /// A background thread pings the main thread every second; no answer for a few seconds is a freeze worth a line.
    private static func startWatchdog() {
        let state = WatchdogState()
        let thread = Thread {
            while true {
                Thread.sleep(forTimeInterval: 1)
                if state.beginPing() == 0 { DispatchQueue.main.async { state.pong() } }
            }
        }
        thread.name = "dr-island.watchdog"
        thread.qualityOfService = .utility
        thread.start()
    }

    private final class WatchdogState: @unchecked Sendable {
        private let lock = NSLock()
        private var pingedAt: Date?
        private var frozenSince: Date?

        /// Returns how many seconds the previous ping has been waiting (0 when none).
        func beginPing() -> TimeInterval {
            lock.lock(); defer { lock.unlock() }
            if let at = pingedAt {
                let waited = Date().timeIntervalSince(at)
                if waited >= 4, frozenSince == nil {
                    frozenSince = at
                    ErrorLog.record("Interface", "A interface deixou de responder (\(Int(waited)) s sem resposta da thread principal)")
                    ErrorLog.sampleMainThread()
                }
                return waited
            }
            pingedAt = Date()
            return 0
        }

        func pong() {
            lock.lock(); defer { lock.unlock() }
            if let since = frozenSince {
                ErrorLog.record("Interface", "A interface voltou a responder após \(Int(Date().timeIntervalSince(since))) s")
                frozenSince = nil
            }
            pingedAt = nil
        }
    }

    /// While frozen, asks macOS `sample` where the main thread is stuck and keeps the answer next to the log.
    static func sampleMainThread() {
        let name = "freeze-\(Int(Date().timeIntervalSince1970)).txt"
        let file = fileURL.deletingLastPathComponent().appendingPathComponent(name)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        process.arguments = ["\(ProcessInfo.processInfo.processIdentifier)", "2", "-file", file.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        record("Interface", "Amostra da thread principal em \(name)")
        // Only the last few samples are worth keeping.
        let dir = file.deletingLastPathComponent()
        let old = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasPrefix("freeze-") }.sorted().dropLast(5)
        for f in old { try? FileManager.default.removeItem(at: dir.appendingPathComponent(f)) }
    }

    // MARK: Restart

    /// Quits and opens the app again, the way out of a stuck island.
    @MainActor static func relaunch() {
        record("App", "Reinício pedido pelo utilizador")
        let bundle = Bundle.main.bundlePath
        let command = bundle.hasSuffix(".app")
            ? "sleep 0.6; /usr/bin/open -n \"\(bundle)\""
            : "sleep 0.6; \"\(Bundle.main.executablePath ?? CommandLine.arguments[0])\" >/dev/null 2>&1 &"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        try? process.run()
        queue.sync {}
        exit(0)   // not terminate(): a frozen main run loop or a pending modal must not be able to block the restart
    }
}
