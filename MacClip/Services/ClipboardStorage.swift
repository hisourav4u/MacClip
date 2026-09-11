import Foundation
import AppKit

@MainActor
final class ClipboardStorage: ObservableObject {
    static let shared = ClipboardStorage()

    @Published private(set) var entries: [ClipboardEntry] = []

    // Set to 1 before writing to the pasteboard internally so the monitor
    // skips that change and doesn't re-add the entry we just pasted.
    var suppressCaptureCount = 0

    var maxHistorySize: Int {
        let v = UserDefaults.standard.integer(forKey: "maxHistorySize")
        return v > 0 ? v : 100
    }

    // MARK: - Storage layout

    private lazy var storageDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MacClip", isDirectory: true)
        // Migrate history from the app's pre-rename storage directory.
        let legacy = base.appendingPathComponent("ClipboardManager", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.moveItem(at: legacy, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var indexURL: URL { storageDir.appendingPathComponent("history.json") }

    private func imageURL(for id: UUID) -> URL {
        storageDir.appendingPathComponent("\(id.uuidString).imgdata")
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let loaded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = loaded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Image sidecar I/O

    func saveImage(_ data: Data, for id: UUID) {
        try? data.write(to: imageURL(for: id), options: .atomic)
    }

    func loadImage(for entry: ClipboardEntry) -> NSImage? {
        guard entry.hasImage else { return nil }
        guard let data = try? Data(contentsOf: imageURL(for: entry.id)) else { return nil }
        return NSImage(data: data)
    }

    private func deleteImage(for id: UUID) {
        try? FileManager.default.removeItem(at: imageURL(for: id))
    }

    // MARK: - Mutations

    func add(_ entry: ClipboardEntry) {
        // Deduplicate against the most recent unpinned entry
        if let recent = entries.first(where: { !$0.isPinned }) ?? entries.first {
            if recent.textContent == entry.textContent && entry.textContent != nil { return }
            if recent.hasImage && entry.hasImage { return } // same image checked by caller
        }

        var mutable = entries
        mutable.insert(entry, at: 0)

        // Prune: keep pinned + newest N unpinned
        let pinned = mutable.filter { $0.isPinned }
        var unpinned = mutable.filter { !$0.isPinned }
        if unpinned.count > maxHistorySize {
            let removed = unpinned.dropFirst(maxHistorySize)
            removed.forEach { deleteImage(for: $0.id) }
            unpinned = Array(unpinned.prefix(maxHistorySize))
        }

        entries = pinned + unpinned
        entries.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }

        persist()
    }

    func delete(_ entry: ClipboardEntry) {
        deleteImage(for: entry.id)
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func togglePin(_ entry: ClipboardEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].isPinned.toggle()
        entries.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }
        persist()
    }

    func clearUnpinned() {
        let toDelete = entries.filter { !$0.isPinned }
        toDelete.forEach { deleteImage(for: $0.id) }
        entries.removeAll { !$0.isPinned }
        persist()
    }
}
