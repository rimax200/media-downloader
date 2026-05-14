<p align="center">
  <img width="128" height="128" alt="Media Downloader" src="https://github.com/user-attachments/assets/ee37ab6e-2903-4374-8ff1-b6ef071f28f7" />
</p>

<h1 align="center">Media Downloader</h1>

<p align="center">
  A native macOS app for downloading videos from YouTube, Instagram, X, TikTok, Reddit, Vimeo, and thousands of other platforms.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
</p>

---

https://github.com/user-attachments/assets/c81f8c07-835d-4d37-87cf-926caa0fe6c1

---

## Overview

Media Downloader is a focused, native macOS application built with SwiftUI. Paste any supported URL into the Spotlight-style input bar and the app handles the rest — downloading, converting, copying to clipboard, and keeping a local history with thumbnails. No browser extensions, no Electron, no clutter.

Under the hood it uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) for media extraction and [ffmpeg](https://ffmpeg.org) for conversion, merging, trimming, and export. Both are industry-standard open-source tools that support [thousands of sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md).

---

## Features

- **One-step downloads** — paste a URL, pick a quality, done.
- **Quality selection** — choose Best, 1080p, 720p, 480p, or Audio Only before each download. Set a default in Settings to skip the picker entirely.
- **Auto copy** — the downloaded file is copied to your clipboard immediately after download.
- **Download history** — thumbnail previews, quick-copy, Finder reveal, and source link for every past download.
- **Video trimmer** — scrub, set in/out points, and export or copy the trimmed clip without leaving the app. Real-time ffmpeg progress bar during export.
- **Audio support** — trims and exports audio-only downloads correctly as M4A.
- **Custom download folder** — choose and persist any folder on your Mac.
- **Global hotkeys** — configurable keyboard shortcuts for activating the app, copying, and opening the trimmer.
- **Update checker** — checks GitHub Releases for new versions from the Settings menu.
- **Fully native** — built with SwiftUI and AppKit, runs natively on Apple Silicon and Intel.

---

## Supported Platforms

Anything supported by `yt-dlp`, including:

| Platform | Platform | Platform |
|---|---|---|
| YouTube | Instagram | X (Twitter) |
| TikTok | Reddit | Vimeo |
| Facebook | Dailymotion | Twitch |
| SoundCloud | Bandcamp | ... and thousands more |

> **Note:** Threads is not currently supported — Meta blocks third-party media access.

---

## Requirements

- macOS 14 (Sonoma) or newer
- Apple Silicon or Intel Mac
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org)

---

## Installation

### Download

Grab the latest `.dmg` from [Releases](../../releases/latest), open it, and drag **MediaDownloader.app** to your Applications folder.

### Dependencies

The app requires `yt-dlp` and `ffmpeg` to be installed on your system. The easiest way is via [Homebrew](https://brew.sh):

```sh
brew install yt-dlp ffmpeg
```

---

## Building from Source

### Prerequisites

```sh
# Install Xcode Command Line Tools
xcode-select --install

# Install runtime dependencies
brew install yt-dlp ffmpeg
```

### Build

```sh
# Debug build
swift build

# Release build
swift build -c release
```

### Run

```sh
# Via Swift Package Manager
.build/release/MediaDownloader

# Or open in Xcode for live development
open Package.swift
```

### Test

```sh
swift test
```

### App Bundle (for distribution or Finder launch)

```sh
./script/build_and_run.sh
```

This builds a proper `.app` bundle at `dist/MediaDownloader.app` and launches it. Additional modes:

| Command | Description |
|---|---|
| `./script/build_and_run.sh --verify` | Build and verify bundle structure |
| `./script/build_and_run.sh --logs` | Launch with console logging |
| `./script/build_and_run.sh --debug` | Attach debugger |
| `./script/build_and_run.sh --setup` | Install dependencies and build |

---

## Project Structure

```
Media-downloader/
├── Package.swift                        # Swift Package Manager manifest
├── Sources/MediaDownloader/
│   ├── App/                             # App lifecycle, AppModel, settings, hotkeys
│   ├── Models/                          # Data models (DownloadItem, TrimSelection, etc.)
│   ├── Services/                        # yt-dlp, ffmpeg, thumbnail, update checker
│   ├── Stores/                          # UserDefaults and history persistence
│   ├── Support/                         # URL validation
│   └── Views/                           # SwiftUI views
├── Tests/MediaDownloaderTests/          # Unit tests
├── Resources/                           # App icon
└── script/                              # Build, bundle, and release scripts
```

---

## How It Works

1. **Download** — `yt-dlp` fetches the best available stream(s) for the selected quality. `ffmpeg` merges video and audio tracks and recodes to H.264/AAC MP4.
2. **History** — each download is saved to a JSON file in Application Support with its file path, source URL, title, and thumbnail.
3. **Trim** — the trim editor uses `AVPlayer` for playback and calls `ffmpeg` directly for frame-accurate export, streaming real-time progress from stderr.
4. **Preferences** — stored in `UserDefaults`. History and thumbnails live in `~/Library/Application Support/MediaDownloader/`.

---

## Keeping yt-dlp Up to Date

Site compatibility depends on your installed `yt-dlp` version. If a site stops working, update it:

```sh
brew upgrade yt-dlp
```

---

## License

MIT
