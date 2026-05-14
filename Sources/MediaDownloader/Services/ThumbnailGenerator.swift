import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum ThumbnailError: LocalizedError {
    case encodingFailed

    var errorDescription: String? { "Failed to encode thumbnail image." }
}

actor ThumbnailGenerator {
    private let fileManager = FileManager.default

    func thumbnailPath(for videoURL: URL) async throws -> URL {
        let directory = try thumbnailDirectory()
        let outputURL = directory.appendingPathComponent(videoURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("jpg")

        if fileManager.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 160)

        let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
        let data = NSMutableData()

        guard
            let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw ThumbnailError.encodingFailed
        }

        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.78
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailError.encodingFailed
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func thumbnailDirectory() throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = support.appendingPathComponent("MediaDownloader/Thumbnails", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
