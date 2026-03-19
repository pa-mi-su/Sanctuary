import Foundation

struct SearchMatcher {
    struct Document: Sendable {
        let itemID: String
        let primaryText: String
        let secondaryText: String
        let auxiliaryText: String

        fileprivate let normalizedPrimary: String
        fileprivate let normalizedSecondary: String
        fileprivate let normalizedAuxiliary: String
        fileprivate let primaryTokens: [String]
        fileprivate let secondaryTokens: [String]
        fileprivate let auxiliaryTokens: [String]

        init(itemID: String, primaryText: String, secondaryText: String = "", auxiliaryText: String = "") {
            self.itemID = itemID
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.auxiliaryText = auxiliaryText

            normalizedPrimary = SearchMatcher.normalize(primaryText)
            normalizedSecondary = SearchMatcher.normalize(secondaryText)
            normalizedAuxiliary = SearchMatcher.normalize(auxiliaryText)
            primaryTokens = SearchMatcher.tokens(fromNormalized: normalizedPrimary)
            secondaryTokens = SearchMatcher.tokens(fromNormalized: normalizedSecondary)
            auxiliaryTokens = SearchMatcher.tokens(fromNormalized: normalizedAuxiliary)
        }
    }

    static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func rankedIDs<T>(for query: String, in documents: [T], document: (T) -> Document) -> [String] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return documents.map { document($0).itemID }
        }

        let queryTokens = tokens(fromNormalized: normalizedQuery)
        guard !queryTokens.isEmpty else {
            return documents.map { document($0).itemID }
        }

        return documents
            .compactMap { item -> (String, Int)? in
                let doc = document(item)
                guard let score = score(document: doc, query: normalizedQuery, queryTokens: queryTokens) else {
                    return nil
                }
                return (doc.itemID, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
            .map(\.0)
    }

    private static func score(document: Document, query: String, queryTokens: [String]) -> Int? {
        guard queryTokens.allSatisfy({ tokenMatches($0, in: document) }) else {
            return nil
        }

        var score = 0

        if document.normalizedPrimary == query {
            score += 500
        } else if document.normalizedPrimary.contains(query) {
            score += 220
        }

        if document.normalizedSecondary.contains(query) {
            score += 90
        }

        if document.normalizedAuxiliary.contains(query) {
            score += 45
        }

        for token in queryTokens {
            score += tokenScore(token, tokens: document.primaryTokens, exact: 80, prefix: 50)
            score += tokenScore(token, tokens: document.secondaryTokens, exact: 24, prefix: 12)
            score += tokenScore(token, tokens: document.auxiliaryTokens, exact: 10, prefix: 5)
        }

        if queryTokens.count > 1, phrasePrefixMatches(queryTokens, in: document.primaryTokens) {
            score += 140
        }

        return score
    }

    private static func tokenMatches(_ queryToken: String, in document: Document) -> Bool {
        tokenScore(queryToken, tokens: document.primaryTokens, exact: 1, prefix: 1) > 0 ||
        tokenScore(queryToken, tokens: document.secondaryTokens, exact: 1, prefix: 1) > 0 ||
        tokenScore(queryToken, tokens: document.auxiliaryTokens, exact: 1, prefix: 1) > 0
    }

    private static func tokenScore(_ queryToken: String, tokens: [String], exact: Int, prefix: Int) -> Int {
        if tokens.contains(queryToken) { return exact }
        if tokens.contains(where: { $0.hasPrefix(queryToken) }) { return prefix }
        return 0
    }

    private static func phrasePrefixMatches(_ queryTokens: [String], in tokens: [String]) -> Bool {
        guard queryTokens.count <= tokens.count else { return false }
        for start in 0...(tokens.count - queryTokens.count) {
            let window = Array(tokens[start..<(start + queryTokens.count)])
            if zip(queryTokens, window).allSatisfy({ query, candidate in candidate.hasPrefix(query) }) {
                return true
            }
        }
        return false
    }

    private static func tokens(fromNormalized value: String) -> [String] {
        value.split(separator: " ").map(String.init)
    }
}
