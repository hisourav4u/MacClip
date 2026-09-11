import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardMonitor: ClipboardMonitor?
    private var hotkeyManager: HotkeyManager?
    private var popupController: PopupWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let storage = ClipboardStorage.shared
        storage.load()

        clipboardMonitor = ClipboardMonitor(storage: storage)
        clipboardMonitor?.start()

        try? SMAppService.mainApp.register()

        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyPressed = { [weak self] in self?.togglePopup() }
        hotkeyManager?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotkeyManager?.unregister()
    }

    // MARK: - Actions

    func togglePopup() {
        if popupController == nil {
            popupController = PopupWindowController()
        }
        if popupController!.isVisible {
            popupController!.close()
        } else {
            popupController!.showPopup()
        }
    }
}
