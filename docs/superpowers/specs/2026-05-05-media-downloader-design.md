# Media Downloader Design

## Scope

Build a small native macOS app that downloads a pasted media URL through user-installed `yt-dlp` and `ffmpeg`. The v1 app assumes both tools are available in `PATH`.

## UI

The app opens as a frameless, transparent, Spotlight-style floating window. A large input appears in the center with a fade/scale animation. A gear button sits inside the right side of the input and opens a folder picker. A history surface below the input matches its width and lists completed downloads with thumbnail, source URL or title, and actions to copy the file, reveal it in Finder, or open the original link.

## Behavior

Submitting or pasting a URL starts a download. The app runs `yt-dlp` with `ffmpeg` for MP4 output so the resulting file is broadly compatible with macOS playback. On success, it writes the downloaded file URL to the pasteboard and adds the item to persisted history.

## Persistence

The chosen download folder persists in `UserDefaults`. Completed history persists as JSON in Application Support. Thumbnails are generated locally from the downloaded media and stored in Application Support.

## Error Handling

Missing `yt-dlp` or `ffmpeg`, invalid URLs, process failures, and missing output files surface as compact status text below the input. The app does not manage tool installation in v1.

## Build

The project is a SwiftPM macOS GUI app. `script/build_and_run.sh` builds the executable, stages a local `.app` bundle, and launches it as a foreground app. `.codex/environments/environment.toml` exposes the same script through the Codex Run action.
