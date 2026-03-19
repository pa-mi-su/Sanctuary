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
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        Button {
                            handleBack()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(AppTheme.cardBackgroundSoft)
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
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

                    VStack(alignment: .leading, spacing: 14) {
                        Text(displayName)
                            .font(AppTheme.rounded(46, weight: .bold))
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
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
                                .font(AppTheme.rounded(16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(isFavorite ? AnyShapeStyle(AppTheme.primaryButtonGradient) : AnyShapeStyle(AppTheme.cardBackgroundSoft))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isFavorite)

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            detailMetaChip(icon: "calendar", text: "\(localization.t("detail.feastDate")): \(feastDateString)")
                            if !feastLabel.isEmpty {
                                detailMetaChip(icon: "sparkles", text: feastLabel)
                            }
                        }
                    }
                    .padding(20)
                    .appGlassCard(cornerRadius: 28)

                    if !summary.isEmpty {
                        DetailCard(title: localization.t("detail.summary")) {
                            Text(summary)
                                .font(AppTheme.rounded(18, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                        }
                    }

                    if !biography.isEmpty {
                        DetailCard(title: localization.t("detail.biography")) {
                            Text(biography)
                                .font(AppTheme.rounded(18, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                        }
                    }

                    if !saint.patronages.isEmpty {
                        DetailCard(title: localization.t("detail.patronages")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(saint.patronages, id: \.self) { patronage in
                                    Text("• \(patronage)")
                                        .font(AppTheme.rounded(17, weight: .medium))
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
                                        .font(AppTheme.rounded(17, weight: .medium))
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
                                                .font(AppTheme.rounded(15, weight: .medium))
                                                .underline()
                                                .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                        }
                                    } else {
                                        Text("• \(source)")
                                            .font(AppTheme.rounded(15, weight: .medium))
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
                                        HStack {
                                            Text(novena.title)
                                                .font(AppTheme.rounded(18, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 15)
                                    }
                                    .buttonStyle(RelatedLinkButtonStyle())
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

    private func detailMetaChip(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.glowGold)
            Text(text)
                .font(AppTheme.rounded(15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackgroundSoft)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(Capsule())
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
                .font(AppTheme.rounded(22, weight: .bold))
                .foregroundStyle(AppTheme.cardText)

            Divider().background(AppTheme.cardText.opacity(0.2))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassCard(cornerRadius: 24)
    }
}

private struct RemoteHeroImage: View {
    let url: URL

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.cardBackground)

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
                            .blur(radius: 26)
                            .saturation(0.7)
                            .opacity(0.78)

                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(12)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
        )
        .allowsHitTesting(false)
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private struct RelatedLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackgroundSoft.opacity(configuration.isPressed ? 0.9 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
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
