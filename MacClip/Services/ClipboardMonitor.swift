import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let storage: ClipboardStorage
    private var timer: Timer?
    private var lastChangeCount: Int

    init(storage: ClipboardStorage) {
        self.storage = storage
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkForChanges() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func checkForChanges() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if storage.suppressCaptureCount > 0 {
            storage.suppressCaptureCount -= 1
            return
        }

        capture(pb)
    }

    private func capture(_ pb: NSPasteboard) {
        // Text (covers plain, rich, HTML, code, URLs)
        if let text = pb.string(forType: .string), !text.isEmpty {
            storage.add(ClipboardEntry(
                textContent: text,
                contentType: detectType(text)
            ))
            return
        }

        // RTF with plain text fallback
        if let rtfData = pb.data(forType: .rtf),
           let attr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            storage.add(ClipboardEntry(
                textContent: attr.string,
                contentType: "public.rtf"
            ))
            return
        }

        // Image
        if let imgData = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            let entry = ClipboardEntry(hasImage: true, contentType: "public.image")
            storage.saveImage(imgData, for: entry.id)
            storage.add(entry)
        }
    }

    private func detectType(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") || t.hasPrefix("ftp://") {
            return "public.url"
        }
        return "public.plain-text"
    }
}
