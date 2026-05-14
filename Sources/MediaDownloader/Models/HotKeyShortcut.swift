import AppKit

enum HotKeyAction: String, CaseIterable {
    case copy
    case openTrim
    case activateApp

    var title: String {
        switch self {
        case .copy:
            return "Copy:"
        case .openTrim:
            return "Open trim mode:"
        case .activateApp:
            return "Activate app:"
        }
    }

    var defaultShortcut: HotKeyShortcut {
        switch self {
        case .copy:
            return HotKeyShortcut(keyCode: 36, modifiers: [])
        case .openTrim:
            return HotKeyShortcut(keyCode: 36, modifiers: [.command])
        case .activateApp:
            return HotKeyShortcut(keyCode: 22, modifiers: [.command, .shift])
        }
    }
}

struct HotKeyShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifierRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        modifierRawValue = modifiers.shortcutModifiers.rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue).shortcutModifiers
    }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode && event.modifierFlags.shortcutModifiers == modifiers
    }

    var displayText: String {
        let key = Self.keyDisplayName(for: keyCode)
        let prefix = [
            modifiers.contains(.control) ? "⌃" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.command) ? "⌘" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return prefix.isEmpty ? key : "\(prefix) \(key)"
    }

    private static func keyDisplayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36, 76:
            return "↩"
        case 49:
            return "Space"
        case 48:
            return "Tab"
        case 51:
            return "Delete"
        case 53:
            return "Esc"
        case 0:
            return "A"
        case 1:
            return "S"
        case 2:
            return "D"
        case 3:
            return "F"
        case 4:
            return "H"
        case 5:
            return "G"
        case 6:
            return "Z"
        case 7:
            return "X"
        case 8:
            return "C"
        case 9:
            return "V"
        case 11:
            return "B"
        case 12:
            return "Q"
        case 13:
            return "W"
        case 14:
            return "E"
        case 15:
            return "R"
        case 16:
            return "Y"
        case 17:
            return "T"
        case 18:
            return "1"
        case 19:
            return "2"
        case 20:
            return "3"
        case 21:
            return "4"
        case 22:
            return "6"
        case 23:
            return "5"
        case 25:
            return "9"
        case 26:
            return "7"
        case 28:
            return "8"
        case 29:
            return "0"
        case 31:
            return "O"
        case 32:
            return "U"
        case 34:
            return "I"
        case 35:
            return "P"
        case 37:
            return "L"
        case 38:
            return "J"
        case 40:
            return "K"
        case 45:
            return "N"
        case 46:
            return "M"
        default:
            return "Key \(keyCode)"
        }
    }
}

extension NSEvent.ModifierFlags {
    var shortcutModifiers: NSEvent.ModifierFlags {
        intersection([.command, .shift, .option, .control])
    }
}

extension Notification.Name {
    static let mediaDownloaderHotKeysDidChange = Notification.Name("MediaDownloaderHotKeysDidChange")
}
