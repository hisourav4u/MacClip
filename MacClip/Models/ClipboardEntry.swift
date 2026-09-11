import Foundation
import AppKit

struct ClipboardEntry: Identifiable, Codable {
    var id: UUID
    var textContent: String?
    var hasImage: Bool          // actual image bytes live in a sidecar file
    var contentType: String
    var timestamp: Date
    var isPinned: Bool
    var sourceApp: String?

    init(
        id: UUID = UUID(),
        textContent: String? = nil,
        hasImage: Bool = false,
        contentType: String,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        sourceApp: String? = nil
    ) {
        self.id = id
        self.textContent = textContent
        self.hasImage = hasImage
        self.contentType = contentType
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.sourceApp = sourceApp
    }

    var displayText: String {
        textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var isImage: Bool { hasImage }

    var isURL: Bool {
        guard let text = textContent else { return false }
        return text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("ftp://")
    }

    var isCode: Bool {
        guard let text = textContent, !isURL else { return false }
        let patterns = ["func ", "class ", "struct ", "import ", "let ", "var ", "const ", "def ",
                        "function ", "public ", "private ", "{", "};", "=>", "->", "#include"]
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return patterns.contains { t.contains($0) } && t.contains("\n")
    }

    private var trimmed: String {
        textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var isEmail: Bool {
        let t = trimmed
        guard !t.isEmpty, !t.contains(" "), !t.contains("\n"), t.contains("@") else { return false }
        return t.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    var isColor: Bool {
        let t = trimmed
        guard !t.isEmpty else { return false }
        if t.range(of: #"^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#,
                   options: .regularExpression) != nil { return true }
        return t.range(of: #"^rgba?\([\d\s.,%/]+\)$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    var isFilePath: Bool {
        guard !isURL else { return false }
        let t = trimmed
        guard !t.isEmpty, !t.contains("\n") else { return false }
        return t.hasPrefix("file://")
            || t.hasPrefix("~/")
            || (t.hasPrefix("/") && t.dropFirst().contains("/"))
    }

    /// The single bucket this entry belongs to, most specific first.
    var category: ClipboardCategory {
        if isImage { return .image }
        if isURL { return .link }
        if isEmail { return .email }
        if isColor { return .color }
        if isFilePath { return .file }
        if isCode { return .code }
        return .text
    }

    /// What search runs against. Images have no text, so give them a keyword.
    var searchableText: String {
        if let text = textContent, !text.isEmpty { return text }
        return isImage ? "image photo" : ""
    }

    var typeIcon: String {
        if contentType == "public.rtf" && category == .text { return "textformat" }
        return category.icon
    }
}

/// The type buckets a clipboard entry can be filtered by.
enum ClipboardCategory: String, CaseIterable, Identifiable {
    case all, text, link, image, code, email, color, file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:   return "All"
        case .text:  return "Text"
        case .link:  return "Links"
        case .image: return "Images"
        case .code:  return "Code"
        case .email: return "Emails"
        case .color: return "Colors"
        case .file:  return "Files"
        }
    }

    var icon: String {
        switch self {
        case .all:   return "square.grid.2x2"
        case .text:  return "doc.text"
        case .link:  return "link"
        case .image: return "photo"
        case .code:  return "curlybraces"
        case .email: return "envelope"
        case .color: return "paintpalette"
        case .file:  return "folder"
        }
    }
}
