import Foundation

actor LocalContentRepository: ContentRepository {
    private struct SaintIndexEntry: Decodable {
        let id: String
    }

    private struct NovenaIndexEntry: Decodable {
        let id: String
    }

    private struct PrayerIndexEntry: Decodable {
        let id: String
    }

    private struct LegacyPrayerDocument: Decodable {
        struct Source: Decodable {
            let type: String?
        }

        let id: String
        let title: String?
        let title_es: String?
        let title_pl: String?
        let prayerText: String?
        let prayerText_es: String?
        let prayerText_pl: String?
        let source: Source?
    }

    private let bundle: Bundle
    private let fallbackToSeed: Bool
    private var saints: [Saint]
    private var novenas: [Novena]
    private var prayers: [Prayer]
    private var liturgicalDays: [String: LiturgicalDay]
    private var didLoadPrimaryContent = false
    private var didLoadSupplementaryContent = false

    init(bundle: Bundle = .main, fallbackToSeed: Bool = true) {
        self.bundle = bundle
        self.fallbackToSeed = fallbackToSeed
        // Keep init lightweight for startup responsiveness.
        self.saints = fallbackToSeed ? LocalSeedData.saints : []
        self.novenas = fallbackToSeed ? LocalSeedData.novenas : []
        self.prayers = fallbackToSeed ? LocalSeedData.prayers : []
        self.liturgicalDays = fallbackToSeed ? LocalSeedData.liturgicalDays : [:]
    }

    func listSaints(
        locale: ContentLocale,
        feastDate: FeastDateFilter?,
        query: String?
    ) async throws -> [Saint] {
        await ensurePrimaryContentLoaded()
        let normalized = normalize(query)
        return saints
            .filter { saint in
                let matchesDate: Bool
                if let feastDate {
                    matchesDate = saint.feastMonth == feastDate.month && saint.feastDay == feastDate.day
                } else {
                    matchesDate = true
                }

                guard matchesDate else { return false }
                guard let normalized else { return true }

                let name = saint.displayName(locale: locale).lowercased()
                let biography = saint.biographyByLocale[locale]?.lowercased() ?? ""
                return name.contains(normalized) || biography.contains(normalized)
            }
            .sorted { $0.displayName(locale: locale) < $1.displayName(locale: locale) }
    }

    func fetchSaint(slug: String, locale _: ContentLocale) async throws -> Saint? {
        await ensurePrimaryContentLoaded()
        return saints.first { $0.slug == slug }
    }

    func listNovenas(
        locale: ContentLocale,
        tag: String?,
        query: String?
    ) async throws -> [Novena] {
        await ensurePrimaryContentLoaded()
        let normalizedTag = normalize(tag)
        let normalizedQuery = normalize(query)

        return novenas
            .filter { novena in
                let matchesTag: Bool
                if let normalizedTag {
                    matchesTag = novena.tags.contains { $0.lowercased() == normalizedTag }
                } else {
                    matchesTag = true
                }

                guard matchesTag else { return false }
                guard let normalizedQuery else { return true }

                let title = novena.titleByLocale[locale]?.lowercased() ?? ""
                let details = novena.descriptionByLocale[locale]?.lowercased() ?? ""
                return title.contains(normalizedQuery) || details.contains(normalizedQuery)
            }
            .sorted {
                let lhs = $0.titleByLocale[locale] ?? ""
                let rhs = $1.titleByLocale[locale] ?? ""
                return lhs < rhs
            }
    }

    func fetchNovena(slug: String, locale _: ContentLocale) async throws -> Novena? {
        await ensurePrimaryContentLoaded()
        return novenas.first { $0.slug == slug }
    }

    func listPrayers(
        locale: ContentLocale,
        category: String?,
        query: String?
    ) async throws -> [Prayer] {
        await ensureSupplementaryContentLoaded()
        let normalizedCategory = normalize(category)
        let normalizedQuery = normalize(query)

        return prayers
            .filter { prayer in
                let matchesCategory: Bool
                if let normalizedCategory {
                    matchesCategory = prayer.category.lowercased() == normalizedCategory
                } else {
                    matchesCategory = true
                }

                guard matchesCategory else { return false }
                guard let normalizedQuery else { return true }

                let title = prayer.titleByLocale[locale]?.lowercased() ?? ""
                let body = prayer.bodyByLocale[locale]?.lowercased() ?? ""
                return title.contains(normalizedQuery) || body.contains(normalizedQuery)
            }
            .sorted {
                let lhs = $0.titleByLocale[locale] ?? ""
                let rhs = $1.titleByLocale[locale] ?? ""
                return lhs < rhs
            }
    }

    func fetchLiturgicalDay(for date: Date) async throws -> LiturgicalDay? {
        await ensureSupplementaryContentLoaded()
        return LiturgicalCalendarEngine.day(for: date)
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func ensurePrimaryContentLoaded() async {
        guard !didLoadPrimaryContent else { return }

        let loader = LocalBundleJSONLoader(bundle: bundle)
        let parsedSaints = Self.loadSourceSaints(loader: loader)
        let parsedNovenas = Self.loadSourceNovenas(loader: loader)

        if !parsedSaints.isEmpty { saints = parsedSaints }
        if !parsedNovenas.isEmpty { novenas = parsedNovenas }
        didLoadPrimaryContent = true
    }

    private func ensureSupplementaryContentLoaded() async {
        guard !didLoadSupplementaryContent else { return }
        let loader = LocalBundleJSONLoader(bundle: bundle)
        let parsedPrayers = Self.loadNormalizedPrayers(loader: loader)
        let parsedLiturgicalDays = Self.loadNormalizedLiturgicalDays(loader: loader)
        if !parsedPrayers.isEmpty { prayers = parsedPrayers }
        if !parsedLiturgicalDays.isEmpty { liturgicalDays = parsedLiturgicalDays }
        didLoadSupplementaryContent = true
    }

    private static func loadNormalizedPrayers(loader: LocalBundleJSONLoader) -> [Prayer] {
        let normalized = (try? loader.load("prayers", as: [Prayer].self, subdirectoryCandidates: [nil, "Resources"])) ?? []
        if !normalized.isEmpty {
            return normalized
        }

        let indexSubdirs: [String?] = ["Resources/LegacyData", "LegacyData", "Resources", nil]
        let docSubdirs: [String?] = ["Resources/LegacyData/prayers", "LegacyData/prayers", "prayers", nil]
        guard let index = try? loader.load("prayers_index", as: [PrayerIndexEntry].self, subdirectoryCandidates: indexSubdirs) else {
            return []
        }

        return index.compactMap { entry in
            guard let doc = try? loader.load(entry.id, as: LegacyPrayerDocument.self, subdirectoryCandidates: docSubdirs) else {
                return nil
            }

            let titleEn = firstNonEmpty(doc.title, fallback: entry.id)
            let bodyEn = firstNonEmpty(doc.prayerText, fallback: "")
            let category = firstNonEmpty(doc.source?.type, fallback: "general")

            return Prayer(
                id: doc.id,
                slug: doc.id,
                category: category,
                titleByLocale: [
                    .en: titleEn,
                    .es: firstNonEmpty(doc.title_es, fallback: titleEn),
                    .pl: firstNonEmpty(doc.title_pl, fallback: titleEn),
                ],
                bodyByLocale: [
                    .en: bodyEn,
                    .es: firstNonEmpty(doc.prayerText_es, fallback: bodyEn),
                    .pl: firstNonEmpty(doc.prayerText_pl, fallback: bodyEn),
                ],
                tags: []
            )
        }
    }

    private static func loadNormalizedLiturgicalDays(loader: LocalBundleJSONLoader) -> [String: LiturgicalDay] {
        guard let list = try? loader.load("liturgical_days", as: [LiturgicalDay].self, subdirectoryCandidates: [nil, "Resources"]) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: list.map { day in
            (dateKey(for: day.date), day)
        })
    }

    private static func loadSourceSaints(loader: LocalBundleJSONLoader) -> [Saint] {
        let indexSubdirs: [String?] = ["Resources/LegacyData", "LegacyData", "Resources", nil]
        let docSubdirs: [String?] = ["Resources/LegacyData/saints", "LegacyData/saints", "saints", nil]
        guard let index = try? loader.load("saints_index", as: [SaintIndexEntry].self, subdirectoryCandidates: indexSubdirs) else {
            return []
        }

        var saints: [Saint] = index.compactMap { entry in
            guard let doc = (try? loader.load(entry.id, as: SaintDocument.self, subdirectoryCandidates: docSubdirs))
                ?? ContentStore.saint(id: entry.id)
            else {
                return nil
            }
            return mapSourceSaint(doc)
        }

        // Secondary fallback for unexpectedly missing ids in the index payload.
        if saints.isEmpty {
            let urls = loader.urlsForJSON(
                subdirectoryCandidates: ["Resources/LegacyData/saints", "LegacyData/saints", "saints"]
            )
            let decoder = JSONDecoder()
            saints = urls.compactMap { url in
                guard url.lastPathComponent != "saints_index.json",
                      let data = try? Data(contentsOf: url),
                      let doc = try? decoder.decode(SaintDocument.self, from: data)
                else {
                    return nil
                }
                return mapSourceSaint(doc)
            }
        }

        return saints.sorted { lhs, rhs in
            if lhs.feastMonth == rhs.feastMonth {
                if lhs.feastDay == rhs.feastDay {
                    return lhs.name < rhs.name
                }
                return lhs.feastDay < rhs.feastDay
            }
            return lhs.feastMonth < rhs.feastMonth
        }
    }

    private static func loadSourceNovenas(loader: LocalBundleJSONLoader) -> [Novena] {
        let indexSubdirs: [String?] = ["Resources/LegacyData", "LegacyData", "Resources", nil]
        let docSubdirs: [String?] = ["Resources/LegacyData/novenas", "LegacyData/novenas", "novenas", nil]
        guard let index = try? loader.load("novenas_index", as: [NovenaIndexEntry].self, subdirectoryCandidates: indexSubdirs) else {
            return []
        }

        var novenas: [Novena] = index.compactMap { entry in
            guard let doc = (try? loader.load(entry.id, as: NovenaDocument.self, subdirectoryCandidates: docSubdirs))
                ?? ContentStore.novena(id: entry.id)
            else {
                return nil
            }
            return mapSourceNovena(doc)
        }

        // Secondary fallback for unexpectedly missing ids in the index payload.
        if novenas.isEmpty {
            let urls = loader.urlsForJSON(
                subdirectoryCandidates: ["Resources/LegacyData/novenas", "LegacyData/novenas", "novenas"]
            )
            let decoder = JSONDecoder()
            novenas = urls.compactMap { url in
                guard url.lastPathComponent != "novenas_index.json",
                      let data = try? Data(contentsOf: url),
                      let doc = try? decoder.decode(NovenaDocument.self, from: data)
                else {
                    return nil
                }
                return mapSourceNovena(doc)
            }
        }

        return novenas.sorted { lhs, rhs in
            let lt = lhs.titleByLocale[.en] ?? lhs.slug
            let rt = rhs.titleByLocale[.en] ?? rhs.slug
            return lt < rt
        }
    }

    private static func mapSourceSaint(_ doc: SaintDocument) -> Saint? {
        guard let mmdd = doc.mmdd else { return nil }
        let pieces = mmdd.split(separator: "-")
        guard pieces.count == 2,
              let month = Int(pieces[0]),
              let day = Int(pieces[1])
        else { return nil }

        let nameByLocale = localizedMap(base: doc.name, es: doc.name_es, pl: doc.name_pl)
        let summaryByLocale = localizedMap(base: doc.summary, es: doc.summary_es, pl: doc.summary_pl)
        let biographyByLocale = localizedMap(base: doc.biography, es: doc.biography_es, pl: doc.biography_pl)
        let feastByLocale = localizedMap(base: doc.feast, es: doc.feast_es, pl: doc.feast_pl)
        let prayersBase = doc.prayers ?? []
        let prayersByLocale: [ContentLocale: [String]] = [
            .en: prayersBase,
            .es: prayersBase,
            .pl: prayersBase,
        ]

        return Saint(
            id: doc.id,
            slug: doc.id,
            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,
            feastDay: day,
            imageURL: urlFromString(doc.photoUrl),
            tags: [],
            patronages: [],
            feastLabelByLocale: feastByLocale,
            summaryByLocale: summaryByLocale,
            biographyByLocale: biographyByLocale,
            prayersByLocale: prayersByLocale,
            sources: doc.sources ?? []
        )
    }

    private static func mapSourceNovena(_ doc: NovenaDocument) -> Novena? {
        guard let daysDoc = doc.days, !daysDoc.isEmpty else {
            return nil
        }
        let titleByLocale = localizedMap(base: doc.title, es: doc.title_es, pl: doc.title_pl)
        let descriptionByLocale = localizedMap(
            base: doc.description,
            es: doc.description_es,
            pl: doc.description_pl
        )
        let duration = doc.durationDays ?? max(1, daysDoc.count)
        let days = daysDoc.map { day in
            let title = localizedMap(base: day.title, es: day.title_es, pl: day.title_pl)
            let scripture = localizedMap(base: day.scripture, es: day.scripture_es, pl: day.scripture_pl)
            let prayer = localizedMap(base: day.prayer, es: day.prayer_es, pl: day.prayer_pl)
            let reflection = localizedMap(base: day.reflection, es: day.reflection_es, pl: day.reflection_pl)

            let bodyByLocale: [ContentLocale: String] = [
                .en: joinBody(title: title[.en], scripture: scripture[.en], prayer: prayer[.en], reflection: reflection[.en]),
                .es: joinBody(title: title[.es], scripture: scripture[.es], prayer: prayer[.es], reflection: reflection[.es]),
                .pl: joinBody(title: title[.pl], scripture: scripture[.pl], prayer: prayer[.pl], reflection: reflection[.pl]),
            ]

            return NovenaDay(
                dayNumber: day.day ?? 1,
                titleByLocale: title,
                scriptureByLocale: scripture,
                prayerByLocale: prayer,
                reflectionByLocale: reflection,
                bodyByLocale: bodyByLocale
            )
        }
        .sorted { $0.dayNumber < $1.dayNumber }

        return Novena(
            id: doc.id,
            slug: doc.id,
            titleByLocale: titleByLocale,
            descriptionByLocale: descriptionByLocale,
            durationDays: duration,
            tags: doc.tags ?? [],
            imageURL: urlFromString(doc.image),
            days: days
        )
    }

    private static func localizedMap(base: String?, es: String?, pl: String?) -> [ContentLocale: String] {
        var map: [ContentLocale: String] = [:]
        if let base, !base.isEmpty { map[.en] = base }
        if let es, !es.isEmpty { map[.es] = es }
        if let pl, !pl.isEmpty { map[.pl] = pl }
        if map[.en] == nil {
            map[.en] = map[.es] ?? map[.pl] ?? ""
        }
        if map[.es] == nil { map[.es] = map[.en] ?? "" }
        if map[.pl] == nil { map[.pl] = map[.en] ?? "" }
        return map
    }

    private static func joinBody(title: String?, scripture: String?, prayer: String?, reflection: String?) -> String {
        let sections = [title, scripture, prayer, reflection]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sections.joined(separator: "\n\n")
    }

    private static func urlFromString(_ raw: String?) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let direct = URL(string: raw) {
            return direct
        }
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return encoded.flatMap(URL.init(string:))
    }

    private static func firstNonEmpty(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalize(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum LocalSeedData {
    static let saints: [Saint] = [
        Saint(
            id: "03-19_saint_joseph",
            slug: "saint-joseph",
            name: "Saint Joseph",
            nameByLocale: [.en: "Saint Joseph", .es: "San José", .pl: "Święty Józef"],
            feastMonth: 3,
            feastDay: 19,
            imageURL: nil,
            tags: ["family", "workers"],
            patronages: ["Fathers", "Workers", "Universal Church"],
            feastLabelByLocale: [
                .en: "Saint Joseph, Spouse of the Blessed Virgin Mary",
                .es: "San José, Esposo de la Virgen María",
                .pl: "Święty Józef, Oblubieniec Najświętszej Maryi Panny"
            ],
            summaryByLocale: [
                .en: "Spouse of the Blessed Virgin Mary and foster father of Jesus.",
                .es: "Esposo de la Virgen María y padre adoptivo de Jesús.",
                .pl: "Małżonek Maryi i opiekun Jezusa."
            ],
            biographyByLocale: [
                .en: "Spouse of the Blessed Virgin Mary and foster father of Jesus.",
                .es: "Esposo de la Virgen María y padre adoptivo de Jesús.",
                .pl: "Małżonek Maryi i opiekun Jezusa."
            ],
            prayersByLocale: [.en: [], .es: [], .pl: []],
            sources: []
        ),
        Saint(
            id: "10-05_saint_faustina",
            slug: "saint-faustina",
            name: "Saint Faustina",
            nameByLocale: [.en: "Saint Faustina", .es: "Santa Faustina", .pl: "Święta Faustyna"],
            feastMonth: 10,
            feastDay: 5,
            imageURL: nil,
            tags: ["mercy", "devotion"],
            patronages: ["Divine Mercy devotion"],
            feastLabelByLocale: [
                .en: "The Fifth Day of October",
                .es: "El Quinto Día de Octubre",
                .pl: "Piąty dzień października"
            ],
            summaryByLocale: [
                .en: "A Polish nun whose diary records revelations about Divine Mercy.",
                .es: "Monja polaca cuyo diario relata revelaciones sobre la Divina Misericordia.",
                .pl: "Polska zakonnica, której dzienniczek opisuje objawienia Miłosierdzia Bożego."
            ],
            biographyByLocale: [
                .en: "A Polish nun whose diary records revelations about Divine Mercy.",
                .es: "Monja polaca cuyo diario relata revelaciones sobre la Divina Misericordia.",
                .pl: "Polska zakonnica, której dzienniczek opisuje objawienia Miłosierdzia Bożego."
            ],
            prayersByLocale: [.en: [], .es: [], .pl: []],
            sources: []
        )
    ]

    static let novenas: [Novena] = [
        Novena(
            id: "st_joseph",
            slug: "st-joseph",
            titleByLocale: [
                .en: "St. Joseph Novena",
                .es: "Novena a San José",
                .pl: "Nowenna do św. Józefa"
            ],
            descriptionByLocale: [
                .en: "A nine-day prayer asking St. Joseph's intercession.",
                .es: "Una oración de nueve días pidiendo la intercesión de San José.",
                .pl: "Dziewięciodniowa modlitwa o wstawiennictwo św. Józefa."
            ],
            durationDays: 9,
            tags: ["family", "guidance"],
            imageURL: nil,
            days: (1...9).map { day in
                NovenaDay(
                    dayNumber: day,
                    titleByLocale: [:],
                    scriptureByLocale: [:],
                    prayerByLocale: [:],
                    reflectionByLocale: [:],
                    bodyByLocale: [
                        .en: "Day \(day): St. Joseph, guide us in faith and humility.",
                        .es: "Día \(day): San José, guíanos en la fe y la humildad.",
                        .pl: "Dzień \(day): Święty Józefie, prowadź nas w wierze i pokorze."
                    ]
                )
            }
        ),
        Novena(
            id: "divine_mercy",
            slug: "divine-mercy",
            titleByLocale: [
                .en: "Divine Mercy Novena",
                .es: "Novena a la Divina Misericordia",
                .pl: "Nowenna do Miłosierdzia Bożego"
            ],
            descriptionByLocale: [
                .en: "A novena entrusting humanity to Divine Mercy.",
                .es: "Una novena que confía la humanidad a la Divina Misericordia.",
                .pl: "Nowenna powierzająca ludzkość Bożemu Miłosierdziu."
            ],
            durationDays: 9,
            tags: ["mercy", "healing"],
            imageURL: nil,
            days: (1...9).map { day in
                NovenaDay(
                    dayNumber: day,
                    titleByLocale: [:],
                    scriptureByLocale: [:],
                    prayerByLocale: [:],
                    reflectionByLocale: [:],
                    bodyByLocale: [
                        .en: "Day \(day): Jesus, I trust in You.",
                        .es: "Día \(day): Jesús, en Ti confío.",
                        .pl: "Dzień \(day): Jezu, ufam Tobie."
                    ]
                )
            }
        )
    ]

    static let prayers: [Prayer] = [
        Prayer(
            id: "prayer_to_st_joseph",
            slug: "prayer-to-st-joseph",
            category: "intercession",
            titleByLocale: [
                .en: "Prayer to St. Joseph",
                .es: "Oración a San José",
                .pl: "Modlitwa do św. Józefa"
            ],
            bodyByLocale: [
                .en: "St. Joseph, guardian of the Holy Family, pray for us.",
                .es: "San José, custodio de la Sagrada Familia, ruega por nosotros.",
                .pl: "Święty Józefie, opiekunie Świętej Rodziny, módl się za nami."
            ],
            tags: ["family", "protection"]
        )
    ]

    static let liturgicalDays: [String: LiturgicalDay] = [
        "2026-03-19": LiturgicalDay(
            date: ISO8601DateFormatter().date(from: "2026-03-19T00:00:00Z") ?? Date(),
            season: .lent,
            rank: "Solemnity",
            observances: ["Saint Joseph, Spouse of the Blessed Virgin Mary"],
            readingURL: URL(string: "https://bible.usccb.org/")
        )
    ]
}
