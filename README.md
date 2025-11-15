# Trimmy

> "Paste once, run once." — Trimmy flattens those multi-line shell snippets you copy so they actually paste and run.

## What it does
- Lives in your macOS menu bar (macOS 15+). No Dock icon.
- Watches the clipboard and, when it looks like a shell command, removes newlines (respects `\` continuations) and rewrites the clipboard automatically.
- Aggressiveness levels (Low/Normal/High) to control how eagerly it detects commands.
- Optional "Keep blank lines" so scripts with intentional spacing stay readable.
- Manual "Trim Clipboard Now" button if you just want to force a flatten.
- Uses a marker pasteboard type to avoid reprocessing its own writes; polls with a lightweight timer and a small grace delay to catch promised pasteboard data.

## Quick start
1. Build: `swift build -c release` (Swift 6, macOS 15+).
2. Bundle: `./Scripts/package_app.sh release` → `Trimmy.app`.
3. Launch: open `Trimmy.app` (or add to Login Items). Menu shows Auto-Trim toggle, Aggressiveness submenu, Keep blank lines toggle, Trim Now, and last-trim status.

## Notes
- Bundle ID: `com.steipete.trimmy` (LSUIElement menu-bar app).
- Polling: ~150ms with leeway; grace delay ~80ms to let promised data arrive.
- Clipboard writes tag themselves with `dev.peter.trimmy` to avoid loops.

## License
MIT
