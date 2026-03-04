import Foundation

actor LocalContentRepository: ContentRepository {
    private let saints: [Saint]
    private let novenas: [Novena]
    private let prayers: [Prayer]
    private let liturgicalDays: [String: LiturgicalDay]

    init(bundle: Bundle = .main, fallbackToSeed: Bool = true) {
        do {
            let loader = LocalBundleJSONLoader(bundle: bundle)
            let saints = try loader.load("saints", as: [Saint].self)
            let novenas = try loader.load("novenas", as: [Novena].self)
            let prayers = try loader.load("prayers", as: [Prayer].self)
            let liturgicalList = try loader.load("liturgical_days", as: [LiturgicalDay].self)
            let liturgicalByKey = Dictionary(uniqueKeysWithValues: liturgicalList.map { day in
                (Self.dateKey(for: day.date), day)
            })

            self.saints = saints
            self.novenas = novenas
            self.prayers = prayers
            self.liturgicalDays = liturgicalByKey
        } catch {
            if fallbackToSeed {
                self.saints = LocalSeedData.saints
                self.novenas = LocalSeedData.novenas
                self.prayers = LocalSeedData.prayers
                self.liturgicalDays = LocalSeedData.liturgicalDays
            } else {
                self.saints = []
                self.novenas = []
                self.prayers = []
                self.liturgicalDays = [:]
            }
        }
    }

    func listSaints(
        locale: ContentLocale,
        feastDate: FeastDateFilter?,
        query: String?
    ) async throws -> [Saint] {
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

                let name = saint.name.lowercased()
                let biography = saint.biographyByLocale[locale]?.lowercased() ?? ""
                return name.contains(normalized) || biography.contains(normalized)
            }
            .sorted { $0.name < $1.name }
    }

    func fetchSaint(slug: String, locale _: ContentLocale) async throws -> Saint? {
        saints.first { $0.slug == slug }
    }

    func listNovenas(
        locale: ContentLocale,
        tag: String?,
        query: String?
    ) async throws -> [Novena] {
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
        novenas.first { $0.slug == slug }
    }

    func listPrayers(
        locale: ContentLocale,
        category: String?,
        query: String?
    ) async throws -> [Prayer] {
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
        liturgicalDays[Self.dateKey(for: date)]
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
            feastMonth: 3,
            feastDay: 19,
            imageURL: nil,
            tags: ["family", "workers"],
            patronages: ["Fathers", "Workers", "Universal Church"],
            biographyByLocale: [
                .en: "Spouse of the Blessed Virgin Mary and foster father of Jesus.",
                .es: "Esposo de la Virgen María y padre adoptivo de Jesús.",
                .pl: "Małżonek Maryi i opiekun Jezusa."
            ]
        ),
        Saint(
            id: "10-05_saint_faustina",
            slug: "saint-faustina",
            name: "Saint Faustina",
            feastMonth: 10,
            feastDay: 5,
            imageURL: nil,
            tags: ["mercy", "devotion"],
            patronages: ["Divine Mercy devotion"],
            biographyByLocale: [
                .en: "A Polish nun whose diary records revelations about Divine Mercy.",
                .es: "Monja polaca cuyo diario relata revelaciones sobre la Divina Misericordia.",
                .pl: "Polska zakonnica, której dzienniczek opisuje objawienia Miłosierdzia Bożego."
            ]
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
