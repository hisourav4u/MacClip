import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject private var storage = ClipboardStorage.shared
    @ObservedObject var keyState: PopupKeyState
    @State private var searchText = ""
    @State private var selectedCategory: ClipboardCategory = .all
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    var onDismiss: () -> Void
    var onPasteAndDismiss: (ClipboardEntry) -> Void

    private var filteredEntries: [ClipboardEntry] {
        // 1) narrow by category (keeps storage order: pinned first, then recent)
        var items = storage.entries
        if selectedCategory != .all {
            items = items.filter { $0.category == selectedCategory }
        }

        // 2) no query -> return as-is
        guard !searchText.isEmpty else { return items }

        // 3) rank by match score, break ties by recency
        return items
            .compactMap { entry -> (ClipboardEntry, Double)? in
                let s = FuzzySearch.score(query: searchText, in: entry.searchableText)
                return s > 0 ? (entry, s) : nil
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.timestamp > $1.0.timestamp }
            .map { $0.0 }
    }

    /// Categories that actually have at least one entry (plus All), for the chip bar.
    private var availableCategories: [ClipboardCategory] {
        let present = Set(storage.entries.map(\.category))
        return ClipboardCategory.allCases.filter { $0 == .all || present.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryBar
            Divider()
            bodyContent
            Divider()
            toolbar
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
        .onAppear { searchFocused = true }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
        .onChange(of: selectedCategory) { _, _ in selectedIndex = 0 }
        .onChange(of: storage.entries.count) { _, _ in clampIndex() }
        .onChange(of: keyState.upCount)     { _, _ in moveUp() }
        .onChange(of: keyState.downCount)   { _, _ in moveDown() }
        .onChange(of: keyState.selectCount) { _, _ in activateSelected() }
        .onChange(of: keyState.escapeCount) { _, _ in onDismiss() }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .medium))

            TextField("Search clipboard history...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var categoryBar: some View {
        let cats = availableCategories
        if cats.count > 1 {   // only show when there's more than just "All"
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(cats) { cat in
                        categoryChip(cat)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func categoryChip(_ cat: ClipboardCategory) -> some View {
        let selected = selectedCategory == cat
        return Button {
            selectedCategory = cat
        } label: {
            HStack(spacing: 4) {
                Image(systemName: cat.icon).font(.system(size: 10, weight: .medium))
                Text(cat.title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if filteredEntries.isEmpty {
            emptyState
        } else {
            HSplitView {
                listPane.frame(minWidth: 240, maxWidth: .infinity)
                previewPane.frame(minWidth: 180, maxWidth: .infinity)
            }
        }
    }

    private var listPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                        ClipboardItemRow(
                            entry: entry,
                            isSelected: index == selectedIndex,
                            onSelect: { selectedIndex = index },
                            onActivate: { selectedIndex = index; activateSelected() },
                            onPin: { storage.togglePin(entry) },
                            onDelete: { deleteEntry(entry, at: index) }
                        )
                        .id(entry.id)   // stable identity so the list rebuilds when the filter changes
                    }
                }
                .padding(6)
            }
            .onChange(of: selectedIndex) { _, idx in
                guard idx >= 0, idx < filteredEntries.count else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(filteredEntries[idx].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        if selectedIndex < filteredEntries.count {
            ContentPreviewView(entry: filteredEntries[selectedIndex])
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard").font(.system(size: 32)).foregroundStyle(.tertiary)
                Text("No selection").font(.subheadline).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No clipboard history" : "No results for \"\(searchText)\"")
                .font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            let count = filteredEntries.count
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)

            Spacer()
            keyHint("↑↓", "navigate")
            keyHint("↵", "paste")
            keyHint("⎋", "close")
            Divider().frame(height: 12)
            Button("Clear All") { storage.clearUnpinned() }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.red.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.secondary.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func moveUp() {
        guard !filteredEntries.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }

    private func moveDown() {
        guard !filteredEntries.isEmpty else { return }
        selectedIndex = min(filteredEntries.count - 1, selectedIndex + 1)
    }

    private func activateSelected() {
        guard selectedIndex < filteredEntries.count else { return }
        onPasteAndDismiss(filteredEntries[selectedIndex])
    }

    private func clampIndex() {
        let max = max(0, filteredEntries.count - 1)
        if selectedIndex > max { selectedIndex = max }
    }

    private func deleteEntry(_ entry: ClipboardEntry, at index: Int) {
        storage.delete(entry)
        selectedIndex = max(0, min(index, filteredEntries.count - 1))
    }
}
