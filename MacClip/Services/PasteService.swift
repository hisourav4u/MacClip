import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum PasteService {
    static func copyToClipboard(_ entry: ClipboardEntry) {
        ClipboardStorage.shared.suppressCaptureCount += 1
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = entry.textContent {
            pb.setString(text, forType: .string)
        } else if entry.hasImage, let image = ClipboardStorage.shared.loadImage(for: entry) {
            pb.writeObjects([image])
        }
    }

    static func simulatePaste() {
        if AXIsProcessTrusted() {
            simulateWithCGEvent()
        } else {
            // Fallback: System Events keystroke (requires Automation permission)
            guard let script = NSAppleScript(source:
                "tell application \"System Events\" to keystroke \"v\" using command down"
            ) else { return }
            var err: NSDictionary?
            script.executeAndReturnError(&err)
        }
    }

    private static func simulateWithCGEvent() {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags   = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
