import Foundation

final class HistoryStore {
    private let fileManager: FileManager
    private let historyURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = support.appendingPathComponent("MediaDownloader", isDirectory: true)
        historyURL = directory.appendingPathComponent("history.json")
    }

    func load() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: historyURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let items = try? decoder.decode([DownloadItem].self, from: data) else {
            NSLog("HistoryStore: history file is corrupted, starting fresh")
            return []
        }
        return items
    }

    @discardableResult
    func save(_ history: [DownloadItem]) -> Bool {
        do {
            try fileManager.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(history)
            try data.write(to: historyURL, options: .atomic)
            return true
        } catch {
            NSLog("HistoryStore: failed to save — \(error.localizedDescription)")
            return false
        }
    }
}
