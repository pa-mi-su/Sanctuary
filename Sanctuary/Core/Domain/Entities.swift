import Foundation

enum ContentLocale: String, Codable, CaseIterable, Sendable {
    case en
    case es
    case pl
}

struct LocalizedText: Codable, Hashable, Sendable {
    let locale: ContentLocale
    let value: String
}

struct Saint: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let feastMonth: Int
    let feastDay: Int
    let imageURL: URL?
    let tags: [String]
    let patronages: [String]
    let feastLabelByLocale: [ContentLocale: String]
    let summaryByLocale: [ContentLocale: String]
    let biographyByLocale: [ContentLocale: String]
    let prayersByLocale: [ContentLocale: [String]]
    let sources: [String]
}

struct NovenaDay: Codable, Hashable, Sendable {
    let dayNumber: Int
    let titleByLocale: [ContentLocale: String]
    let scriptureByLocale: [ContentLocale: String]
    let prayerByLocale: [ContentLocale: String]
    let reflectionByLocale: [ContentLocale: String]
    let bodyByLocale: [ContentLocale: String]
}

struct Novena: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let titleByLocale: [ContentLocale: String]
    let descriptionByLocale: [ContentLocale: String]
    let durationDays: Int
    let tags: [String]
    let imageURL: URL?
    let days: [NovenaDay]
}

struct Prayer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let category: String
    let titleByLocale: [ContentLocale: String]
    let bodyByLocale: [ContentLocale: String]
    let tags: [String]
}

enum LiturgicalSeason: String, Codable, CaseIterable, Sendable {
    case advent
    case christmas
    case lent
    case easter
    case ordinary
}

struct LiturgicalDay: Codable, Hashable, Sendable {
    let date: Date
    let season: LiturgicalSeason
    let rank: String
    let observances: [String]
    let readingURL: URL?
}

enum FavoriteItemType: String, Codable, CaseIterable, Sendable {
    case saint
    case novena
    case prayer
}

struct UserFavorite: Codable, Hashable, Sendable {
    let userID: String
    let itemType: FavoriteItemType
    let itemID: String
    let createdAt: Date
}

enum CommitmentStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
}

struct ReminderConfig: Codable, Hashable, Sendable {
    let enabled: Bool
    let morningHour: Int?
    let eveningHour: Int?
    let timeZoneID: String
}

struct UserNovenaCommitment: Codable, Hashable, Sendable {
    let userID: String
    let novenaID: String
    let startedAt: Date
    let currentDay: Int
    let completedDays: [Int]
    let reminder: ReminderConfig
    let status: CommitmentStatus
    let updatedAt: Date
}

enum LiturgicalCalendarEngine {
    private struct Entry: Hashable, Sendable {
        let rank: String
        let season: LiturgicalSeason
        let rankType: String
    }

    private final class CacheStore: @unchecked Sendable {
        private var byYear: [Int: [String: Entry]] = [:]
        private let lock = NSLock()

        func entries(for year: Int, build: (Int) -> [String: Entry]) -> [String: Entry] {
            lock.lock()
            if let cached = byYear[year] {
                lock.unlock()
                return cached
            }
            lock.unlock()

            let computed = build(year)

            lock.lock()
            byYear[year] = computed
            lock.unlock()
            return computed
        }
    }

