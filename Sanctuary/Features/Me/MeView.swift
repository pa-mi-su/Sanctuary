import SwiftUI

struct MeView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var progressStore: UserProgressStore
    @State private var selectedRoute: MeSelectionRoute?

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localization.t("tab.me"))
                        .font(AppTheme.rounded(42, weight: .bold))
                        .foregroundStyle(.white)

                    Text(localization.t("me.subtitle"))
                        .font(AppTheme.rounded(18, weight: .medium))
                        .foregroundStyle(AppTheme.subtitleText)

                    MeCard(title: localization.t("me.inProgress"), subtitle: "\(progressStore.activeCommitments.count) in progress") {
                        if progressStore.activeCommitments.isEmpty {
                            Text(localization.t("me.noneInProgress"))
                                .font(AppTheme.rounded(16, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.85))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(progressStore.activeCommitments, id: \.novenaID) { commitment in
                                    let title = ContentStore.novena(id: commitment.novenaID)?.title ?? commitment.novenaID
                                    let total = max(1, ContentStore.novena(id: commitment.novenaID)?.durationDays ?? 9)
                                    let dayLabel = "Day \(min(commitment.currentDay, total)) of \(total)"
                                    Button {
                                        selectedRoute = .novena(id: commitment.novenaID)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(title)
                                                    .font(AppTheme.rounded(16, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                Text(dayLabel)
                                                    .font(AppTheme.rounded(13, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.86))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                        .background(AppTheme.purpleButton)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    MeCard(title: localization.t("me.favoriteNovenas")) {
                        if favoriteNovenas.isEmpty {
                            Text(localization.t("me.noneFavoriteNovenas"))
                                .font(AppTheme.rounded(16, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.85))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(favoriteNovenas, id: \.itemID) { favorite in
                                    Button {
                                        selectedRoute = .novena(id: favorite.itemID)
                                    } label: {
                                        HStack {
                                            Text(novenaTitle(for: favorite.itemID))
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .background(AppTheme.purpleButton)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    MeCard(title: localization.t("me.favoriteSaints")) {
                        if favoriteSaints.isEmpty {
                            Text(localization.t("me.noneFavoriteSaints"))
                                .font(AppTheme.rounded(16, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.85))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(favoriteSaints, id: \.itemID) { favorite in
                                    Button {
                                        selectedRoute = .saint(id: favorite.itemID)
                                    } label: {
                                        HStack {
                                            Text(saintName(for: favorite.itemID))
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .background(AppTheme.purpleButton)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .task {
            await progressStore.refresh()
        }
        .sheet(item: $selectedRoute) { route in
            switch route {
            case .saint(let id):
                SaintDetailView(
                    saint: Saint(
                        id: id,
                        slug: id,
                        name: saintName(for: id),
                        nameByLocale: [
                            .en: saintName(for: id),
                            .es: saintName(for: id),
                            .pl: saintName(for: id)
                        ],
                        feastMonth: 1,
                        feastDay: 1,
                        imageURL: nil,
                        tags: [],
                        patronages: [],
                        feastLabelByLocale: [.en: ""],
                        summaryByLocale: [.en: ""],
                        biographyByLocale: [.en: ""],
                        prayersByLocale: [.en: []],
                        sources: []
                    ),
                    onClose: { selectedRoute = nil }
                )
            case .novena(let id):
                NovenaDetailView(
                    novena: Novena(
                        id: id,
                        slug: id,
                        titleByLocale: [.en: novenaTitle(for: id)],
                        descriptionByLocale: [.en: ""],
                        durationDays: 9,
                        tags: [],
                        imageURL: nil,
                        days: []
                    ),
                    onClose: { selectedRoute = nil }
                )
            }
        }
    }

    private var favoriteNovenas: [UserFavorite] {
        progressStore.favorites(for: .novena)
    }

    private var favoriteSaints: [UserFavorite] {
        progressStore.favorites(for: .saint)
    }

    private func saintName(for id: String) -> String {
        guard let doc = ContentStore.saint(id: id) else { return id }
        switch localization.language.contentLocale {
        case .en:
            return doc.name ?? id
        case .es:
            return doc.name_es ?? doc.name ?? id
        case .pl:
            return doc.name_pl ?? doc.name ?? id
        }
    }

    private func novenaTitle(for id: String) -> String {
        ContentStore.novena(id: id)?.title ?? id
    }

    private func mapSourceSaint(_ doc: SaintDocument) -> Saint {
        let mmdd = doc.mmdd ?? "01-01"
        let parts = mmdd.split(separator: "-")
        let month = parts.count == 2 ? Int(parts[0]) ?? 1 : 1
        let day = parts.count == 2 ? Int(parts[1]) ?? 1 : 1
        let nameByLocale: [ContentLocale: String] = [
            .en: doc.name ?? doc.id,
            .es: doc.name_es ?? doc.name ?? doc.id,
            .pl: doc.name_pl ?? doc.name ?? doc.id
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
            feastLabelByLocale: [
                .en: doc.feast ?? "",
                .es: doc.feast_es ?? doc.feast ?? "",
                .pl: doc.feast_pl ?? doc.feast ?? "",
            ],
            summaryByLocale: [
                .en: doc.summary ?? "",
                .es: doc.summary_es ?? doc.summary ?? "",
                .pl: doc.summary_pl ?? doc.summary ?? "",
            ],
            biographyByLocale: [
                .en: doc.biography ?? "",
                .es: doc.biography_es ?? doc.biography ?? "",
                .pl: doc.biography_pl ?? doc.biography ?? "",
            ],
            prayersByLocale: [.en: doc.prayers ?? [], .es: doc.prayers ?? [], .pl: doc.prayers ?? []],
            sources: doc.sources ?? []
        )
    }

    private func mapSourceNovena(_ doc: NovenaDocument) -> Novena {
        let titleByLocale: [ContentLocale: String] = [
            .en: doc.title ?? doc.id,
            .es: doc.title_es ?? doc.title ?? doc.id,
            .pl: doc.title_pl ?? doc.title ?? doc.id,
        ]
        let descriptionByLocale: [ContentLocale: String] = [
            .en: doc.description ?? "",
            .es: doc.description_es ?? doc.description ?? "",
            .pl: doc.description_pl ?? doc.description ?? "",
        ]

        let days = (doc.days ?? []).map { d in
            let title: [ContentLocale: String] = [
                .en: d.title ?? "",
                .es: d.title_es ?? d.title ?? "",
                .pl: d.title_pl ?? d.title ?? "",
            ]
            let scripture: [ContentLocale: String] = [
                .en: d.scripture ?? "",
                .es: d.scripture_es ?? d.scripture ?? "",
                .pl: d.scripture_pl ?? d.scripture ?? "",
            ]
            let prayer: [ContentLocale: String] = [
                .en: d.prayer ?? "",
                .es: d.prayer_es ?? d.prayer ?? "",
                .pl: d.prayer_pl ?? d.prayer ?? "",
            ]
            let reflection: [ContentLocale: String] = [
                .en: d.reflection ?? "",
                .es: d.reflection_es ?? d.reflection ?? "",
                .pl: d.reflection_pl ?? d.reflection ?? "",
            ]

            return NovenaDay(
                dayNumber: d.day ?? 1,
                titleByLocale: title,
                scriptureByLocale: scripture,
                prayerByLocale: prayer,
                reflectionByLocale: reflection,
                bodyByLocale: [
                    .en: [title[.en], scripture[.en], prayer[.en], reflection[.en]].compactMap { $0 }.joined(separator: "\n\n"),
                    .es: [title[.es], scripture[.es], prayer[.es], reflection[.es]].compactMap { $0 }.joined(separator: "\n\n"),
                    .pl: [title[.pl], scripture[.pl], prayer[.pl], reflection[.pl]].compactMap { $0 }.joined(separator: "\n\n"),
                ]
            )
        }

        return Novena(
            id: doc.id,
            slug: doc.id,
            titleByLocale: titleByLocale,
            descriptionByLocale: descriptionByLocale,
            durationDays: doc.durationDays ?? max(1, days.count),
            tags: doc.tags ?? [],
            imageURL: urlFromString(doc.image),
            days: days
        )
    }

    private func urlFromString(_ raw: String?) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let direct = URL(string: raw) { return direct }
        return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
    }
}

private struct MeCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.rounded(24, weight: .bold))
                .foregroundStyle(AppTheme.cardText)
            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.rounded(18, weight: .medium))
                    .foregroundStyle(AppTheme.cardText.opacity(0.84))
            }
            Divider().background(AppTheme.cardText.opacity(0.25))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView(environment: .local())
            .environmentObject(
                UserProgressStore(userProgressRepository: AppEnvironment.local().userProgressRepository)
            )
            .environmentObject(LocalizationManager())
    }
}

private enum MeSelectionRoute: Identifiable {
    case saint(id: String)
    case novena(id: String)

    var id: String {
        switch self {
        case .saint(let id):
            return "saint:\(id)"
        case .novena(let id):
            return "novena:\(id)"
        }
    }
}
