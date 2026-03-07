import Foundation

struct SaintDocument: Decodable {
    let id: String
    let name: String?
    let mmdd: String?
    let feast: String?
    let summary: String?
    let biography: String?
    let prayers: [String]?
    let sources: [String]?
    let photoUrl: String?
    let name_es: String?
    let name_pl: String?
    let feast_es: String?
    let feast_pl: String?
    let summary_es: String?
    let summary_pl: String?
    let biography_es: String?
    let biography_pl: String?
}

struct NovenaDocument: Decodable {
    let id: String
    let title: String?
    let title_es: String?
    let title_pl: String?
    let description: String?
    let description_es: String?
    let description_pl: String?
    let intentions: [String]?
    let intentions_es: [String]?
    let intentions_pl: [String]?
    let durationDays: Int?
    let tags: [String]?
    let image: String?
    let days: [NovenaDayDocument]?
}

struct NovenaDayDocument: Decodable {
    let day: Int?
    let title: String?
    let title_es: String?
    let title_pl: String?
    let scripture: String?
    let scripture_es: String?
    let scripture_pl: String?
    let prayer: String?
    let prayer_es: String?
    let prayer_pl: String?
    let reflection: String?
    let reflection_es: String?
    let reflection_pl: String?
}

enum ContentStore {
    enum NovenaServingStatus: String {
        case notYetStarted
        case active
        case completed
    }

    struct NovenaServingWindow {
        let start: Date
        let end: Date
        let feast: Date
    }

    private struct SaintIndexEntry: Decodable {
        let id: String
        let name: String?
        let mmdd: String?
    }

    private struct NovenaIndexEntry: Decodable {
        struct Rule: Decodable {
            let type: String?
            let month: Int?
            let day: Int?
            let anchor: String?
            let offsetDays: Int?
            let weekday: Int?
            let weekdayPolicy: String?
            let n: Int?
            let daysBefore: Int?
        }

        let id: String
        let title: String?
        let startRule: Rule?
        let feastRule: Rule?
        let durationDays: Int?
    }

    private static var saintCache: [String: SaintDocument] = [:]
    private static var novenaCache: [String: NovenaDocument] = [:]
    private static var saintIndexCache: [SaintIndexEntry]?
    private static var novenaIndexCache: [NovenaIndexEntry]?
    private static var saintIDsByMonthDayCache: [String: [String]]?
    private static var firstSaintByMonthDayCache: [String: SaintIndexEntry]?
    private static var novenaStartByMonthDayCache: [String: NovenaIndexEntry]?
    private static var novenaFeastByMonthDayCache: [String: NovenaIndexEntry]?
    private static var novenaCalendarByYearCache: [Int: [String: NovenaIndexEntry]] = [:]
    private static var resourceURLByFilenameCache: [String: URL]?
    private static let cacheLock = NSLock()

    static func prewarm(bundle: Bundle = .main) {
        // Build index/lookup caches once off the UI path.
        _ = saintIndex(bundle: bundle).count
        _ = novenaIndex(bundle: bundle).count
        buildSaintLookupsIfNeeded(bundle: bundle)
        buildNovenaLookupsIfNeeded(bundle: bundle)

        // Touch today's entries so first open on calendar/detail is instant.
        let today = Date()
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        if let saintID = firstSaintID(onMonth: month, day: day, bundle: bundle) {
            _ = saint(id: saintID, bundle: bundle)
        }
        if let novenaID = firstNovenaIDForCalendarDay(onMonth: month, day: day, bundle: bundle) {
            _ = novena(id: novenaID, bundle: bundle)
        }
    }

    static func prewarmSaintsTab(bundle: Bundle = .main) {
        buildSaintLookupsIfNeeded(bundle: bundle)
        let today = Date()
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        if let id = firstSaintID(onMonth: month, day: day, bundle: bundle) {
            _ = saint(id: id, bundle: bundle)
        }
    }

    static func prewarmNovenasTab(bundle: Bundle = .main) {
        buildNovenaLookupsIfNeeded(bundle: bundle)
        let today = Date()
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        if let id = firstNovenaIDForCalendarDay(onMonth: month, day: day, bundle: bundle) {
            _ = novena(id: id, bundle: bundle)
        }
    }