    private static let cacheStore = CacheStore()
    private static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        return value
    }()
    private static let weekdayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    private static let rankPriority: [String: Int] = [
        "Triduum": 6,
        "Solemnity": 5,
        "Sunday": 4,
        "Feast": 3,
        "Memorial": 2,
        "Optional Memorial": 1,
        "Weekday": 0,
    ]
    private static let debugValidation: Void = {
        #if DEBUG
            // Validate Gregorian computus and weekday alignment across a broad range.
            for year in 1900...4099 {
                guard let easter = easterSunday(year: year) else {
                    assertionFailure("LiturgicalCalendarEngine: Easter computation failed for \(year)")
                    return
                }
                let easterWeekday = calendar.component(.weekday, from: easter)
                if easterWeekday != 1 {
                    assertionFailure("LiturgicalCalendarEngine: Easter is not Sunday for \(year)")
                    return
                }
                let goodFriday = addDays(easter, -2)
                let goodFridayWeekday = calendar.component(.weekday, from: goodFriday)
                if goodFridayWeekday != 6 {
                    assertionFailure("LiturgicalCalendarEngine: Good Friday is not Friday for \(year)")
                    return
                }
            }
        #endif
    }()

    static func day(for date: Date) -> LiturgicalDay {
        _ = debugValidation
        let normalized = normalize(date)
        let key = keyFor(normalized)
        let year = calendar.component(.year, from: normalized)
        let entry = entries(for: year)[key] ?? fallbackEntry(for: normalized)
        return LiturgicalDay(
            date: normalized,
            season: entry.season,
            rank: entry.rank,
            observances: [entry.rank],
            readingURL: URL(string: usccbReadingURL(for: normalized))
        )
    }

    static func readingURL(for date: Date) -> URL? {
        URL(string: usccbReadingURL(for: normalize(date)))
    }

    static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? Date()
    }

    private static func entries(for year: Int) -> [String: Entry] {
        cacheStore.entries(for: year, build: buildYearEntries)
    }

    private static func buildYearEntries(year: Int) -> [String: Entry] {
        var entries: [String: Entry] = [:]
        guard let easter = easterSunday(year: year) else { return entries }

        let ashWednesday = addDays(easter, -46)
        let palmSunday = addDays(easter, -7)
        let holyThursday = addDays(easter, -3)
        let goodFriday = addDays(easter, -2)
        let holySaturday = addDays(easter, -1)
        let pentecost = addDays(easter, 49)
        let christmas = makeDate(year: year, month: 12, day: 25)
        let advent1 = firstSundayOfAdvent(year: year)
        let christTheKing = addDays(advent1, -7)
        let baptism = baptismOfTheLord(year: year)
        let ordinaryPart1Start = addDays(baptism, 1)

        addEntry(to: &entries, date: makeDate(year: year, month: 1, day: 1), rank: "Mary, the Holy Mother of God", season: .christmas, rankType: "Solemnity")
        addEntry(to: &entries, date: makeDate(year: year, month: 1, day: 6), rank: "Epiphany of the Lord", season: .christmas, rankType: "Solemnity")
        addEntry(to: &entries, date: baptism, rank: "Baptism of the Lord", season: .christmas, rankType: "Feast")

        addEntry(to: &entries, date: ashWednesday, rank: "Ash Wednesday", season: .lent, rankType: "Weekday")
        let lent1 = addDays(ashWednesday, 4)
        addEntry(to: &entries, date: lent1, rank: "First Sunday of Lent", season: .lent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(lent1, 7), rank: "Second Sunday of Lent", season: .lent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(lent1, 14), rank: "Third Sunday of Lent", season: .lent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(lent1, 21), rank: "Fourth Sunday of Lent (Laetare Sunday)", season: .lent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(lent1, 28), rank: "Fifth Sunday of Lent", season: .lent, rankType: "Sunday")
        addEntry(to: &entries, date: palmSunday, rank: "Palm Sunday of the Passion of the Lord", season: .lent, rankType: "Sunday")
        // Keep Triduum in Lent for this app's 5-season legend model.
        // Easter season coloring starts on Easter Sunday.
        addEntry(to: &entries, date: holyThursday, rank: "Holy Thursday (Evening Mass of the Lord’s Supper)", season: .lent, rankType: "Triduum")
        addEntry(to: &entries, date: goodFriday, rank: "Good Friday of the Passion of the Lord", season: .lent, rankType: "Triduum")
        addEntry(to: &entries, date: holySaturday, rank: "Holy Saturday", season: .lent, rankType: "Triduum")
        addEntry(to: &entries, date: easter, rank: "Easter Sunday of the Resurrection of the Lord", season: .easter, rankType: "Solemnity")
        for offset in 1 ... 6 {
            addEntry(to: &entries, date: addDays(easter, offset), rank: "Easter Octave (Day \(offset + 1))", season: .easter, rankType: "Solemnity")
        }
        addEntry(to: &entries, date: addDays(easter, 7), rank: "Second Sunday of Easter (Divine Mercy Sunday)", season: .easter, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(easter, 39), rank: "Ascension of the Lord (Thursday)", season: .easter, rankType: "Solemnity")
        addEntry(to: &entries, date: addDays(easter, 42), rank: "Ascension of the Lord (Transferred to Sunday)", season: .easter, rankType: "Solemnity")
        addEntry(to: &entries, date: pentecost, rank: "Pentecost Sunday", season: .easter, rankType: "Solemnity")

        let dayBeforeAsh = addDays(ashWednesday, -1)
        let otPart1FirstSunday = sundayOnOrAfter(ordinaryPart1Start)
        let otPart1LastSunday = sundayOnOrBefore(dayBeforeAsh)
        var sunday = otPart1FirstSunday
        while sunday <= otPart1LastSunday {
            let week = 1 + (daysBetween(start: ordinaryPart1Start, end: sunday) / 7)
            let sundayNumber = week + 1
            addEntry(to: &entries, date: sunday, rank: "\(ordinal(sundayNumber)) Sunday in Ordinary Time", season: .ordinary, rankType: "Sunday")
            sunday = addDays(sunday, 7)
        }

        let ordinaryPart2Start = addDays(pentecost, 1)
        let lastOTWeekBeforeLent = 1 + (daysBetween(start: ordinaryPart1Start, end: dayBeforeAsh) / 7)
        let ordinaryPart2BaseWeek = lastOTWeekBeforeLent + 1
        sunday = sundayOnOrAfter(ordinaryPart2Start)
        while sunday <= christTheKing {
            let week = ordinaryPart2BaseWeek + (daysBetween(start: ordinaryPart2Start, end: sunday) / 7)
            let sundayNumber = min(34, week + 1)
            addEntry(to: &entries, date: sunday, rank: "\(ordinal(sundayNumber)) Sunday in Ordinary Time", season: .ordinary, rankType: "Sunday")
            sunday = addDays(sunday, 7)
        }

        addEntry(to: &entries, date: addDays(easter, 56), rank: "Trinity Sunday", season: .ordinary, rankType: "Solemnity")
        addEntry(to: &entries, date: addDays(easter, 60), rank: "The Most Holy Body and Blood of Christ (Corpus Christi) — Thursday", season: .ordinary, rankType: "Solemnity")
        addEntry(to: &entries, date: addDays(easter, 63), rank: "The Most Holy Body and Blood of Christ (Corpus Christi) — Sunday", season: .ordinary, rankType: "Solemnity")
        addEntry(to: &entries, date: addDays(easter, 68), rank: "Most Sacred Heart of Jesus", season: .ordinary, rankType: "Solemnity")
        addEntry(to: &entries, date: addDays(easter, 69), rank: "Immaculate Heart of Mary", season: .ordinary, rankType: "Memorial")

        addEntry(to: &entries, date: advent1, rank: "First Sunday of Advent", season: .advent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(advent1, 7), rank: "Second Sunday of Advent", season: .advent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(advent1, 14), rank: "Third Sunday of Advent (Gaudete Sunday)", season: .advent, rankType: "Sunday")
        addEntry(to: &entries, date: addDays(advent1, 21), rank: "Fourth Sunday of Advent", season: .advent, rankType: "Sunday")
        addEntry(to: &entries, date: christTheKing, rank: "Our Lord Jesus Christ, King of the Universe (Christ the King)", season: .ordinary, rankType: "Solemnity")
        addEntry(to: &entries, date: christmas, rank: "The Nativity of the Lord (Christmas)", season: .christmas, rankType: "Solemnity")

        var month = 1
        while month <= 12 {
            let maxDay = daysInMonth(year: year, month: month)
            var day = 1
            while day <= maxDay {
                let date = makeDate(year: year, month: month, day: day)
                let key = keyFor(date)
                if entries[key] == nil {
                    entries[key] = fallbackEntry(for: date)
                }
                day += 1
            }
            month += 1
        }
        return entries
    }

    private static func addEntry(
        to entries: inout [String: Entry],
        date: Date,
        rank: String,
        season: LiturgicalSeason,
        rankType: String
    ) {
        let key = keyFor(date)
        let candidate = Entry(rank: rank, season: season, rankType: rankType)
        guard let existing = entries[key] else {
            entries[key] = candidate
            return
        }
        let existingPriority = rankPriority[existing.rankType] ?? 0
        let candidatePriority = rankPriority[rankType] ?? 0
        if candidatePriority >= existingPriority {
            entries[key] = candidate
        }
    }

    private static func fallbackEntry(for date: Date) -> Entry {
        let season = seasonForDate(date: date)
        let weekdayIndex = max(1, min(7, calendar.component(.weekday, from: date))) - 1
        return Entry(
            rank: "\(weekdayNames[weekdayIndex]) of \(seasonDisplayName(season))",
            season: season,
            rankType: "Weekday"
        )
    }

    private static func usccbReadingURL(for date: Date) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year2 = calendar.component(.year, from: date) % 100
        return String(format: "https://bible.usccb.org/bible/readings/%02d%02d%02d.cfm", month, day, year2)
    }

    private static func keyFor(_ date: Date) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func normalize(_ date: Date) -> Date {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return makeDate(year: year, month: month, day: day)
    }

    private static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func daysBetween(start: Date, end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private static func sundayOnOrAfter(_ date: Date) -> Date {
        nextWeekday(date, weekday: 1, includeSameDay: true)
    }

    private static func sundayOnOrBefore(_ date: Date) -> Date {
        previousWeekday(date, weekday: 1, includeSameDay: true)
    }

    private static func nextWeekday(_ date: Date, weekday: Int, includeSameDay: Bool) -> Date {
        let current = calendar.component(.weekday, from: date)
        var delta = (weekday - current + 7) % 7
        if delta == 0, !includeSameDay { delta = 7 }
        return addDays(date, delta)
    }

    private static func previousWeekday(_ date: Date, weekday: Int, includeSameDay: Bool) -> Date {
        let current = calendar.component(.weekday, from: date)
        var delta = (current - weekday + 7) % 7
        if delta == 0, !includeSameDay { delta = 7 }
        return addDays(date, -delta)
    }

    private static func easterSunday(year: Int) -> Date? {
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
        return makeDate(year: year, month: month, day: day)
    }

    private static func firstSundayOfAdvent(year: Int) -> Date {
        sundayOnOrAfter(makeDate(year: year, month: 11, day: 27))
    }

    private static func baptismOfTheLord(year: Int) -> Date {
        nextWeekday(makeDate(year: year, month: 1, day: 6), weekday: 1, includeSameDay: false)
    }

    // Central seasonal boundaries used by the liturgical engine.
    // Handles both Christmas windows correctly:
    // - Dec 25 (year N) through Baptism of the Lord (year N+1)
    // - Dec 25 (year N-1) through Baptism of the Lord (year N)
    private static func seasonForDate(date: Date) -> LiturgicalSeason {
        let year = calendar.component(.year, from: date)

        let advent1 = firstSundayOfAdvent(year: year)
        let christmasCurrent = makeDate(year: year, month: 12, day: 25)
        let christmasPrevious = makeDate(year: year - 1, month: 12, day: 25)
        let baptismCurrent = baptismOfTheLord(year: year)
        let baptismNext = baptismOfTheLord(year: year + 1)

        if date >= advent1, date < christmasCurrent { return .advent }
        if (date >= christmasPrevious && date <= baptismCurrent) ||
            (date >= christmasCurrent && date <= baptismNext) {
            return .christmas
        }

        let easter = easterSunday(year: year) ?? date
        let ashWednesday = addDays(easter, -46)
        let pentecost = addDays(easter, 49)
        if date >= ashWednesday, date < easter { return .lent }
        if date >= easter, date <= pentecost { return .easter }
        return .ordinary
    }

    private static func seasonDisplayName(_ season: LiturgicalSeason) -> String {
        switch season {
        case .advent: return "Advent"
        case .christmas: return "Christmas"
        case .lent: return "Lent"
        case .easter: return "Easter"
        case .ordinary: return "Ordinary Time"
        }
    }

    private static func ordinal(_ n: Int) -> String {
        let words = [
            "", "First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth",
            "Tenth", "Eleventh", "Twelfth", "Thirteenth", "Fourteenth", "Fifteenth", "Sixteenth",
            "Seventeenth", "Eighteenth", "Nineteenth", "Twentieth", "Twenty-First", "Twenty-Second",
            "Twenty-Third", "Twenty-Fourth", "Twenty-Fifth", "Twenty-Sixth", "Twenty-Seventh",
            "Twenty-Eighth", "Twenty-Ninth", "Thirtieth", "Thirty-First", "Thirty-Second",
            "Thirty-Third", "Thirty-Fourth",
        ]
        if n >= 1, n < words.count { return words[n] }
        return "\(n)th"
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }
}
