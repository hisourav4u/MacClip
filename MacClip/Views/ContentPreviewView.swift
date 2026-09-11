import SwiftUI
import AppKit

struct ContentPreviewView: View {
    let entry: ClipboardEntry
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.opacity(0.4))
        .task(id: entry.id) {
            image = entry.hasImage ? ClipboardStorage.shared.loadImage(for: entry) : nil
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.typeIcon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(typeName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text(entry.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        ScrollView {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                } else if let text = entry.textContent {
                    Text(text)
                        .font(.system(size: 12, design: entry.isCode ? .monospaced : .default))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No preview available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let text = entry.textContent {
                Label("\(text.count) chars", systemImage: "character.cursor.ibeam")
                let words = text.split(whereSeparator: \.isWhitespace).count
                if words > 0 { Label("\(words) words", systemImage: "text.word.spacing") }
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var typeName: String {
        if entry.isImage { return "Image" }
        if entry.isURL { return "URL" }
        if entry.isCode { return "Code" }
        if entry.contentType == "public.rtf" { return "Rich Text" }
        return "Plain Text"
    }
}
