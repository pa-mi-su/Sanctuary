import Foundation

struct RelatedNovena: Hashable, Identifiable {
    let id: String
    let title: String
    let score: Double
}

struct RelatedSaint: Hashable, Identifiable {
    let id: String
    let name: String
    let score: Double
}

enum RelationResolver {
    private struct SaintIndexEntry: Decodable {
        let id: String
        let name: String
    }

    private struct NovenaIndexEntry: Decodable {
        let id: String
        let title: String
    }

    private static let ambiguousSingle: Set<String> = [
        "john", "joseph", "mary", "paul", "peter", "thomas", "james", "francis", "elizabeth", "catherine", "anthony", "nicholas", "gregory", "martin", "vincent"
    ]

    private static let saintManualLinks: [String: [String]] = [
        "03-19_saint_joseph": ["st_joseph", "st_joseph_the_worker", "holy_cloak_of_st_joseph"],
        "03-20_saint_joachim": ["st_joachim"],
        "07-26_saints_joachim_and_ann": ["st_joachim", "sts_joachim_and_anne"],
        "07-26_saints_joachim_and_anne": ["st_joachim", "sts_joachim_and_anne"],
        "07-16_our_lady_of_mount_carmel": ["our_lady_of_mt_carmel"],
        "02-11_our_lady_of_lourdes": ["our_lady_of_lourdes"],
        "12-12_our_lady_of_guadalupe": ["our_lady_of_guadalupe"],
        "08-15_assumption_of_mary": ["assumption"],
        "03-17_saint_patrick_389_461": ["st_patrick"],
        "01-21_saint_agnes": ["st_agnes"],
        "01-20_saint_sebastian": ["st_sebastian"],
        "01-28_saint_thomas_aquinas": ["st_thomas_aquinas"],
        "01-25_the_conversion_of_saint_paul_the_apostle": ["st_paul_of_the_cross"],
        "06-21_saint_aloysius_gonzaga": ["st_aloysius_gonzaga"],
        "04-05_saint_vincent_ferrer": ["st_vincent_ferrer"],
        "09-27_saint_vincent_de_paul_1581_1660": ["st_vincent_de_paul"],
    ]

    private static let saintsIndex: [SaintIndexEntry] = loadJSON(named: "saints_index") ?? []
    private static let novenasIndex: [NovenaIndexEntry] = loadJSON(named: "novenas_index") ?? []
    private static let novenaByID: [String: NovenaIndexEntry] = Dictionary(uniqueKeysWithValues: novenasIndex.map { ($0.id, $0) })
    private static let saintByID: [String: SaintIndexEntry] = Dictionary(uniqueKeysWithValues: saintsIndex.map { ($0.id, $0) })
    private static let manualSaintsByNovena: [String: [String]] = {
        var out: [String: [String]] = [:]
        for (saintID, novenaIDs) in saintManualLinks {
            for novenaID in novenaIDs {
                out[novenaID, default: []].append(saintID)
            }
        }
        return out
    }()
    private static var saintToNovenasCache: [String: [RelatedNovena]] = [:]
    private static var novenaToSaintsCache: [String: [RelatedSaint]] = [:]
    private static let cacheLock = NSLock()

    static func prewarm() {
        _ = saintsIndex.count
        _ = novenasIndex.count
    }

    static func relatedNovenas(forSaintID saintID: String) -> [RelatedNovena] {
        cacheLock.lock()
        if let cached = saintToNovenasCache[saintID] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let saint = saintByID[saintID] else { return [] }

        let related = computeLinksForSaint(
            saintID: saint.id,
            saintName: saint.name,
            novenasIndex: novenasIndex,
            novenaByID: novenaByID
        )
        cacheLock.lock()
        saintToNovenasCache[saintID] = related
        cacheLock.unlock()
        return related
    }

