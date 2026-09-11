import AppKit
import SwiftUI

@MainActor
final class PopupWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    let keyState = PopupKeyState()

    var isVisible: Bool { panel?.isVisible ?? false }

    func showPopup() {
        // Save who was active before we steal focus.
        previousApp = NSWorkspace.shared.frontmostApplication

        if panel == nil { buildPanel() }
        positionCenter()
        // Activate our app so that — on the very first paste — the macOS
        // Automation permission dialog can surface above other windows.
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        probeAutomationPermission()
        requestAccessibilityIfNeeded()
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        // 300 ms gives the panel time to appear on screen before the system
        // dialog surfaces — avoids the NULL-dereference crash we hit at launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !AXIsProcessTrusted() else { return }
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    // Run a no-op AppleScript while our app is frontmost so macOS shows the
    // "MacClip wants to control System Events" dialog in context.
    // After the user clicks OK once, this becomes a fast no-op on every open.
    private func probeAutomationPermission() {
        DispatchQueue.main.async {
            guard let script = NSAppleScript(source: "tell application \"System Events\" to get name") else { return }
            var err: NSDictionary?
            script.executeAndReturnError(&err)
        }
    }

    func close() {
        removeKeyMonitor()
        panel?.close()
    }

    func pasteEntry(_ entry: ClipboardEntry) {
        let target = previousApp
        PasteService.copyToClipboard(entry)
        close()
        target?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            PasteService.simulatePaste()
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        removeKeyMonitor()
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
        panel = nil
    }

    // MARK: - Key monitor

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 126: self.keyState.upCount += 1;      return nil   // ↑
            case 125: self.keyState.downCount += 1;    return nil   // ↓
            case 36, 76: self.keyState.selectCount += 1; return nil  // Return
            case 53: self.keyState.escapeCount += 1;   return nil   // Esc
            default:  return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    // MARK: - Private

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.minSize = NSSize(width: 480, height: 360)
        panel.delegate = self

        let rootView = ClipboardHistoryView(
            keyState: keyState,
            onDismiss: { [weak self] in self?.close() },
            onPasteAndDismiss: { [weak self] entry in self?.pasteEntry(entry) }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.panel = panel
    }

    private func positionCenter() {
        guard let panel, let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let s = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: max(f.minX, min(f.midX - s.width / 2,  f.maxX - s.width)),
            y: max(f.minY, min(f.midY - s.height / 2 + 60, f.maxY - s.height))
        ))
    }
}
