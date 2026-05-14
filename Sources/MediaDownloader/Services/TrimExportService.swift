import AVFoundation
import Foundation

enum TrimExportError: LocalizedError {
    case invalidRange
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "Choose a longer trim range."
        case .processFailed(let message):
            return message.isEmpty ? "Trim export failed." : message
        }
    }
}

actor TrimExportService {
    private let fileManager = FileManager.default

    func exportTrim(
        sourceURL: URL,
        selection: TrimSelection,
        to outputURL: URL,
        onProgress: @Sendable @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard selection.end - selection.start >= 0.25 else {
            throw TrimExportError.invalidRange
        }

        try? fileManager.removeItem(at: outputURL)
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let arguments = Self.exportArguments(sourceURL: sourceURL, selection: selection, outputURL: outputURL)
        let duration = selection.end - selection.start

        try await runProcess(executable: "/usr/bin/env", arguments: arguments) { line in
            guard let elapsed = Self.parseTime(from: line), duration > 0 else { return }
            onProgress(min(elapsed / duration, 1.0))
        }
        return outputURL
    }

    nonisolated static func exportArguments(sourceURL: URL, selection: TrimSelection, outputURL: URL) -> [String] {
        let hasVideo = sourceHasVideoStream(at: sourceURL)
        var args = [
            "ffmpeg",
            "-y",
            "-i", sourceURL.path,
            "-ss", formatTime(selection.start),
            "-t", formatTime(selection.end - selection.start),
        ]

        if hasVideo {
            args += [
                "-map", "0:v:0",
                "-map", "0:a?",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "18",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", "192k",
                "-movflags", "+faststart",
            ]
        } else {
            args += [
                "-map", "0:a:0",
                "-c:a", "aac",
                "-b:a", "192k",
            ]
        }

        args.append(outputURL.path)
        return args
    }

    nonisolated private static func sourceHasVideoStream(at url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        return asset.tracks(withMediaType: .video).count > 0
    }

    func saveURL(for sourceURL: URL, selection: TrimSelection) -> URL {
        let folder = sourceURL.deletingLastPathComponent()
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let start = Int(selection.start.rounded())
        let end = Int(selection.end.rounded())
        return folder
            .appendingPathComponent("\(name) trim \(start)-\(end)s")
            .appendingPathExtension("mp4")
    }

    func temporaryURL(for sourceURL: URL) throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = support.appendingPathComponent("MediaDownloader/TrimExports", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }

    private nonisolated static func formatTime(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }

    // parses "time=HH:MM:SS.ss" from ffmpeg stderr progress lines
    private nonisolated static func parseTime(from line: String) -> Double? {
        guard let range = line.range(of: "time=") else { return nil }
        let timeString = String(line[range.upperBound...].prefix(11)) // "HH:MM:SS.ss"
        let parts = timeString.split(separator: ":").map { Double($0) ?? 0 }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        onStderrLine: @Sendable @escaping (String) -> Void = { _ in }
    ) async throws {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = DependencyChecker.processEnvironment
        process.standardOutput = stdout
        process.standardError = stderr

        // stream stderr line by line for progress parsing
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: "\r") {
                onStderrLine(line)
            }
        }

        let stderrBuffer = NSMutableString()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { process in
                    stderr.fileHandleForReading.readabilityHandler = nil
                    let tail = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    stderrBuffer.append(tail)
                    stdout.fileHandleForReading.closeFile()
                    stderr.fileHandleForReading.closeFile()

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TrimExportError.processFailed(stderrBuffer as String))
                    }
                }

                do {
                    try process.run()
                } catch {
                    stderr.fileHandleForReading.readabilityHandler = nil
                    stdout.fileHandleForReading.closeFile()
                    stderr.fileHandleForReading.closeFile()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
