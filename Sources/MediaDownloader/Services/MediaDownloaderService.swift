import Foundation

enum MediaDownloaderError: LocalizedError {
    case missingTool(String)
    case processFailed(String)
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool):
            return "\(tool) was not found in PATH."
        case .processFailed(let message):
            return message.isEmpty ? "Download failed." : message
        case .missingOutputFile:
            return "Download finished but no output file was found."
        }
    }
}

actor MediaDownloaderService {
    private let fileManager = FileManager.default

    func download(sourceURL: String, destinationFolder: URL, quality: VideoQuality = .best) async throws -> DownloadResult {
        try await requireTool("yt-dlp")
        try await requireTool("ffmpeg")
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let startDate = Date()
        var arguments = [
            "yt-dlp",
            "--no-playlist",
            "--no-progress",
            "--restrict-filenames",
            "--paths", destinationFolder.path,
            "--output", "%(title).180B [%(id)s].%(ext)s",
            "--print", "after_move:%(filepath)s",
            "--print", "after_move:%(title)s",
        ]

        if quality == .audioOnly {
            arguments += [
                "-x",
                "--audio-format", "m4a",
                "--audio-quality", "0",
            ]
        } else {
            arguments += [
                "-f", quality.ytdlpFormatArg,
                "--merge-output-format", "mp4",
                "--recode-video", "mp4",
                "--postprocessor-args", "ffmpeg:-c:v libx264 -c:a aac",
            ]
        }

        arguments.append(sourceURL)

        let output = try await runProcess(executable: "/usr/bin/env", arguments: arguments)
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filePath = lines.first(where: { $0.hasPrefix("/") && fileManager.fileExists(atPath: $0) })
        let fileURL = try filePath.map(URL.init(fileURLWithPath:)) ?? newestMediaFile(in: destinationFolder, after: startDate)
        let title = lines.last(where: { !$0.hasPrefix("/") }) ?? fileURL.deletingPathExtension().lastPathComponent
        return DownloadResult(fileURL: fileURL, title: title)
    }

    private func requireTool(_ tool: String) async throws {
        _ = try await runProcess(executable: "/usr/bin/env", arguments: ["which", tool])
    }

    private func newestMediaFile(in folder: URL, after date: Date) throws -> URL {
        let extensions = Set(["mp4", "m4v", "mov"])
        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let candidates = files.compactMap { url -> (URL, Date)? in
            guard extensions.contains(url.pathExtension.lowercased()) else {
                return nil
            }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate, modified >= date.addingTimeInterval(-2) else {
                return nil
            }

            return (url, modified)
        }

        guard let newest = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            throw MediaDownloaderError.missingOutputFile
        }

        return newest
    }

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = DependencyChecker.processEnvironment
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    defer {
                        stdout.fileHandleForReading.closeFile()
                        stderr.fileHandleForReading.closeFile()
                    }
                    let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: MediaDownloaderError.processFailed(error))
                    }
                }

                do {
                    try process.run()
                } catch {
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
