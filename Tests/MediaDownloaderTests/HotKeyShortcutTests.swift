@testable import MediaDownloader
import AppKit
import XCTest

final class HotKeyShortcutTests: XCTestCase {
    func testDefaultShortcutDisplayText() {
        XCTAssertEqual(HotKeyAction.copy.defaultShortcut.displayText, "↩")
        XCTAssertEqual(HotKeyAction.openTrim.defaultShortcut.displayText, "⌘ ↩")
        XCTAssertEqual(HotKeyAction.activateApp.defaultShortcut.displayText, "⇧ ⌘ 6")
    }

    func testPreferenceStorePersistsShortcut() {
        let suiteName = "HotKeyShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let shortcut = HotKeyShortcut(keyCode: 8, modifiers: [.command, .option])

        store.setHotKeyShortcut(shortcut, for: .copy)

        XCTAssertEqual(store.hotKeyShortcut(for: .copy), shortcut)
        XCTAssertEqual(store.hotKeyShortcut(for: .openTrim), HotKeyAction.openTrim.defaultShortcut)
    }

    func testShortcutMatchingIgnoresNonShortcutModifierFlags() {
        let shortcut = HotKeyShortcut(keyCode: 36, modifiers: [.command])
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .capsLock],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        XCTAssertTrue(shortcut.matches(event))
    }
}
