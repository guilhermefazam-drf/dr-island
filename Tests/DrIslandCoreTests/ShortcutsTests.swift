import Testing
@testable import DrIslandCore

@Suite struct ShortcutsTests {
    let code = DevShortcut(appPath: "/Applications/Visual Studio Code.app")

    @Test func nameComesFromTheApp() {
        #expect(code.name == "Visual Studio Code")
    }

    @Test func roundTripsAndBadJSONIsEmpty() {
        let list = [code, DevShortcut(appPath: "/Applications/Xcode.app", folder: "/tmp/p")]
        #expect(ShortcutList.decode(ShortcutList.encode(list)) == list)
        #expect(ShortcutList.decode("").isEmpty)
        #expect(ShortcutList.decode("not json").isEmpty)
    }

    @Test func addingIgnoresDuplicates() {
        #expect(ShortcutList.adding(code, to: [code]).count == 1)
        #expect(ShortcutList.adding(DevShortcut(appPath: "/x.app"), to: [code]).count == 2)
    }

    @Test func removeAndSetFolder() {
        #expect(ShortcutList.removing(id: code.id, from: [code]).isEmpty)
        let withFolder = ShortcutList.setting(folder: "/p", for: code.id, in: [code])
        #expect(withFolder.first?.folder == "/p")
        #expect(ShortcutList.setting(folder: "", for: code.id, in: withFolder).first?.folder == nil)
    }

    @Test func suggestionsSkipMissingAndPinned() {
        let installed: Set<String> = ["/Applications/Cursor.app", code.appPath]
        let result = ShortcutList.availableSuggestions(pinned: [code], exists: installed.contains)
        #expect(result == ["/Applications/Cursor.app"])
    }
}