    static func saint(id: String, bundle: Bundle = .main) -> SaintDocument? {
        cacheLock.lock()
        if let cached = saintCache[id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let doc: SaintDocument = loadJSON(id: id, category: "saints", bundle: bundle) else {
            return nil
        }
        cacheLock.lock()
        saintCache[id] = doc
        cacheLock.unlock()
        return doc
    }

    static func novena(id: String, bundle: Bundle = .main) -> NovenaDocument? {
        cacheLock.lock()
        if let cached = novenaCache[id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let doc: NovenaDocument = loadJSON(id: id, category: "novenas", bundle: bundle) else {
            return nil
        }
        cacheLock.lock()
        novenaCache[id] = doc
        cacheLock.unlock()
        return doc
    }

    static func saints(onMonth month: Int, day: Int, bundle: Bundle = .main) -> [SaintDocument] {
        buildSaintLookupsIfNeeded(bundle: bundle)
        let ids = saintIDsByMonthDayCache?[monthDayKey(month: month, day: day)] ?? []

        // Preserve curated index order for same-day collisions.
        return ids.compactMap { saint(id: $0, bundle: bundle) }
    }

    static func firstSaintID(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        buildSaintLookupsIfNeeded(bundle: bundle)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return firstSaintByMonthDayCache?[monthDayKey(month: month, day: day)]?.id
    }

    static func firstSaintName(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        buildSaintLookupsIfNeeded(bundle: bundle)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return firstSaintByMonthDayCache?[monthDayKey(month: month, day: day)]?.name
    }

    static func firstSaintPhotoURLString(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        guard let id = firstSaintID(onMonth: month, day: day, bundle: bundle) else { return nil }
        return saint(id: id, bundle: bundle)?.photoUrl
    }

    static func novenaIDsStarting(onMonth month: Int, day: Int, bundle: Bundle = .main) -> [String] {
        buildNovenaLookupsIfNeeded(bundle: bundle)
        cacheLock.lock()
        let entry = novenaStartByMonthDayCache?[monthDayKey(month: month, day: day)]
        cacheLock.unlock()
        guard let entry else {
            return []
        }
        return [entry.id]
    }

    static func firstNovenaStarting(onMonth month: Int, day: Int, bundle: Bundle = .main) -> NovenaDocument? {
        guard let id = novenaIDsStarting(onMonth: month, day: day, bundle: bundle).first else {
            return nil
        }
        return novena(id: id, bundle: bundle)
    }

    static func firstNovenaForCalendarDay(onMonth month: Int, day: Int, bundle: Bundle = .main) -> NovenaDocument? {
        guard let id = firstNovenaIDForCalendarDay(onMonth: month, day: day, bundle: bundle) else {
            return nil
        }
        return novena(id: id, bundle: bundle)
    }

    static func firstNovenaIDForCalendarDay(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        let currentYear = Calendar.current.component(.year, from: Date())
        return firstNovenaIDForCalendarDay(onYear: currentYear, month: month, day: day, bundle: bundle)
    }

    static func firstNovenaTitleForCalendarDay(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        let currentYear = Calendar.current.component(.year, from: Date())
        return firstNovenaTitleForCalendarDay(onYear: currentYear, month: month, day: day, bundle: bundle)
    }

    static func firstNovenaImageURLStringForCalendarDay(onMonth month: Int, day: Int, bundle: Bundle = .main) -> String? {
        guard let id = firstNovenaIDForCalendarDay(onMonth: month, day: day, bundle: bundle) else { return nil }
        return novena(id: id, bundle: bundle)?.image
    }

    static func firstNovenaIDForCalendarDay(onYear year: Int, month: Int, day: Int, bundle: Bundle = .main) -> String? {
        let key = monthDayKey(month: month, day: day)
        let map = novenaCalendarMap(forYear: year, bundle: bundle)
        return map[key]?.id
    }

    static func firstNovenaTitleForCalendarDay(onYear year: Int, month: Int, day: Int, bundle: Bundle = .main) -> String? {
        let key = monthDayKey(month: month, day: day)
        let map = novenaCalendarMap(forYear: year, bundle: bundle)
        return map[key]?.title
    }

    static func firstNovenaImageURLStringForCalendarDay(onYear year: Int, month: Int, day: Int, bundle: Bundle = .main) -> String? {
        guard let id = firstNovenaIDForCalendarDay(onYear: year, month: month, day: day, bundle: bundle) else { return nil }
        return novena(id: id, bundle: bundle)?.image
    }

    static func novenaFeastDate(id: String, year: Int, bundle: Bundle = .main) -> Date? {
        novenaServingWindow(id: id, year: year, bundle: bundle)?.feast
    }

    static func novenaServingWindow(id: String, year: Int, bundle: Bundle = .main) -> NovenaServingWindow? {
        guard let entry = novenaIndex(bundle: bundle).first(where: { $0.id == id }) else { return nil }
        return resolvedServingWindow(for: entry, year: year, bundle: bundle)
    }

    static func novenaServingStatus(id: String, on date: Date = Date(), bundle: Bundle = .main) -> NovenaServingStatus? {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        guard let window = novenaServingWindow(id: id, year: year, bundle: bundle)
            ?? novenaServingWindow(id: id, year: year - 1, bundle: bundle)
            ?? novenaServingWindow(id: id, year: year + 1, bundle: bundle)
        else { return nil }

        if date < window.start { return .notYetStarted }
        if date > window.end { return .completed }
        return .active
    }

    private static func saintIndex(bundle: Bundle) -> [SaintIndexEntry] {
        cacheLock.lock()
        if let cache = saintIndexCache {
            cacheLock.unlock()
            return cache
        }
        cacheLock.unlock()
        let loaded: [SaintIndexEntry] = loadIndex(named: "saints_index", bundle: bundle) ?? []
        cacheLock.lock()
        saintIndexCache = loaded
        cacheLock.unlock()
        return loaded
    }

    private static func novenaIndex(bundle: Bundle) -> [NovenaIndexEntry] {
        cacheLock.lock()
        if let cache = novenaIndexCache {
            cacheLock.unlock()
            return cache
        }
        cacheLock.unlock()
        let loaded: [NovenaIndexEntry] = loadIndex(named: "novenas_index", bundle: bundle) ?? []
        cacheLock.lock()
        novenaIndexCache = loaded
        cacheLock.unlock()
        return loaded
    }

    private static func loadIndex<T: Decodable>(named name: String, bundle: Bundle) -> T? {
        let subdirs: [String?] = ["Resources/LegacyData", "LegacyData", "Resources", nil]
        for sub in subdirs {
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }
        if let url = cachedResourceURL(forFilename: "\(name).json", in: bundle),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let url = localResourceURL(relativePath: "Resources/LegacyData/\(name).json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return nil
    }

    private static func monthDayFromSaintID(_ id: String) -> (month: Int, day: Int)? {
        let prefix = String(id.prefix(5))
        let parts = prefix.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) else {
            return nil
        }
        return (month, day)
    }

    private static func monthDayFromMMDD(_ mmdd: String?) -> (month: Int, day: Int)? {
        guard let mmdd else { return nil }
        let parts = mmdd.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) else {
            return nil
        }
        return (month, day)
    }

    private static func buildSaintLookupsIfNeeded(bundle: Bundle) {
        cacheLock.lock()
        let alreadyBuilt = saintIDsByMonthDayCache != nil && firstSaintByMonthDayCache != nil
        cacheLock.unlock()
        if alreadyBuilt { return }

        var idsByDay: [String: [String]] = [:]
        var firstByDay: [String: SaintIndexEntry] = [:]
        for entry in saintIndex(bundle: bundle) {
            guard let md = monthDayFromMMDD(entry.mmdd) ?? monthDayFromSaintID(entry.id) else { continue }
            let key = monthDayKey(month: md.month, day: md.day)
            idsByDay[key, default: []].append(entry.id)
            if firstByDay[key] == nil {
                firstByDay[key] = entry
            }
        }

        cacheLock.lock()
        saintIDsByMonthDayCache = idsByDay
        firstSaintByMonthDayCache = firstByDay
        cacheLock.unlock()
    }

    private static func buildNovenaLookupsIfNeeded(bundle: Bundle) {
        cacheLock.lock()
        let alreadyBuilt = novenaStartByMonthDayCache != nil && novenaFeastByMonthDayCache != nil
        cacheLock.unlock()
        if alreadyBuilt { return }

        var startMap: [String: NovenaIndexEntry] = [:]
        var feastMap: [String: NovenaIndexEntry] = [:]
        for entry in novenaIndex(bundle: bundle) {
            if entry.startRule?.type == "fixed",
               let m = entry.startRule?.month,
               let d = entry.startRule?.day {
                let key = monthDayKey(month: m, day: d)
                if startMap[key] == nil {
                    startMap[key] = entry
                }
            }
            if entry.feastRule?.type == "fixed",
               let m = entry.feastRule?.month,
               let d = entry.feastRule?.day {
                let key = monthDayKey(month: m, day: d)
                if feastMap[key] == nil {
                    feastMap[key] = entry
                }
            }
        }

        cacheLock.lock()
        novenaStartByMonthDayCache = startMap
        novenaFeastByMonthDayCache = feastMap
        cacheLock.unlock()
    }

    private static func monthDayKey(month: Int, day: Int) -> String {
        "\(month)-\(day)"
    }

    private static func novenaCalendarMap(forYear year: Int, bundle: Bundle) -> [String: NovenaIndexEntry] {
        let calendar = Calendar(identifier: .gregorian)
        cacheLock.lock()
        if let cached = novenaCalendarByYearCache[year] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var dayMap: [String: NovenaIndexEntry] = [:]
        for entry in novenaIndex(bundle: bundle) {
            guard let window = resolvedServingWindow(for: entry, year: year, bundle: bundle) else { continue }
            let key = monthDayKey(
                month: calendar.component(.month, from: window.start),
                day: calendar.component(.day, from: window.start)
            )
            if dayMap[key] == nil { dayMap[key] = entry }
        }

        cacheLock.lock()
        novenaCalendarByYearCache[year] = dayMap
        cacheLock.unlock()
        return dayMap
    }

    private static func resolvedServingWindow(
        for entry: NovenaIndexEntry,
        year: Int,
        bundle: Bundle
    ) -> NovenaServingWindow? {
        let calendar = Calendar(identifier: .gregorian)
        guard let feastRule = entry.feastRule,
              let feast = resolveNovenaRule(feastRule, year: year, fallbackFeastRule: nil)
        else {
            return nil
        }

        var start = entry.startRule.flatMap { resolveNovenaRule($0, year: year, fallbackFeastRule: entry.feastRule) } ?? feast

        // Fixed starts that naturally belong to prior year for a next-year feast (e.g., Advent spans).
        if entry.startRule?.type == "fixed", start > feast {
            start = calendar.date(byAdding: .year, value: -1, to: start) ?? start
        }

        let feastMinusOne = calendar.date(byAdding: .day, value: -1, to: feast) ?? feast
        var end = maxDate(start, feastMinusOne)

        let sourceDuration = effectiveDurationDays(for: entry.id, entryDuration: entry.durationDays, bundle: bundle)
        if sourceDuration > 0, let byDuration = calendar.date(byAdding: .day, value: sourceDuration - 1, to: start) {
            end = minDate(end, byDuration)
        }

        return NovenaServingWindow(start: start, end: end, feast: feast)
    }

    private static func effectiveDurationDays(for id: String, entryDuration: Int?, bundle: Bundle) -> Int {
        if let docDays = novena(id: id, bundle: bundle)?.days?.count, docDays > 0 {
            return docDays
        }
        // Source index duration can be inclusive up to feast-day.
        if let entryDuration, entryDuration > 1 {
            return entryDuration - 1
        }
        return 0
    }

    private static func minDate(_ lhs: Date, _ rhs: Date) -> Date { lhs < rhs ? lhs : rhs }
    private static func maxDate(_ lhs: Date, _ rhs: Date) -> Date { lhs > rhs ? lhs : rhs }

    private static func resolveNovenaRule(
        _ rule: NovenaIndexEntry.Rule,
        year: Int,
        fallbackFeastRule: NovenaIndexEntry.Rule?
    ) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let anchors = novenaAnchors(forYear: year)

        switch rule.type {
        case "fixed":
            guard let month = rule.month, let day = rule.day else { return nil }
            return calendar.date(from: DateComponents(year: year, month: month, day: day))

        case "anchor":
            guard let anchor = rule.anchor else { return nil }
            return anchors[anchor]

        case "relative":
            guard let anchor = rule.anchor, let offset = rule.offsetDays, let base = anchors[anchor] else { return nil }
            let moved = calendar.date(byAdding: .day, value: offset, to: base) ?? base
            if let weekday = rule.weekday {
                return alignToWeekday(base: moved, targetWeekday: weekday, policy: rule.weekdayPolicy ?? "onOrAfter")
            }
            return moved

        case "nth_weekday_after":
            guard let anchor = rule.anchor, let base = anchors[anchor], let weekday = rule.weekday, let n = rule.n, n >= 1 else {
                return nil
            }
            var date = calendar.date(byAdding: .day, value: 1, to: base) ?? base
            var count = 0
            while count < n {
                if calendar.component(.weekday, from: date) - 1 == weekday {
                    count += 1
                    if count == n { return date }
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            return nil

        case "before_feast":
            guard let daysBefore = rule.daysBefore, daysBefore >= 1 else { return nil }
            let anchor = rule.anchor ?? ((fallbackFeastRule?.type == "anchor") ? fallbackFeastRule?.anchor : nil)
            if let anchor, let feast = anchors[anchor] {
                return calendar.date(byAdding: .day, value: -(daysBefore - 1), to: feast)
            }
            return nil

        default:
            return nil
        }
    }

    private static func novenaAnchors(forYear year: Int) -> [String: Date] {
        let calendar = Calendar(identifier: .gregorian)
        let easter = computeEasterSunday(year: year)
        let ashWednesday = calendar.date(byAdding: .day, value: -46, to: easter) ?? easter
        let shroveTuesday = calendar.date(byAdding: .day, value: -1, to: ashWednesday) ?? ashWednesday
        let palmSunday = calendar.date(byAdding: .day, value: -7, to: easter) ?? easter
        let holyThursday = calendar.date(byAdding: .day, value: -3, to: easter) ?? easter
        let goodFriday = calendar.date(byAdding: .day, value: -2, to: easter) ?? easter
        let holySaturday = calendar.date(byAdding: .day, value: -1, to: easter) ?? easter
        let divineMercySunday = calendar.date(byAdding: .day, value: 7, to: easter) ?? easter
        let ascensionThursday = calendar.date(byAdding: .day, value: 39, to: easter) ?? easter
        let ascensionSunday = calendar.date(byAdding: .day, value: 42, to: easter) ?? easter
        let pentecost = calendar.date(byAdding: .day, value: 49, to: easter) ?? easter
        let trinitySunday = calendar.date(byAdding: .day, value: 56, to: easter) ?? easter
        let corpusChristi = calendar.date(byAdding: .day, value: 60, to: easter) ?? easter
        let corpusChristiSunday = calendar.date(byAdding: .day, value: 63, to: easter) ?? easter
        let sacredHeart = calendar.date(byAdding: .day, value: 68, to: easter) ?? easter
        let immaculateHeart = calendar.date(byAdding: .day, value: 69, to: easter) ?? easter

        let christmas = calendar.date(from: DateComponents(year: year, month: 12, day: 25)) ?? easter
        let christmasEve = calendar.date(from: DateComponents(year: year, month: 12, day: 24)) ?? easter
        let newYearsEve = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? easter
        let maryMotherOfGod = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? easter
        let epiphany = calendar.date(from: DateComponents(year: year, month: 1, day: 6)) ?? easter
        let baptismOfTheLord = nextWeekday(onOrAfter: epiphany, weekday: 1)
        let holyFamily = holyFamilyDate(year: year)
        let advent1 = firstSundayOfAdvent(year: year)
        let christKing = calendar.date(byAdding: .day, value: -7, to: advent1) ?? advent1
        let annunciation = calendar.date(from: DateComponents(year: year, month: 3, day: 25)) ?? easter
        let assumption = calendar.date(from: DateComponents(year: year, month: 8, day: 15)) ?? easter
        let allSaints = calendar.date(from: DateComponents(year: year, month: 11, day: 1)) ?? easter
        let immaculateConception = calendar.date(from: DateComponents(year: year, month: 12, day: 8)) ?? easter

        return [
            "easter": easter,
            "ash_wednesday": ashWednesday,
            "shrove_tuesday": shroveTuesday,
            "palm_sunday": palmSunday,
            "holy_thursday": holyThursday,
            "good_friday": goodFriday,
            "holy_saturday": holySaturday,
            "divine_mercy_sunday": divineMercySunday,
            "ascension_thursday": ascensionThursday,
            "ascension_sunday": ascensionSunday,
            "pentecost": pentecost,
            "trinity_sunday": trinitySunday,
            "corpus_christi": corpusChristi,
            "corpus_christi_sunday": corpusChristiSunday,
            "sacred_heart": sacredHeart,
            "immaculate_heart": immaculateHeart,
            "christmas": christmas,
            "christmas_eve": christmasEve,
            "mary_mother_of_god": maryMotherOfGod,
            "new_years_eve": newYearsEve,
            "epiphany": epiphany,
            "baptism_of_the_lord": baptismOfTheLord,
            "holy_family": holyFamily,
            "advent_1": advent1,
            "christ_king": christKing,
            "annunciation": annunciation,
            "assumption": assumption,
            "all_saints": allSaints,
            "immaculate_conception": immaculateConception,
        ]
    }

    private static func computeEasterSunday(year: Int) -> Date {
        // Gregorian computus (stable baseline algorithm used by the app).
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static func nextWeekday(onOrAfter date: Date, weekday: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var candidate = date
        while calendar.component(.weekday, from: candidate) != weekday {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func firstSundayOfAdvent(year: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let nov27 = calendar.date(from: DateComponents(year: year, month: 11, day: 27)) ?? Date()
        return nextWeekday(onOrAfter: nov27, weekday: 1)
    }

    private static func holyFamilyDate(year: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let dec26 = calendar.date(from: DateComponents(year: year, month: 12, day: 26)) ?? Date()
        for i in 0...5 {
            if let d = calendar.date(byAdding: .day, value: i, to: dec26),
               calendar.component(.weekday, from: d) == 1 {
                return d
            }
        }
        return calendar.date(from: DateComponents(year: year, month: 12, day: 30)) ?? dec26
    }

    private static func alignToWeekday(base: Date, targetWeekday: Int, policy: String) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var candidate = base
        let target = targetWeekday + 1 // json uses 0..6, Calendar uses 1..7
        switch policy {
        case "onOrBefore":
            while calendar.component(.weekday, from: candidate) != target {
                candidate = calendar.date(byAdding: .day, value: -1, to: candidate) ?? candidate
            }
            return candidate
        default:
            while calendar.component(.weekday, from: candidate) != target {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate
        }
    }

    private static func loadJSON<T: Decodable>(id: String, category: String, bundle: Bundle) -> T? {
        let candidates = [
            "Resources/LegacyData/\(category)",
            "LegacyData/\(category)",
            category,
        ]

        for subdirectory in candidates {
            if let url = bundle.url(forResource: id, withExtension: "json", subdirectory: subdirectory),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }

        // Fallback for builds where JSON resources are flattened by Xcode.
        if let url = cachedResourceURL(forFilename: "\(id).json", in: bundle),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        if let url = localResourceURL(relativePath: "Resources/LegacyData/\(category)/\(id).json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        return nil
    }

    private static func cachedResourceURL(forFilename filename: String, in bundle: Bundle) -> URL? {
        cacheLock.lock()
        let needsBuild = (resourceURLByFilenameCache == nil)
        cacheLock.unlock()
        if needsBuild {
            buildResourceURLCache(bundle: bundle)
        }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return resourceURLByFilenameCache?[filename]
    }

    private static func buildResourceURLCache(bundle: Bundle) {
        cacheLock.lock()
        if resourceURLByFilenameCache != nil {
            cacheLock.unlock()
            return
        }
        cacheLock.unlock()

        var map: [String: URL] = [:]
        if let enumerator = FileManager.default.enumerator(
            at: bundle.bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                // Keep the first hit; the bundle usually has unique JSON filenames for ids.
                if map[name] == nil {
                    map[name] = url
                }
            }
        }
        cacheLock.lock()
        resourceURLByFilenameCache = map
        cacheLock.unlock()
    }

    private static func localResourceURL(relativePath: String) -> URL? {
        let fm = FileManager.default
        let envRoot = ProcessInfo.processInfo.environment["SANCTUARY_RESOURCE_ROOT"]
        let cwd = fm.currentDirectoryPath
        let candidates = [envRoot, cwd].compactMap { $0 }
        for root in candidates {
            let direct = URL(fileURLWithPath: root).appendingPathComponent(relativePath)
            if fm.fileExists(atPath: direct.path) {
                return direct
            }
            let nested = URL(fileURLWithPath: root).appendingPathComponent("Sanctuary").appendingPathComponent(relativePath)
            if fm.fileExists(atPath: nested.path) {
                return nested
            }
        }
        return nil
    }
}
