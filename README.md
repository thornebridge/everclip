# EverClip

**The clipboard manager your Mac deserves.**

Native Swift. Apple Silicon optimized. 100% free and open source. Your data never leaves your machine.

[Download](https://github.com/thornebridge/everclip/releases) | [Website](https://thornebridge.github.io/everclip) | [Source](https://github.com/thornebridge/everclip)

---

## Features

- **Infinite clipboard history** — Save from 1 to 1,000,000 entries
- **7 content types** — Text, URLs, images, code, files, colors, Markdown — each with smart detection and rich previews
- **Pinboards & Tags** — Organize clips into color-coded collections with multi-board support
- **Smart Rules** — Auto-route entries to pinboards based on source app, content type, regex, or URL domain
- **Paste Stack** — Collect multiple copies with `Cmd+Shift+C`, paste them all in order
- **Paste Transformations** — UPPERCASE, lowercase, Title Case, URL encode, trim, wrap in quotes — right from the context menu
- **Text Expansion** — Snippets with `{{date}}`, `{{time}}`, `{{clipboard}}` template variables
- **Quick Look** — Spacebar for full-size preview of any entry
- **Drag & Drop** — Drag clips directly into any app
- **Privacy First** — Exclude apps, pause capture, everything stays local

## Install

### Download (recommended)

1. Download the `.dmg` from [Releases](https://github.com/thornebridge/everclip/releases/latest)
2. Open the DMG and drag EverClip to Applications
3. **First launch**: Right-click the app → **Open** (bypasses Gatekeeper since the app isn't notarized yet)
4. Grant Accessibility permissions when prompted

> EverClip is open source and ad-hoc signed. macOS may warn about unverified developers on first launch. Right-click → Open resolves this permanently. Alternatively run: `xattr -cr /Applications/EverClip.app`

### Build from source

Requires macOS 14+ and Swift 5.9+.

```bash
git clone https://github.com/thornebridge/everclip.git
cd everclip
bash scripts/build.sh
open EverClip.app
```

### Install to Applications

```bash
cp -r EverClip.app /Applications/
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+V` | Open / close EverClip |
| `Cmd+Shift+C` | Toggle Paste Stack |
| `Left / Right` | Navigate clips |
| `Return` | Paste selected clip |
| `Space` | Quick Look preview |
| `Delete` | Delete selected clip |
| `Escape` | Close drawer |

## Architecture

- **41 Swift source files**, ~3,900 lines
- **Zero external dependencies** — only system frameworks (AppKit, SwiftUI, Carbon, CryptoKit, WebKit, SQLite3)
- **SQLite** with WAL mode for persistence
- **Native ARM64** binary optimized for Apple Silicon (M1/M2/M3/M4)
- Menu bar app — no dock icon, runs forever in the background

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI + AppKit |
| Storage | SQLite3 (via C interop) |
| Hotkeys | Carbon EventHotKey API |
| Paste simulation | CoreGraphics CGEvent |
| Markdown | WKWebView with custom renderer |
| Platform | macOS 14+ (Sonoma) |

## License

MIT License. See [LICENSE](LICENSE).

---

**Powered by [Thornebridge](https://thornebridge.tech)** — We build technology for a reason.
