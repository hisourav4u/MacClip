# MacClip

A native macOS clipboard history manager — the macOS equivalent of Windows clipboard history (Win+V).

## Features

| Feature | Detail |
|---|---|
| **Global hotkey** | `⌘ ⌃ V` opens the history popup from any app |
| **Auto-capture** | Every copy (`⌘C`) is recorded automatically |
| **Content types** | Plain text · Rich text · URLs · Images · Code snippets |
| **Persistent storage** | SwiftData (SQLite-backed), survives restarts |
| **Fuzzy search** | Type to filter history in real time |
| **Keyboard-first** | `↑ ↓` navigate · `↵` paste · `Esc` dismiss |
| **Pinning** | Pin entries so they're never pruned |
| **Auto-paste** | Selecting an entry copies it back and simulates `⌘V` |
| **Configurable** | Max history size (default 100), per-entry TTL via pruning |
| **Dark mode** | Full system appearance support |
| **Menu bar** | Lightweight; no Dock icon |

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ for building
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (installed automatically by `setup.sh`)

---

## Setup

```bash
cd MacClip
./setup.sh
open MacClip.xcodeproj
```

In Xcode:
1. Select the **MacClip** target → **Signing & Capabilities** → set your **Team**.
2. Press **⌘R** to build and run.

---

## First-run permissions

### Accessibility (required for auto-paste)

The app uses `CGEventPost` to simulate `⌘V` after you select an entry. macOS requires Accessibility access for this.

1. Launch the app.
2. Open **Settings** from the menu bar icon → click **Request Access**.
3. Approve in **System Settings → Privacy & Security → Accessibility**.

Without this permission the app falls back to AppleScript (`System Events`), which triggers its own prompt the first time.

### Automation / System Events (AppleScript fallback)

If Accessibility is not granted, the app sends keystrokes via `System Events`. macOS will prompt once per app.

---

## Usage

| Action | How |
|---|---|
| Open history popup | `⌘ ⌃ V` (global, works in any app) |
| Navigate entries | `↑` / `↓` |
| Paste selected entry | `↵` — copies to clipboard and simulates `⌘V` |
| Search | Just start typing in the search bar |
| Pin an entry | Hover the row → click the pin icon; pinned entries survive "Clear All" |
| Delete an entry | Hover the row → click the trash icon (or right-click → Delete) |
| Clear history | Popup toolbar → **Clear All** (leaves pinned entries) |
| Settings | Menu bar icon → **Settings…** |
| Quit | Menu bar icon → **Quit** |

---

## Architecture

```
MacClip/
├── App/
│   ├── MacClipApp.swift   — @main SwiftUI App + MenuBarExtra
│   └── AppDelegate.swift           — lifecycle, wires all services together
├── Models/
│   └── ClipboardEntry.swift        — SwiftData @Model (text, image, type, pin, timestamp)
├── Services/
│   ├── ClipboardMonitor.swift      — polls NSPasteboard.changeCount every 0.5 s
│   ├── HotkeyManager.swift         — Carbon RegisterEventHotKey for ⌘⌃V
│   └── PasteService.swift          — CGEventPost (+ AppleScript fallback) for ⌘V
├── Views/
│   ├── PopupWindowController.swift — floating NSPanel, lifecycle management
│   ├── ClipboardHistoryView.swift  — SwiftUI main view, @Query + @State
│   ├── ClipboardItemRow.swift      — per-entry row with hover actions
│   ├── ContentPreviewView.swift    — right-pane preview (text selection enabled)
│   ├── SearchFieldView.swift       — NSViewRepresentable wrapping custom NSTextField
│   │                                 that intercepts ↑ ↓ ↵ Esc for navigation
│   └── SettingsView.swift          — preferences window
└── Utilities/
    └── FuzzySearch.swift           — substring + fuzzy char-order matching
```

### Key design decisions

- **SwiftData** instead of CoreData: no `.xcdatamodeld` file needed; `@Model` macro + `@Query` handles everything.
- **Carbon `RegisterEventHotKey`** for the global shortcut: works without Accessibility permission, unlike `CGEventTap`.
- **Custom `NSTextField` subclass** for the search field: intercepts navigation keys before AppKit's default cursor-movement behaviour, so `↓` navigates the list rather than moving the caret.
- **NSPanel** (not NSWindow): `isFloatingPanel = true` keeps the popup above other windows without stealing activation from the target app.
- **No Electron / Catalyst**: 100% native Swift + SwiftUI + AppKit.

---

## Configuration (UserDefaults)

| Key | Type | Default | Description |
|---|---|---|---|
| `maxHistorySize` | Int | 100 | Max unpinned entries kept |
| `autoPasteEnabled` | Bool | true | Simulate `⌘V` after selecting an entry |

Exposed via **Settings…** in the menu bar.

---

## Building a release

```bash
xcodebuild \
  -project MacClip.xcodeproj \
  -scheme MacClip \
  -configuration Release \
  -archivePath build/MacClip.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath build/MacClip.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/
```

For notarisation, add your Apple ID credentials and run `xcrun notarytool`.

---

## Privacy

- MacClip never uploads clipboard data anywhere.
- All history is stored locally in the app's SwiftData store (`~/Library/Application Support/MacClip/`).
- The app only reads the system clipboard — it cannot inject content into other apps without your explicit action.
