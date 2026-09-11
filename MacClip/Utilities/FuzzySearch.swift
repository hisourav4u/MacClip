import Foundation

/// Ranked, multi-term search.
///
/// The old version matched a query against text if every query character
/// appeared *somewhere in order* (a subsequence). For short queries that
/// matches almost everything ("cat" hits any text with c…a…t), which is why
/// unrelated results kept showing up. This version:
///   - splits the query on whitespace and requires EVERY term to match (AND),
///   - ranks matches (exact > word-start > prefix > substring > weak fuzzy),
///   - only allows loose subsequence matching for terms of 3+ characters, as a
///     last resort, so it can never dominate a real substring hit.
enum FuzzySearch {
    /// True if the query matches at all. Kept for callers that only need a bool.
    static func matches(query: String, in text: String) -> Bool {
        score(query: query, in: text) > 0
    }

    /// 0 means "no match". Higher is a better match. Callers should sort by this.
    static func score(query: String, in text: String) -> Double {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return 1 }
        let t = text.lowercased()

        let terms = q.split(whereSeparator: { $0 == " " }).map(String.init)
        guard !terms.isEmpty else { return 1 }

        var total = 0.0
        for term in terms {
            let s = termScore(term, in: t)
            if s == 0 { return 0 }   // AND: a query only matches if every term does
            total += s
        }
        return total / Double(terms.count)
    }

    // MARK: - private

    private static func termScore(_ term: String, in t: String) -> Double {
        if t == term { return 1.0 }
        if wordStartsWith(term, in: t) { return 0.9 }   // a word in the text begins with the term
        if t.hasPrefix(term) { return 0.85 }
        if t.contains(term) { return 0.6 }              // contiguous substring anywhere
        return 0                                        // substring/word match only — no loose fuzzy
    }

    /// Any whitespace/punctuation-delimited word in `t` that starts with `term`.
    private static func wordStartsWith(_ term: String, in t: String) -> Bool {
        for word in t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if word.hasPrefix(term) { return true }
        }
        return false
    }
}
