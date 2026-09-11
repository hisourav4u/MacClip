import SwiftUI

@main
struct MacClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var storage = ClipboardStorage.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(appDelegate: appDelegate, storage: storage)
        } label: {
            Image(systemName: "doc.on.clipboard.fill")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarMenuView: View {
    let appDelegate: AppDelegate
    let storage: ClipboardStorage

    var body: some View {
        Button("Show History  ⌘⌃V") { appDelegate.togglePopup() }
        Divider()
        SettingsLink()
        Button("Clear History") { storage.clearUnpinned() }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
