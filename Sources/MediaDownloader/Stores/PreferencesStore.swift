import Foundation

enum VideoQuality: String, CaseIterable, Codable {
    case best = "best"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    case audioOnly = "audio"

    var displayName: String {
        switch self {
        case .best: return "Best Available"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        case .audioOnly: return "Audio Only"
        }
    }

    var ytdlpFormatArg: String {
        switch self {
        case .best:
            return "bestvideo+bestaudio/best"
        case .p1080:
            return "bestvideo[height<=1080]+bestaudio/best[height<=1080]/bestvideo+bestaudio/best"
        case .p720:
            return "bestvideo[height<=720]+bestaudio/best[height<=720]/bestvideo+bestaudio/best"
        case .p480:
            return "bestvideo[height<=480]+bestaudio/best[height<=480]/bestvideo+bestaudio/best"
        case .audioOnly:
            return "bestaudio/best"
        }
    }
}

final class PreferencesStore {
    private let downloadFolderKey = "downloadFolderPath"
    private let hotKeyPrefix = "hotKeyShortcut."
    private let defaultQualityKey = "defaultVideoQuality"
    private let alwaysUseDefaultQualityKey = "alwaysUseDefaultQuality"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var defaultQuality: VideoQuality {
        get {
            guard let raw = defaults.string(forKey: defaultQualityKey),
                  let quality = VideoQuality(rawValue: raw) else {
                return .best
            }
            return quality
        }
        set {
            defaults.set(newValue.rawValue, forKey: defaultQualityKey)
        }
    }

    var alwaysUseDefaultQuality: Bool {
        get { defaults.bool(forKey: alwaysUseDefaultQualityKey) }
        set { defaults.set(newValue, forKey: alwaysUseDefaultQualityKey) }
    }

    var downloadFolder: URL {
        get {
            if let path = defaults.string(forKey: downloadFolderKey), !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }

            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            return downloads
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: downloadFolderKey)
        }
    }

    func hotKeyShortcut(for action: HotKeyAction) -> HotKeyShortcut {
        let key = hotKeyKey(for: action)
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(HotKeyShortcut.self, from: data) else {
            return action.defaultShortcut
        }

        return shortcut
    }

    func setHotKeyShortcut(_ shortcut: HotKeyShortcut, for action: HotKeyAction) {
        let key = hotKeyKey(for: action)
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .mediaDownloaderHotKeysDidChange, object: action)
    }

    private func hotKeyKey(for action: HotKeyAction) -> String {
        hotKeyPrefix + action.rawValue
    }
}
