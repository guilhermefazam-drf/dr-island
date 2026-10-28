import Foundation

/// An app the user pinned to the island, optionally opened on a folder (e.g. a project).
public struct DevShortcut: Codable, Equatable, Identifiable, Sendable {
    public var id: String { appPath }
    public let appPath: String
    public var folder: String?

    public init(appPath: String, folder: String? = nil) {
        self.appPath = appPath
        self.folder = folder
    }

    /// "Visual Studio Code" from ".../Visual Studio Code.app".
    public var name: String {
        URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
    }
}

public enum ShortcutList {
    public static func decode(_ json: String) -> [DevShortcut] {
        guard let data = json.data(using: .utf8), let list = try? JSONDecoder().decode([DevShortcut].self, from: data) else { return [] }
        return list
    }

    public static func encode(_ list: [DevShortcut]) -> String {
        (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// The same app is never added twice.
    public static func adding(_ shortcut: DevShortcut, to list: [DevShortcut]) -> [DevShortcut] {
        list.contains { $0.id == shortcut.id } ? list : list + [shortcut]
    }

    public static func removing(id: String, from list: [DevShortcut]) -> [DevShortcut] {
        list.filter { $0.id != id }
    }

    public static func setting(folder: String?, for id: String, in list: [DevShortcut]) -> [DevShortcut] {
        list.map { $0.id == id ? DevShortcut(appPath: $0.appPath, folder: folder?.isEmpty == false ? folder : nil) : $0 }
    }

    /// Common development apps offered as one-click suggestions when installed.
    public static let suggestions: [String] = [
        "/Applications/Visual Studio Code.app", "/Applications/Cursor.app", "/Applications/Claude.app",
        "/Applications/Xcode.app", "/Applications/IntelliJ IDEA.app", "/Applications/IntelliJ IDEA CE.app",
        "/Applications/PhpStorm.app", "/Applications/WebStorm.app", "/Applications/PyCharm.app",
        "/Applications/Android Studio.app", "/Applications/Warp.app", "/Applications/iTerm.app",
        "/System/Applications/Utilities/Terminal.app", "/Applications/Docker.app", "/Applications/Postman.app",
        "/Applications/TablePlus.app", "/Applications/Sublime Text.app", "/Applications/GitHub Desktop.app",
    ]

    /// Suggestions that are installed (per `exists`) and not already pinned.
    public static func availableSuggestions(pinned: [DevShortcut], exists: (String) -> Bool) -> [String] {
        suggestions.filter { path in !pinned.contains { $0.appPath == path } && exists(path) }
    }
}
