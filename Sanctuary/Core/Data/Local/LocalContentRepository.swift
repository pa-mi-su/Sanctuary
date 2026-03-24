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
        ),
        Prayer(
            id: "prayer_to_st_michael_the_archangel",
            slug: "prayer_to_st_michael_the_archangel",
            category: "user_provided",
            titleByLocale: [
                .en: "Prayer to St. Michael the Archangel",
                .es: "Oración a San Miguel Arcángel",
                .pl: "Modlitwa do św. Michała Archanioła"
            ],
            bodyByLocale: [
                .en: "St. Michael the Archangel,\ndefend us in battle.\nBe our defense against the wickedness and snares of the Devil.\nMay God rebuke him, we humbly pray,\nand do thou,\nO Prince of the heavenly hosts,\nby the power of God,\nthrust into hell Satan,\nand all the evil spirits,\nwho prowl about the world\nseeking the ruin of souls. Amen.",
                .es: "San Miguel Arcángel,\ndefiéndenos en la batalla.\nSé nuestro amparo contra la perversidad y asechanzas del demonio.\nReprímale Dios, pedimos suplicantes,\ny tú,\nPríncipe de la milicia celestial,\ncon el poder que Dios te ha conferido,\narroja al infierno a Satanás,\ny a los demás espíritus malignos,\nque vagan por el mundo\npara la perdición de las almas. Amén.",
                .pl: "Święty Michale Archaniele,\nwspomagaj nas w walce.\nA przeciw niegodziwości i zasadzkom złego ducha\nbądź naszą obroną.\nOby go Bóg pogromić raczył,\npokornie o to prosimy,\na Ty,\nWodzu niebieskich zastępów,\nSzatana i inne duchy złe,\nktóre na zgubę dusz ludzkich\npo tym świecie krążą,\nMocą Bożą strąć do piekła. Amen."
            ],
            tags: ["protection", "st michael", "archangel", "spiritual warfare"]
        ),
        Prayer(
            id: "magnificat",
            slug: "magnificat",
            category: "user_provided",
            titleByLocale: [
                .en: "The Magnificat",
                .es: "El Magníficat",
                .pl: "Magnificat"
            ],
            bodyByLocale: [
                .en: "My soul proclaims the greatness of the Lord,\nmy spirit rejoices in God my Savior\nfor he has looked with favor on his lowly servant.\nFrom this day all generations will call me blessed:\nthe Almighty has done great things for me,\nand holy is his Name.\n\nHe has mercy on those who fear him\nin every generation.\nHe has shown the strength of his arm,\nhe has scattered the proud in their conceit.\n\nHe has cast down the mighty from their thrones,\nand has lifted up the lowly.\nHe has filled the hungry with good things,\nand the rich he has sent away empty.\n\nHe has come to the help of his servant Israel\nfor he remembered his promise of mercy,\nthe promise he made to our fathers,\nto Abraham and his children forever.",
                .es: "Proclama mi alma la grandeza del Señor,\nse alegra mi espíritu en Dios mi salvador,\nporque ha mirado la humildad de su esclava.\nDesde ahora me felicitarán todas las generaciones,\nporque el Poderoso ha hecho obras grandes por mí:\nsu nombre es santo.\n\nY su misericordia llega a sus fieles\nde generación en generación.\nÉl hace proezas con su brazo,\ndispersa a los soberbios de corazón.\n\nDerriba del trono a los poderosos\ny enaltece a los humildes.\nA los hambrientos los colma de bienes\ny a los ricos los despide vacíos.\n\nAuxilia a Israel, su siervo,\nacordándose de su misericordia,\ncomo lo había prometido a nuestros padres,\nen favor de Abraham y su descendencia por siempre.",
                .pl: "Wielbi dusza moja Pana,\ni raduje się duch mój w Bogu, Zbawcy moim,\nbo wejrzał na uniżenie swojej Służebnicy.\nOto bowiem odtąd błogosławić mnie będą wszystkie pokolenia,\ngdyż wielkie rzeczy uczynił mi Wszechmocny.\nŚwięte jest Jego imię.\n\nA Jego miłosierdzie z pokolenia na pokolenie\nnad tymi, którzy się Go boją.\nOkazał moc swego ramienia,\nrozproszył pyszniących się zamysłami serc swoich.\n\nStrącił władców z tronu,\na wywyższył pokornych.\nGłodnych nasycił dobrami,\na bogatych z niczym odprawił.\n\nUjął się za swoim sługą, Izraelem,\npomny na swe miłosierdzie,\njak przyobiecał naszym ojcom,\nAbrahamowi i jego potomstwu na wieki."
            ],
            tags: ["mary", "canticle", "gospel of luke", "evening prayer"]
        ),
        Prayer(
            id: "the_angelus",
            slug: "the_angelus",
            category: "user_provided",
            titleByLocale: [
                .en: "The Angelus",
                .es: "El Ángelus",
                .pl: "Anioł Pański"
            ],
            bodyByLocale: [
                .en: "The Angel of the Lord declared to Mary:\nAnd she conceived of the Holy Spirit.\n\nHail Mary, full of grace, the Lord is with thee; blessed art thou among women and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.\n\nBehold the handmaid of the Lord:\nBe it done unto me according to Thy word.\n\nHail Mary . . .\n\nAnd the Word was made Flesh:\nAnd dwelt among us.\n\nHail Mary . . .\n\nPray for us, O Holy Mother of God,\nthat we may be made worthy of the promises of Christ.\n\nLet us pray:\n\nPour forth, we beseech Thee, O Lord, Thy grace into our hearts; that we, to whom the incarnation of Christ, Thy Son, was made known by the message of an angel, may by His Passion and Cross be brought to the glory of His Resurrection, through the same Christ Our Lord. Amen.",
                .es: "El Ángel del Señor anunció a María.\nY concibió por obra del Espíritu Santo.\n\nDios te salve, María, llena eres de gracia; el Señor es contigo; bendita tú eres entre todas las mujeres, y bendito es el fruto de tu vientre, Jesús. Santa María, Madre de Dios, ruega por nosotros, pecadores, ahora y en la hora de nuestra muerte. Amén.\n\nHe aquí la esclava del Señor.\nHágase en mí según tu palabra.\n\nDios te salve, María . . .\n\nY el Verbo se hizo carne.\nY habitó entre nosotros.\n\nDios te salve, María . . .\n\nRuega por nosotros, Santa Madre de Dios,\npara que seamos dignos de alcanzar las promesas de Nuestro Señor Jesucristo.\n\nOremos:\n\nDerrama, Señor, tu gracia en nuestros corazones, para que cuantos hemos conocido por el anuncio del ángel la encarnación de tu Hijo Jesucristo, por su Pasión y su Cruz lleguemos a la gloria de la Resurrección. Por el mismo Jesucristo, nuestro Señor. Amén.",
                .pl: "Anioł Pański zwiastował Pannie Maryi.\nI poczęła z Ducha Świętego.\n\nZdrowaś Maryjo, łaski pełna, Pan z Tobą, błogosławionaś Ty między niewiastami i błogosławiony owoc żywota Twojego, Jezus. Święta Maryjo, Matko Boża, módl się za nami grzesznymi, teraz i w godzinę śmierci naszej. Amen.\n\nOto ja służebnica Pańska.\nNiech mi się stanie według słowa twego.\n\nZdrowaś Maryjo . . .\n\nA Słowo stało się ciałem.\nI zamieszkało między nami.\n\nZdrowaś Maryjo . . .\n\nMódl się za nami, święta Boża Rodzicielko,\nabyśmy się stali godnymi obietnic Chrystusowych.\n\nMódlmy się:\n\nŁaskę Twoją, prosimy Cię, Panie, racz wlać w serca nasze, abyśmy, którzy za zwiastowaniem anielskim wcielenie Chrystusa, Syna Twego, poznali, przez Jego mękę i krzyż do chwały zmartwychwstania byli doprowadzeni. Przez tegoż Chrystusa, Pana naszego. Amen."
            ],
            tags: ["mary", "incarnation", "angelus", "hail mary"]
        ),
        Prayer(
            id: "nicene_creed",
            slug: "nicene_creed",
            category: "user_provided",
            titleByLocale: [
                .en: "Nicene Creed",
                .es: "Credo Niceno",
                .pl: "Credo nicejskie"
            ],
            bodyByLocale: [
                .en: "I believe in one God,\nthe Father, the Almighty,\nMaker of heaven and earth,\nof all things visible and invisible.\n\nI believe in one Lord Jesus Christ,\nthe Only Begotten Son of God,\nborn of the Father before all ages.\nGod from God, Light from Light,\ntrue God from true God,\nbegotten, not made, consubstantial with the Father;\nthrough him all things were made.\nFor us men and for our salvation\nhe came down from heaven,\nand by the Holy Spirit was incarnate of the Virgin Mary,\nand became man.\nFor our sake he was crucified under Pontius Pilate,\nhe suffered death and was buried,\nand rose again on the third day\nin accordance with the Scriptures.\nHe ascended into heaven\nand is seated at the right hand of the Father.\nHe will come again in glory\nto judge the living and the dead\nand his kingdom will have no end.\n\nI believe in the Holy Spirit, the Lord, the giver of life,\nwho proceeds from the Father and the Son,\nwho with the Father and the Son is adored and glorified,\nwho has spoken through the prophets.\n\nI believe in one, holy, catholic and apostolic Church.\nI confess one Baptism for the forgiveness of sins\nand I look forward to the resurrection of the dead\nand the life of the world to come. Amen.",
                .es: "Creo en un solo Dios,\nPadre todopoderoso,\nCreador del cielo y de la tierra,\nde todo lo visible y lo invisible.\n\nCreo en un solo Señor, Jesucristo,\nHijo único de Dios,\nnacido del Padre antes de todos los siglos:\nDios de Dios, Luz de Luz,\nDios verdadero de Dios verdadero,\nengendrado, no creado,\nde la misma naturaleza del Padre,\npor quien todo fue hecho;\nque por nosotros, los hombres,\ny por nuestra salvación bajó del cielo,\ny por obra del Espíritu Santo se encarnó de María, la Virgen,\ny se hizo hombre;\ny por nuestra causa fue crucificado\nen tiempos de Poncio Pilato;\npadeció y fue sepultado,\ny resucitó al tercer día, según las Escrituras,\ny subió al cielo,\ny está sentado a la derecha del Padre;\ny de nuevo vendrá con gloria para juzgar a vivos y muertos,\ny su reino no tendrá fin.\n\nCreo en el Espíritu Santo, Señor y dador de vida,\nque procede del Padre y del Hijo,\nque con el Padre y el Hijo recibe una misma adoración y gloria,\ny que habló por los profetas.\n\nCreo en la Iglesia, que es una, santa, católica y apostólica.\nConfieso que hay un solo Bautismo para el perdón de los pecados.\nEspero la resurrección de los muertos\ny la vida del mundo futuro. Amén.",
                .pl: "Wierzę w jednego Boga,\nOjca wszechmogącego,\nStworzyciela nieba i ziemi,\nwszystkich rzeczy widzialnych i niewidzialnych.\n\nI w jednego Pana Jezusa Chrystusa,\nSyna Bożego Jednorodzonego,\nktóry z Ojca jest zrodzony przed wszystkimi wiekami.\nBóg z Boga, Światłość ze Światłości,\nBóg prawdziwy z Boga prawdziwego,\nzrodzony, a nie stworzony,\nwspółistotny Ojcu,\na przez Niego wszystko się stało.\nOn to dla nas ludzi i dla naszego zbawienia zstąpił z nieba.\nI za sprawą Ducha Świętego przyjął ciało z Maryi Dziewicy\ni stał się człowiekiem.\nUkrzyżowany również za nas,\npod Poncjuszem Piłatem został umęczony i pogrzebany.\nI zmartwychwstał dnia trzeciego, jak oznajmia Pismo.\nI wstąpił do nieba; siedzi po prawicy Ojca.\nI powtórnie przyjdzie w chwale sądzić żywych i umarłych,\na królestwu Jego nie będzie końca.\n\nWierzę w Ducha Świętego, Pana i Ożywiciela,\nktóry od Ojca i Syna pochodzi.\nKtóry z Ojcem i Synem wspólnie odbiera uwielbienie i chwałę;\nktóry mówił przez Proroków.\n\nWierzę w jeden, święty, powszechny i apostolski Kościół.\nWyznaję jeden chrzest na odpuszczenie grzechów.\nI oczekuję wskrzeszenia umarłych.\nI życia wiecznego w przyszłym świecie. Amen."
            ],
            tags: ["creed", "profession of faith", "mass", "trinity"]
        ),
        Prayer(
            id: "apostles_creed",
            slug: "apostles_creed",
            category: "user_provided",
            titleByLocale: [
                .en: "Apostles' Creed",
                .es: "Credo de los Apóstoles",
                .pl: "Skład Apostolski"
            ],
            bodyByLocale: [
                .en: "I believe in God, the Father Almighty, Creator of Heaven and earth;\nand in Jesus Christ, His only Son Our Lord,\nWho was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died, and was buried.\nHe descended into Hell; the third day He rose again from the dead;\nHe ascended into Heaven, and sitteth at the right hand of God, the Father almighty; from thence He shall come to judge the living and the dead.\nI believe in the Holy Spirit, the holy Catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body and life everlasting. Amen.",
                .es: "Creo en Dios, Padre todopoderoso,\nCreador del cielo y de la tierra.\nCreo en Jesucristo, su único Hijo, nuestro Señor,\nque fue concebido por obra y gracia del Espíritu Santo,\nnació de santa María Virgen,\npadeció bajo el poder de Poncio Pilato,\nfue crucificado, muerto y sepultado,\ndescendió a los infiernos,\nal tercer día resucitó de entre los muertos,\nsubió a los cielos y está sentado a la derecha de Dios, Padre todopoderoso.\nDesde allí ha de venir a juzgar a vivos y muertos.\nCreo en el Espíritu Santo,\nla santa Iglesia católica,\nla comunión de los santos,\nel perdón de los pecados,\nla resurrección de la carne\ny la vida eterna. Amén.",
                .pl: "Wierzę w Boga,\nOjca wszechmogącego,\nStworzyciela nieba i ziemi.\nI w Jezusa Chrystusa,\nSyna Jego jedynego, Pana naszego,\nktóry się począł z Ducha Świętego,\nnarodził się z Maryi Panny,\numęczon pod Ponckim Piłatem,\nukrzyżowan, umarł i pogrzebion.\nZstąpił do piekieł,\ntrzeciego dnia zmartwychwstał.\nWstąpił na niebiosa,\nsiedzi po prawicy Boga Ojca wszechmogącego.\nStamtąd przyjdzie sądzić żywych i umarłych.\nWierzę w Ducha Świętego,\nświęty Kościół powszechny,\nświętych obcowanie,\ngrzechów odpuszczenie,\nciała zmartwychwstanie,\nżywot wieczny. Amen."
            ],
            tags: ["creed", "profession of faith", "rosary", "baptismal faith"]
        ),
        Prayer(
            id: "salve_regina",
            slug: "salve_regina",
            category: "user_provided",
            titleByLocale: [
                .en: "Salve Regina (Hail, Holy Queen)",
                .es: "Salve Regina (Dios te salve, Reina y Madre)",
                .pl: "Salve Regina (Witaj, Królowo)"
            ],
            bodyByLocale: [
                .en: "Hail, holy Queen, mother of Mercy.\nHail, our life, our sweetness and our hope.\nTo thee do we cry,\npoor banished children of Eve;\nto thee do we send up our sighs,\nmourning and weeping,\nin this vale of tears.\nTurn then, most gracious advocate,\nthine eyes of mercy toward us;\nand after this our exile, show unto us\nthe blessed fruit of thy womb, Jesus.\nO clement, O loving,\nO sweet virgin Mary.",
                .es: "Dios te salve, Reina y Madre de misericordia,\nvida, dulzura y esperanza nuestra;\nDios te salve.\nA ti llamamos los desterrados hijos de Eva;\na ti suspiramos, gimiendo y llorando\nen este valle de lágrimas.\nEa, pues, Señora, abogada nuestra,\nvuelve a nosotros esos tus ojos misericordiosos,\ny después de este destierro muéstranos a Jesús,\nfruto bendito de tu vientre.\n¡Oh clemente, oh piadosa,\noh dulce Virgen María!",
                .pl: "Witaj, Królowo, Matko Miłosierdzia,\nżycie, słodyczy i nadziejo nasza, witaj.\nDo Ciebie wołamy, wygnańcy, synowie Ewy,\ndo Ciebie wzdychamy,\njęcząc i płacząc\nna tym łez padole.\nPrzeto, Orędowniczko nasza,\none miłosierne oczy Twoje\nna nas zwróć,\na Jezusa,\nbłogosławiony owoc żywota Twojego,\npo tym wygnaniu nam okaż.\nO łaskawa,\nO litościwa,\nO słodka Panno Maryjo."
            ],
            tags: ["mary", "marian prayer", "rosary", "hail holy queen"]
        ),
        Prayer(
            id: "prayer_of_st_thomas_aquinas",
            slug: "prayer_of_st_thomas_aquinas",
            category: "user_provided",
            titleByLocale: [
                .en: "Prayer of St. Thomas Aquinas",
                .es: "Oración de Santo Tomás de Aquino",
                .pl: "Modlitwa św. Tomasza z Akwinu"
            ],
            bodyByLocale: [
                .en: "Lord, Father all-powerful and ever-living God, I thank You, for even though I am a sinner, your unprofitable servant, not because of my worth but in the kindness of your mercy, You have fed me with the Precious Body and Blood of Your Son, our Lord Jesus Christ.\n\nI pray that this Holy Communion may not bring me condemnation and punishment but forgiveness and salvation. May it be a helmet of faith and a shield of good will. May it purify me from evil ways and put an end to my evil passions. May it bring me charity and patience, humility and obedience, and growth in the power to do good.\n\nMay it be my strong defense against all my enemies, visible and invisible, and the perfect calming of all my evil impulses, bodily and spiritual. May it unite me more closely to you, the One true God, and lead me safely through death to everlasting happiness with You.\n\nAnd I pray that You will lead me, a sinner, to the banquet where You, with Your Son and Holy Spirit, are true and perfect light, total fulfillment, everlasting joy, gladness without end, and perfect happiness to your saints. Grant this through Christ our Lord. Amen.",
                .es: "Señor, Padre todopoderoso y Dios eterno, te doy gracias porque, aun siendo yo pecador e indigno siervo tuyo, no por mis méritos sino por la bondad de tu misericordia, me has alimentado con el preciosísimo Cuerpo y Sangre de tu Hijo, nuestro Señor Jesucristo.\n\nTe suplico que esta santa Comunión no sea para mí motivo de condenación y castigo, sino intercesión saludable para perdón y salvación. Sea para mí armadura de fe y escudo de buena voluntad. Purifícame de mis malos caminos y pon fin a mis pasiones desordenadas. Acrecienta en mí la caridad y la paciencia, la humildad y la obediencia, y fortaleza para obrar el bien.\n\nSea mi firme defensa contra todos mis enemigos, visibles e invisibles, y la perfecta calma de todos mis impulsos desordenados, corporales y espirituales. Úneme más estrechamente a Ti, único Dios verdadero, y condúceme con seguridad a la felicidad eterna contigo.\n\nY te ruego que me conduzcas, a mí pecador, al banquete donde Tú, con tu Hijo y el Espíritu Santo, eres luz verdadera y perfecta, plenitud total, gozo eterno, alegría sin fin y perfecta felicidad para tus santos. Concédelo por Cristo nuestro Señor. Amén.",
                .pl: "Panie, Ojcze wszechmogący i wiecznie żyjący Boże, dziękuję Ci, że choć jestem grzesznikiem i niegodnym sługą Twoim, nie dla moich zasług, lecz przez dobroć Twego miłosierdzia, nakarmiłeś mnie Najświętszym Ciałem i Krwią Twego Syna, naszego Pana Jezusa Chrystusa.\n\nProszę Cię, aby ta Komunia Święta nie była mi ku potępieniu i karze, lecz wyjednała przebaczenie i zbawienie. Niech będzie dla mnie hełmem wiary i tarczą dobrej woli. Niech oczyści mnie ze złych dróg i położy kres moim złym namiętnościom. Niech przyniesie mi miłość i cierpliwość, pokorę i posłuszeństwo oraz wzrost w mocy czynienia dobra.\n\nNiech będzie moją mocną obroną przeciw wszystkim moim nieprzyjaciołom, widzialnym i niewidzialnym, i doskonałym uciszeniem wszystkich moich złych poruszeń, cielesnych i duchowych. Niech zjednoczy mnie ściślej z Tobą, jedynym prawdziwym Bogiem, i bezpiecznie poprowadzi przez śmierć do wiecznego szczęścia z Tobą.\n\nI proszę, prowadź mnie, grzesznika, do uczty, gdzie Ty, ze swoim Synem i Duchem Świętym, jesteś prawdziwym i doskonałym światłem, pełnią spełnienia, wieczną radością, weselem bez końca i doskonałym szczęściem Twoich świętych. Udziel tego przez Chrystusa, Pana naszego. Amen."
            ],
            tags: ["communion", "eucharist", "st thomas aquinas", "thanksgiving"]
        ),
        Prayer(
            id: "prayer_of_st_dominic",
            slug: "prayer_of_st_dominic",
            category: "user_provided",
            titleByLocale: [
                .en: "Prayer of St. Dominic",
                .es: "Oración de Santo Domingo",
                .pl: "Modlitwa św. Dominika"
            ],
            bodyByLocale: [
                .en: "May God the Father who made us bless us.\nMay God the Son send his healing among us.\nMay God the Holy Spirit move within us and\ngive us eyes to see with, ears to hear with,\nand hands that your work might be done.\nMay we walk and preach the word of God to all.\nMay the angel of peace watch over us and\nlead us at last by God's grace to the Kingdom. Amen.",
                .es: "Que Dios Padre, que nos creó, nos bendiga.\nQue Dios Hijo envíe su sanación entre nosotros.\nQue Dios Espíritu Santo se mueva dentro de nosotros y\nnos dé ojos para ver, oídos para escuchar\ny manos para que se haga su obra.\nQue caminemos y prediquemos la palabra de Dios a todos.\nQue el ángel de la paz vele por nosotros y\nnos conduzca finalmente, por la gracia de Dios, al Reino. Amén.",
                .pl: "Niech Bóg Ojciec, który nas stworzył, nam błogosławi.\nNiech Bóg Syn ześle pośród nas swoje uzdrowienie.\nNiech Bóg Duch Święty porusza się w nas i\nda nam oczy do widzenia, uszy do słyszenia\ni ręce, aby mogło dokonać się Twoje dzieło.\nNiech kroczymy i głosimy słowo Boże wszystkim.\nNiech anioł pokoju czuwa nad nami i\nniech prowadzi nas w końcu, dzięki łasce Bożej, do Królestwa. Amen."
            ],
            tags: ["st dominic", "peace", "mission", "healing"]
        ),
        Prayer(
            id: "prayer_in_honor_of_st_peter_julian_eymard",
            slug: "prayer_in_honor_of_st_peter_julian_eymard",
            category: "user_provided",
            titleByLocale: [
                .en: "Prayer in Honor of St. Peter Julian Eymard",
                .es: "Oración en honor de San Pedro Julián Eymard",
                .pl: "Modlitwa ku czci św. Piotra Juliana Eymarda"
            ],
            bodyByLocale: [
                .en: "Gracious God of our ancestors,\nyou led Peter Julian Eymard,\nlike Jacob in times past,\non a journey of faith.\nUnder the guidance of your gentle Spirit,\nPeter Julian discovered the gift of love\nin the Eucharist which your Son Jesus\noffered for the hungers of humanity.\nGrant that we may\ncelebrate this mystery worthily,\nadore it profoundly, and\nproclaim it prophetically\nfor your greater glory.\n\nSaint Peter Julian Eymard,\nApostle of the Eucharist,\npray for us!",
                .es: "Dios bondadoso de nuestros antepasados,\ntú condujiste a Pedro Julián Eymard,\ncomo a Jacob en tiempos pasados,\nen un camino de fe.\nBajo la guía de tu suave Espíritu,\nPedro Julián descubrió el don del amor\nen la Eucaristía que tu Hijo Jesús\nofreció para el hambre de la humanidad.\nConcédenos\ncelebrar dignamente este misterio,\nadorarlo profundamente y\nproclamarlo proféticamente\npara tu mayor gloria.\n\nSan Pedro Julián Eymard,\nApóstol de la Eucaristía,\nruega por nosotros.",
                .pl: "Łaskawy Boże naszych przodków,\nprowadziłeś Piotra Juliana Eymarda,\njak niegdyś Jakuba,\nna drodze wiary.\nPod przewodnictwem Twego łagodnego Ducha\nPiotr Julian odkrył dar miłości\nw Eucharystii, którą Twój Syn Jezus\nofiarował na głód ludzkości.\nSpraw, abyśmy\nmogli godnie celebrować tę tajemnicę,\ngłęboko ją adorować i\nproroczo ją głosić\ndla Twojej większej chwały.\n\nŚwięty Piotrze Julianie Eymardzie,\nApostole Eucharystii,\nmódl się za nami!"
            ],
            tags: ["eucharist", "st peter julian eymard", "adoration", "apostle of the eucharist"]
        ),
        Prayer(
            id: "prayer_to_our_lady_guadalupe_apostolate",
            slug: "prayer_to_our_lady_guadalupe_apostolate",
            category: "user_provided",
            titleByLocale: [
                .en: "Prayer to Our Lady Guadalupe Apostolate",
                .es: "Oración al Apostolado de Nuestra Señora de Guadalupe",
                .pl: "Modlitwa do apostolatu Matki Bożej z Guadalupe"
            ],
            bodyByLocale: [
                .en: "Our Lady of Guadalupe, Mother of the Americas and all Nations.\nLook in compassion on your children.\nWe need your help to keep the faith, to preserve the family,\nto work for justice with forbearance and forgiveness, to live and grow in charity.\n\nWith our whole heart we consecrate ourselves to Your Immaculate Heart.\nDirect our abilities, our efforts, to the furthering of the Kingdom of God on earth.\n\nMay we do our part to make ourselves, the Americas and all Nations more worthy of the love you show us. Looking on your image, may we grow in the likeness of your son, our Lord Jesus Christ. Amen.\n\n- John Paul II",
                .es: "Nuestra Señora de Guadalupe, Madre de las Américas y de todas las naciones.\nMira con compasión a tus hijos.\nNecesitamos tu ayuda para conservar la fe, para preservar la familia,\npara trabajar por la justicia con paciencia y perdón, para vivir y crecer en la caridad.\n\nCon todo nuestro corazón nos consagramos a tu Inmaculado Corazón.\nDirige nuestras capacidades y nuestros esfuerzos al crecimiento del Reino de Dios en la tierra.\n\nQue hagamos nuestra parte para hacernos a nosotros mismos, a las Américas y a todas las naciones más dignos del amor que nos muestras. Al contemplar tu imagen, que crezcamos a semejanza de tu Hijo, nuestro Señor Jesucristo. Amén.\n\n- Juan Pablo II",
                .pl: "Matko Boża z Guadalupe, Matko obu Ameryk i wszystkich narodów.\nSpójrz ze współczuciem na swoje dzieci.\nPotrzebujemy Twojej pomocy, aby zachować wiarę, strzec rodziny,\npracować na rzecz sprawiedliwości z cierpliwością i przebaczeniem oraz żyć i wzrastać w miłości.\n\nCałym sercem poświęcamy się Twojemu Niepokalanemu Sercu.\nKieruj naszymi zdolnościami i naszymi wysiłkami ku rozszerzaniu Królestwa Bożego na ziemi.\n\nObyśmy czynili swoją część, aby uczynić nas samych, obie Ameryki i wszystkie narody bardziej godnymi miłości, którą nam okazujesz. Patrząc na Twój wizerunek, niech wzrastamy na podobieństwo Twojego Syna, naszego Pana Jezusa Chrystusa. Amen.\n\n- Jan Paweł II"
            ],
            tags: ["our lady of guadalupe", "mary", "john paul ii", "apostolate"]
        ),
        Prayer(
            id: "hail_mary",
            slug: "hail_mary",
            category: "user_provided",
            titleByLocale: [
                .en: "Hail Mary",
                .es: "Dios te salve, María",
                .pl: "Zdrowaś Maryjo"
            ],
            bodyByLocale: [
                .en: "Hail Mary,\nFull of Grace,\nThe Lord is with thee.\nBlessed art thou among women,\nand blessed is the fruit\nof thy womb, Jesus.\nHoly Mary,\nMother of God,\npray for us sinners now,\nand at the hour of our death.\nAmen.",
                .es: "Dios te salve, María,\nllena eres de gracia,\nel Señor es contigo.\nBendita tú eres entre todas las mujeres,\ny bendito es el fruto de tu vientre, Jesús.\nSanta María,\nMadre de Dios,\nruega por nosotros pecadores,\nahora y en la hora de nuestra muerte.\nAmén.",
                .pl: "Zdrowaś Maryjo,\nłaski pełna,\nPan z Tobą,\nbłogosławionaś Ty między niewiastami\ni błogosławiony owoc żywota Twojego, Jezus.\nŚwięta Maryjo,\nMatko Boża,\nmódl się za nami grzesznymi,\nteraz i w godzinę śmierci naszej.\nAmen."
            ],
            tags: ["mary", "hail mary", "ave maria", "marian prayer"]
        ),
        Prayer(
            id: "our_father",
            slug: "our_father",
            category: "user_provided",
            titleByLocale: [
                .en: "Our Father",
                .es: "Padre Nuestro",
                .pl: "Ojcze nasz"
            ],
            bodyByLocale: [
                .en: "Our Father,\nwho art in heaven,\nhallowed be thy name.\nThy kingdom come,\nthy will be done,\non earth as it is in heaven.\nGive us this day our daily bread,\nand forgive us our trespasses,\nas we forgive those who trespass against us;\nand lead us not into temptation,\nbut deliver us from evil.\nAmen.",
                .es: "Padre nuestro,\nque estás en el cielo,\nsantificado sea tu Nombre;\nvenga a nosotros tu reino;\nhágase tu voluntad\nen la tierra como en el cielo.\nDanos hoy nuestro pan de cada día;\nperdona nuestras ofensas,\ncomo también nosotros perdonamos\na los que nos ofenden;\nno nos dejes caer en la tentación,\ny líbranos del mal.\nAmén.",
                .pl: "Ojcze nasz,\nktóryś jest w niebie,\nświęć się imię Twoje;\nprzyjdź królestwo Twoje;\nbądź wola Twoja,\njako w niebie, tak i na ziemi.\nChleba naszego powszedniego daj nam dzisiaj;\ni odpuść nam nasze winy,\njako i my odpuszczamy naszym winowajcom;\ni nie wódź nas na pokuszenie,\nale nas zbaw ode złego.\nAmen."
            ],
            tags: ["our father", "lord's prayer", "jesus", "foundational prayer"]
        ),
        Prayer(
            id: "glory_be",
            slug: "glory_be",
            category: "user_provided",
            titleByLocale: [
                .en: "Glory Be",
                .es: "Gloria",
                .pl: "Chwała Ojcu"
            ],
            bodyByLocale: [
                .en: "Glory be to the Father,\nand to the Son,\nand to the Holy Spirit.\nAs it was in the beginning, is now,\nand ever shall be,\nworld without end.\nAmen.",
                .es: "Gloria al Padre,\ny al Hijo,\ny al Espíritu Santo.\nComo era en el principio, ahora y siempre,\npor los siglos de los siglos.\nAmén.",
                .pl: "Chwała Ojcu\ni Synowi,\ni Duchowi Świętemu.\nJak była na początku,\nteraz i zawsze,\ni na wieki wieków.\nAmen."
            ],
            tags: ["glory be", "doxology", "trinity", "holy spirit"]
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