    static func relatedSaints(forNovenaID novenaID: String) -> [RelatedSaint] {
        cacheLock.lock()
        if let cached = novenaToSaintsCache[novenaID] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let novena = novenaByID[novenaID] else { return [] }

        var candidates: [RelatedSaint] = saintsIndex
            .map { saint in
                RelatedSaint(
                    id: saint.id,
                    name: saint.name,
                    score: scoreLink(saintName: saint.name, novena: novena)
                )
            }
            .filter { $0.score >= 0.9 }

        for manualSaintID in manualSaintsByNovena[novenaID] ?? [] {
            guard let saint = saintByID[manualSaintID] else { continue }
            if !candidates.contains(where: { $0.id == manualSaintID }) {
                candidates.append(RelatedSaint(id: manualSaintID, name: saint.name, score: 9))
            }
        }

        var dedup: [String: RelatedSaint] = [:]
        for saint in candidates {
            let key = cleanSaintName(saint.name)
            if let existing = dedup[key], existing.score > saint.score { continue }
            dedup[key] = saint
        }

        let resolved = dedup.values.sorted {
            if $0.score == $1.score { return $0.name < $1.name }
            return $0.score > $1.score
        }
        .prefix(5)
        .map { $0 }

        cacheLock.lock()
        novenaToSaintsCache[novenaID] = resolved
        cacheLock.unlock()
        return resolved
    }

    private static func computeLinksForSaint(
        saintID: String,
        saintName: String,
        novenasIndex: [NovenaIndexEntry],
        novenaByID: [String: NovenaIndexEntry]
    ) -> [RelatedNovena] {
        let manual = (saintManualLinks[saintID] ?? []).compactMap { id -> RelatedNovena? in
            guard let novena = novenaByID[id] else { return nil }
            return RelatedNovena(id: novena.id, title: novena.title, score: 9)
        }

        let computed = novenasIndex
            .map { novena in
                RelatedNovena(
                    id: novena.id,
                    title: novena.title,
                    score: scoreLink(saintName: saintName, novena: novena)
                )
            }
            .filter { $0.score >= 0.9 }
            .sorted {
                if $0.score == $1.score { return $0.title < $1.title }
                return $0.score > $1.score
            }
            .prefix(4)

        var dedup: [String: RelatedNovena] = [:]
        for item in manual + computed {
            if dedup[item.id] == nil {
                dedup[item.id] = item
            }
        }
        return Array(dedup.values).prefix(4).map { $0 }
    }

    private static func scoreLink(saintName: String, novena: NovenaIndexEntry) -> Double {
        let saint = cleanSaintName(saintName)
        let saintTokens = tokens(saint)
        guard !saintTokens.isEmpty else { return 0 }

        let hay = normalize("\(novena.title) \(novena.id.replacingOccurrences(of: "_", with: " "))")
        let novTokens = tokens(hay)
        let overlap = saintTokens.filter { novTokens.contains($0) }.count

        let tokenScore = Double(overlap) / Double(max(1, saintTokens.count))
        let saintPhrase = normalize(saint)
        let containsPhrase = hay.contains(saintPhrase)
        let idContains = novena.id.contains(compactSlug(saint))

        var score = tokenScore * 0.9 + (containsPhrase ? 0.5 : 0) + (idContains ? 0.4 : 0)

        if saintTokens.count == 1, let tok = saintTokens.first, ambiguousSingle.contains(tok) {
            let exactID = novena.id == "st_\(tok)" || novena.id == tok
            if !exactID { return 0 }
            score += 0.2
        }

        return score
    }

    private static func cleanSaintName(_ name: String) -> String {
        var s = normalize(name)
        let removals = ["st", "saint", "saints", "blessed", "venerable", "pope", "martyr", "virgin", "apostle", "abbot", "bishop", "doctor", "religious", "the", "of"]
        for token in removals {
            s = s.replacingOccurrences(of: "\\b\(token)\\b", with: " ", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: "\\b\\d{3,4}\\b", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if let comma = s.split(separator: ",").first {
            return String(comma).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    private static func compactSlug(_ s: String) -> String {
        normalize(s).replacingOccurrences(of: " ", with: "_")
    }

    private static func tokens(_ s: String) -> [String] {
        let stop: Set<String> = ["the", "of", "and", "our", "lady", "saint", "st", "blessed", "venerable", "holy"]
        return normalize(s)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !stop.contains($0) }
    }

    private static func normalize(_ s: String) -> String {
        s
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadJSON<T: Decodable>(named name: String) -> T? {
        let candidates: [String?] = ["Resources/LegacyData", "LegacyData", "Resources", nil]
        for sub in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }
        guard let enumerator = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let target = "\(name).json"
        for case let url as URL in enumerator where url.lastPathComponent == target {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }
        return nil
    }
}
