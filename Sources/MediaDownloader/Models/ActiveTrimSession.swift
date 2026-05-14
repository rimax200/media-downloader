import Foundation

struct ActiveTrimSession: Identifiable, Equatable {
    let id = UUID()
    let item: DownloadItem

    var fileURL: URL {
        URL(fileURLWithPath: item.filePath)
    }
}
