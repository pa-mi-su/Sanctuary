import SwiftUI

struct SaintDetailView: View {
    let saint: Saint
    var displayYear: Int? = nil
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var progressStore: UserProgressStore
    @State private var isFavorite = false
    @State private var relatedNovenas: [RelatedNovena] = []
    @State private var selectedNovenaSelection: IDSelection?
    @State private var sourceDoc: SaintDocument?

    private var locale: ContentLocale { localization.language.contentLocale }

    private var displayName: String {
        let baseName = localized(base: sourceDoc?.name, es: sourceDoc?.name_es, pl: sourceDoc?.name_pl) ?? saint.displayName(locale: locale)
        let raw = baseName.replacingOccurrences(of: #",\s*\d{3,4}[–-]\d{2,4}$"#, with: "", options: .regularExpression)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var biography: String {
        localized(base: sourceDoc?.biography, es: sourceDoc?.biography_es, pl: sourceDoc?.biography_pl)
            ?? saint.biographyByLocale[locale]
            ?? saint.biographyByLocale[.en]
            ?? ""
    }

    private var summary: String {
        localized(base: sourceDoc?.summary, es: sourceDoc?.summary_es, pl: sourceDoc?.summary_pl)
            ?? saint.summaryByLocale[locale]
            ?? saint.summaryByLocale[.en]
            ?? ""
    }

    private var prayers: [String] {
        sourceDoc?.prayers ?? saint.prayersByLocale[locale] ?? saint.prayersByLocale[.en] ?? []
    }

    private var feastLabel: String {
        localized(base: sourceDoc?.feast, es: sourceDoc?.feast_es, pl: sourceDoc?.feast_pl)
            ?? saint.feastLabelByLocale[locale]
            ?? saint.feastLabelByLocale[.en]
            ?? ""
    }

    private var feastDateString: String {
        let year = displayYear ?? Calendar.current.component(.year, from: Date())
        let parsedMonthDay: (Int, Int)? = {
            guard let mmdd = sourceDoc?.mmdd else { return nil }
            let parts = mmdd.split(separator: "-")
            guard parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]) else { return nil }
            return (m, d)
        }()
        let month = parsedMonthDay?.0 ?? saint.feastMonth
        let day = parsedMonthDay?.1 ?? saint.feastDay
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func handleBack() {
        dismiss()
        onClose?()
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Button {
                            handleBack()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.black.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .highPriorityGesture(TapGesture().onEnded { handleBack() })
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(.top, 8)
                    .zIndex(10)

                    if let imageURL = imageURL {
                        RemoteHeroImage(url: imageURL)
                    }

                    Text(displayName)
                        .font(.system(size: 48, weight: .heavy))
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)

                    Button {
                        Task {
                            await progressStore.toggleFavorite(itemType: .saint, itemID: saint.id)
                            isFavorite = progressStore.isFavorite(itemType: .saint, itemID: saint.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                            Text(isFavorite ? localization.t("detail.savedFavorites") : localization.t("detail.addFavorites"))
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(isFavorite ? AppTheme.purpleButton : Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    Text("\(localization.t("detail.feastDate")): \(feastDateString)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))

                    if !feastLabel.isEmpty {
                        Text(feastLabel)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    if !summary.isEmpty {
                        DetailCard(title: localization.t("detail.summary")) {
                            Text(summary)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                        }
                    }

                    if !biography.isEmpty {
                        DetailCard(title: localization.t("detail.biography")) {
                            Text(biography)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                        }
                    }

                    if !saint.patronages.isEmpty {
                        DetailCard(title: localization.t("detail.patronages")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(saint.patronages, id: \.self) { patronage in
                                    Text("• \(patronage)")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                            }
                        }
                    }

                    if !prayers.isEmpty {
                        DetailCard(title: localization.t("detail.prayers")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(prayers, id: \.self) { prayer in
                                    Text("• \(prayer)")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                            }
                        }
                    }

                    if !sources.isEmpty {
                        DetailCard(title: localization.t("detail.sources")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(sources, id: \.self) { source in
                                    if let url = URL(string: source), source.lowercased().hasPrefix("http") {
                                        Link(destination: url) {
                                            Text("• \(source)")
                                                .font(.system(size: 15, weight: .medium))
                                                .underline()
                                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                        }
                                    } else {
                                        Text("• \(source)")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                    }
                                }
                            }
                        }
                    }

                    if !relatedNovenas.isEmpty {
                        DetailCard(title: localization.t("detail.relatedNovenas")) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(relatedNovenas) { novena in
                                    Button {
                                        selectedNovenaSelection = IDSelection(id: novena.id)
                                    } label: {
                                        Text(novena.title)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(AppTheme.purpleButton)
                                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let saintID = saint.id
            async let loadedDoc: SaintDocument? = Task.detached(priority: .userInitiated) {
                ContentStore.saint(id: saintID)
            }.value
            async let loadedRelated: [RelatedNovena] = Task.detached(priority: .userInitiated) {
                RelationResolver.relatedNovenas(forSaintID: saintID)
            }.value
            sourceDoc = await loadedDoc
            relatedNovenas = await loadedRelated
            isFavorite = progressStore.isFavorite(itemType: .saint, itemID: saint.id)
        }
        .sheet(item: $selectedNovenaSelection) { selection in
            NovenaDetailView(
                novena: Novena(
                    id: selection.id,
                    slug: selection.id,
                    titleByLocale: [.en: relatedNovenas.first(where: { $0.id == selection.id })?.title ?? selection.id],
                    descriptionByLocale: [.en: ""],
                    durationDays: 9,
                    tags: [],
                    imageURL: nil,
                    days: []
                ),
                displayYear: displayYear,
                onClose: { selectedNovenaSelection = nil }
            )
        }
    }

    private var imageURL: URL? {
        if let raw = sourceDoc?.photoUrl, let url = urlFromString(raw) {
            return url
        }
        return saint.imageURL
    }

    private var sources: [String] {
        if let src = sourceDoc?.sources, !src.isEmpty { return src }
        return saint.sources
    }

    private func localized(base: String?, es: String?, pl: String?) -> String? {
        switch locale {
        case .en: return (base?.isEmpty == false ? base : nil) ?? es ?? pl
        case .es: return (es?.isEmpty == false ? es : nil) ?? base ?? pl
        case .pl: return (pl?.isEmpty == false ? pl : nil) ?? base ?? es
        }
    }

    private func urlFromString(_ raw: String?) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let direct = URL(string: raw) { return direct }
        return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
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
}

private struct IDSelection: Identifiable {
    let id: String
}

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.cardText)

            Divider().background(AppTheme.cardText.opacity(0.2))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct RemoteHeroImage: View {
    let url: URL

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.12))

            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView().tint(.white)
                case .success(let image):
                    ZStack {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: 22)
                            .saturation(0.7)
                            .opacity(0.82)

                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(10)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
                            )
                            .padding(2)
                    }
                case .failure:
                    Color.gray.opacity(0.25)
                @unknown default:
                    Color.gray.opacity(0.25)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1.5)
        )
        .allowsHitTesting(false)
    }
}

struct SaintDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SaintDetailView(saint: previewSaint)
            .environmentObject(LocalizationManager())
            .environmentObject(
                UserProgressStore(userProgressRepository: AppEnvironment.local().userProgressRepository)
            )
    }

    private static var previewSaint: Saint {
        LocalSeedData.saints[0]
    }
}
