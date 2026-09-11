import SwiftUI
import AppKit

struct ClipboardItemRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            typeIcon.frame(width: 20, alignment: .center)
            contentPreview
            Spacer(minLength: 4)
            if isHovered || isSelected { actionButtons }
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onActivate)
        .onTapGesture(count: 1, perform: onSelect)
        .task(id: entry.id) {
            if entry.hasImage {
                thumbnail = ClipboardStorage.shared.loadImage(for: entry)
            }
        }
        .contextMenu {
            Button("Paste") { onActivate() }
            Divider()
            Button(entry.isPinned ? "Unpin" : "Pin") { onPin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var typeIcon: some View {
        Image(systemName: entry.typeIcon)
            .font(.system(size: 12))
            .foregroundStyle(iconColor)
    }

    private var iconColor: Color {
        if entry.isImage { return .blue }
        if entry.isURL { return .green }
        if entry.isCode { return .purple }
        if entry.contentType == "public.rtf" { return .orange }
        return .secondary
    }

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text(entry.displayText.isEmpty ? "(empty)" : entry.displayText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(relativeTime(entry.timestamp))
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button(action: onPin) {
                Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected { Color.accentColor }
        else if isHovered { Color.primary.opacity(0.06) }
        else { Color.clear }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
