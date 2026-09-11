import Foundation

// Key-event signals shared between PopupWindowController (producer)
// and ClipboardHistoryView (consumer). The controller installs a local
// NSEvent monitor that increments these counters; the view reacts via
// .onChange — no first-responder dependency required.
@MainActor
final class PopupKeyState: ObservableObject {
    @Published var upCount = 0
    @Published var downCount = 0
    @Published var selectCount = 0
    @Published var escapeCount = 0
}
