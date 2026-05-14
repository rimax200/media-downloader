import AppKit
import AVFoundation
import SwiftUI

struct VideoTrimPanelView: View {
    let session: ActiveTrimSession
    let playbackCommand: Int
    let onClose: () -> Void
    let onCopy: (TrimSelection, @Sendable @escaping (Double) -> Void) async throws -> Void
    let onSave: (TrimSelection, URL, @Sendable @escaping (Double) -> Void) async throws -> URL

    @State private var player = AVPlayer()
    @State private var duration: Double = 0
    @State private var selection = TrimSelection(start: 0, end: 0)
    @State private var isHoveringVideo = false
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var feedback: String?
    @State private var timelineFrames: [NSImage] = []
    @State private var playheadTime: Double = 0
    @State private var timeObserver: Any?
    @State private var boundaryObserver: Any?
    @State private var copySucceeded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 0) {
                VideoPlayerSurface(player: player)
                    .frame(width: 680, height: 430)
                    .background(.black)

                Spacer(minLength: 0)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            videoControls

            VStack(spacing: 8) {
                if let feedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .frame(width: 648, alignment: .leading)
                }

                TrimTimelineView(
                    selection: $selection,
                    playheadTime: $playheadTime,
                    duration: duration,
                    frames: timelineFrames,
                    onSeek: seekPreview
                )
                .frame(width: 640, height: 60)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 680, height: 520)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 32, x: 0, y: 18)
        .onHover { isHoveringVideo = $0 }
        .onAppear(perform: loadVideo)
        .onChange(of: playbackCommand) { _, _ in
            togglePlayback()
        }
        .onChange(of: selection) { _, _ in
            updatePlaybackBoundsForSelection()
        }
        .onDisappear {
            player.pause()
            removePlaybackObservers()
            player.replaceCurrentItem(with: nil)
        }
    }

    private var videoControls: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    overlayButton(systemName: "xmark", help: "Close trim mode", action: onClose)
                }
                Spacer()
            }
            .padding(14)

            VStack {
                Spacer()
                HStack {
                    overlayButton(systemName: isPlaying ? "pause.fill" : "play.fill", help: "Play", action: togglePlayback)
                    Spacer()

                    HStack(spacing: 8) {
                        overlayButton(systemName: copySucceeded ? "checkmark" : "doc.on.doc", help: "Copy trim to clipboard", action: copyTrim)
                        overlayButton(systemName: "square.and.arrow.up", help: "Export trim", action: saveTrim)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 88)

            if isExporting {
                ExportProgressBar(progress: exportProgress)
                    .frame(width: 320, height: 36)
            }
        }
    }

    private func overlayButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .disabled(isExporting)
    }

    private func loadVideo() {
        removePlaybackObservers()
        player.replaceCurrentItem(with: AVPlayerItem(url: session.fileURL))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.02, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }

            let boundedSelection = selection.clamped(to: duration)
            if isPlaying, seconds >= boundedSelection.end - 0.001 {
                stopPlaybackAtSelectionEnd()
                return
            }

            playheadTime = min(max(seconds, boundedSelection.start), boundedSelection.end)
        }

        Task {
            let asset = AVURLAsset(url: session.fileURL)
            let loadedDuration = (try? await asset.load(.duration)) ?? .zero
            let seconds = CMTimeGetSeconds(loadedDuration)
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
            selection = TrimSelection(start: 0, end: duration)
            playheadTime = 0
            timelineFrames = await generateTimelineFrames(asset: asset, duration: duration)
            installEndBoundaryObserver()
        }
    }

    private func removePlaybackObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        removeEndBoundaryObserver()
    }

    private func removeEndBoundaryObserver() {
        if let boundaryObserver {
            player.removeTimeObserver(boundaryObserver)
            self.boundaryObserver = nil
        }
    }

    private func generateTimelineFrames(asset: AVAsset, duration: Double) async -> [NSImage] {
        guard duration > 0 else {
            return []
        }

        return await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = CGSize(width: 180, height: 110)

            let frameCount = 18
            return (0..<frameCount).compactMap { index in
                let seconds = duration * (Double(index) + 0.5) / Double(frameCount)
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                    return nil
                }

                return NSImage(cgImage: cgImage, size: .zero)
            }
        }.value
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            startBoundedPlayback()
        }
    }

    private func seekPreview(_ seconds: Double) {
        let boundedSelection = selection.clamped(to: duration)
        let boundedSeconds = min(max(seconds, boundedSelection.start), boundedSelection.end)
        let shouldResumePlayback = isPlaying && boundedSeconds < boundedSelection.end - 0.001

        if !shouldResumePlayback {
            player.pause()
            isPlaying = false
        }

        playheadTime = boundedSeconds
        player.seek(
            to: CMTime(seconds: boundedSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { finished in
            guard finished, shouldResumePlayback else { return }
            DispatchQueue.main.async {
                player.play()
                isPlaying = true
            }
        }
    }

    private func startBoundedPlayback() {
        let boundedSelection = selection.clamped(to: duration)
        guard boundedSelection.end > boundedSelection.start else { return }

        installEndBoundaryObserver()

        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let startSeconds: Double
        if currentSeconds.isFinite,
           currentSeconds >= boundedSelection.start,
           currentSeconds < boundedSelection.end - 0.001 {
            startSeconds = currentSeconds
        } else {
            startSeconds = boundedSelection.start
        }

        playheadTime = startSeconds
        player.seek(
            to: CMTime(seconds: startSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { finished in
            guard finished else { return }
            DispatchQueue.main.async {
                player.play()
                isPlaying = true
            }
        }
    }

    private func updatePlaybackBoundsForSelection() {
        installEndBoundaryObserver()

        guard isPlaying else { return }

        let boundedSelection = selection.clamped(to: duration)
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        guard currentSeconds.isFinite else { return }

        if currentSeconds >= boundedSelection.end - 0.001 {
            stopPlaybackAtSelectionEnd()
        } else if currentSeconds < boundedSelection.start {
            seekPreview(boundedSelection.start)
        }
    }

    private func installEndBoundaryObserver() {
        removeEndBoundaryObserver()

        let boundedSelection = selection.clamped(to: duration)
        guard boundedSelection.end > boundedSelection.start else { return }

        let endTime = CMTime(seconds: boundedSelection.end, preferredTimescale: 600)
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
            stopPlaybackAtSelectionEnd()
        }
    }

    private func stopPlaybackAtSelectionEnd() {
        let endSeconds = selection.clamped(to: duration).end
        player.pause()
        isPlaying = false
        playheadTime = endSeconds
        player.seek(
            to: CMTime(seconds: endSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func copyTrim() {
        runExport { progress in
            try await onCopy(selection.clamped(to: duration), progress)
        } onSuccess: {
            copySucceeded = true
            showFeedback("Trim copied to clipboard.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                copySucceeded = false
            }
        }
    }

    private func saveTrim() {
        let trimSelection = selection.clamped(to: duration)
        let suggestedName = session.fileURL.deletingPathExtension().lastPathComponent
            + " trim \(Int(trimSelection.start.rounded()))-\(Int(trimSelection.end.rounded()))s"

        let isAudioOnly = AVURLAsset(url: session.fileURL).tracks(withMediaType: .video).isEmpty
        let panel = NSSavePanel()
        panel.allowedContentTypes = isAudioOnly ? [.mpeg4Audio] : [.mpeg4Movie]
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = session.fileURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        runExport { progress in
            _ = try await onSave(trimSelection, destination, progress)
        } onSuccess: {
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            showFeedback("Saved.")
        }
    }

    private func runExport(
        operation: @escaping (@Sendable @escaping (Double) -> Void) async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isExporting else { return }
        isExporting = true
        exportProgress = 0
        feedback = nil

        Task {
            do {
                try await operation { progress in
                    Task { @MainActor in
                        exportProgress = progress
                    }
                }
                isExporting = false
                onSuccess?()
            } catch {
                isExporting = false
                showFeedback(error.localizedDescription)
            }
        }
    }

    private func showFeedback(_ message: String) {
        feedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if feedback == message {
                feedback = nil
            }
        }
    }
}

private struct VideoPlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.playerLayer.player = player
    }
}

private final class PlayerContainerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

private struct ExportProgressBar: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Exporting…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                        .frame(height: 4)

                    Capsule()
                        .fill(.white)
                        .frame(width: max(geo.size.width * progress, 6), height: 4)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
