import Foundation
import SwiftUI

struct NovenaDetailView: View {
    let novena: Novena
    var displayYear: Int? = nil
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var progressStore: UserProgressStore

    @State private var selectedDay = 1
    @State private var isFavorite = false
    @State private var relatedSaints: [RelatedSaint] = []
    @State private var selectedSaintSelection: IDSelection?
    @State private var sourceDoc: NovenaDocument?
    @State private var hydratedNovena: Novena?
    @State private var showCompletionModal = false

    private var locale: ContentLocale { localization.language.contentLocale }
    private var effectiveNovena: Novena { hydratedNovena ?? novena }

    private var title: String {
        effectiveNovena.titleByLocale[locale] ?? effectiveNovena.titleByLocale[.en] ?? effectiveNovena.slug
    }

    private var description: String {
        effectiveNovena.descriptionByLocale[locale] ?? effectiveNovena.descriptionByLocale[.en] ?? ""
    }

    private var orderedDays: [NovenaDay] {
        effectiveNovena.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var selectedDayContent: String {
        guard let day = orderedDays.first(where: { $0.dayNumber == selectedDay }) else {
            return ""
        }
        return day.bodyByLocale[locale] ?? day.bodyByLocale[.en] ?? ""
    }

    private var selectedDayTitle: String {
        guard let day = orderedDays.first(where: { $0.dayNumber == selectedDay }) else { return "" }
        return day.titleByLocale[locale] ?? day.titleByLocale[.en] ?? ""
    }

    private var selectedDayScripture: String {
        guard let day = orderedDays.first(where: { $0.dayNumber == selectedDay }) else { return "" }
        return day.scriptureByLocale[locale] ?? day.scriptureByLocale[.en] ?? ""
    }

    private var selectedDayPrayer: String {
        guard let day = orderedDays.first(where: { $0.dayNumber == selectedDay }) else { return "" }
        return day.prayerByLocale[locale] ?? day.prayerByLocale[.en] ?? ""
    }

    private var selectedDayReflection: String {
        guard let day = orderedDays.first(where: { $0.dayNumber == selectedDay }) else { return "" }
        return day.reflectionByLocale[locale] ?? day.reflectionByLocale[.en] ?? ""
    }

    private var novenaStartDateString: String? {
        let year = displayYear ?? Calendar.current.component(.year, from: Date())
        guard let window = ContentStore.novenaServingWindow(id: effectiveNovena.id, year: year) else {
            return nil
        }
        let calendar = Calendar(identifier: .gregorian)
        let startYear = calendar.component(.year, from: window.start)
        let month = calendar.component(.month, from: window.start)
        let day = calendar.component(.day, from: window.start)
        return String(format: "%04d-%02d-%02d", startYear, month, day)
    }

    private var novenaEndDateString: String? {
        let year = displayYear ?? Calendar.current.component(.year, from: Date())
        guard let date = ContentStore.novenaFeastDate(id: effectiveNovena.id, year: year) else {
            return nil
        }
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var currentCommitment: UserNovenaCommitment? {
        progressStore.activeCommitment(for: effectiveNovena.id)
    }

    private var latestCommitment: UserNovenaCommitment? {
        progressStore.commitments
            .filter { $0.novenaID == effectiveNovena.id }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private var completionButtonTitle: String {
        if let active = currentCommitment {
            return "\(localization.t("novena.completeDay")) \(active.currentDay)"
        }
        if latestCommitment?.status == .completed {
            return localization.t("novena.completed")
        }
        return "\(localization.t("novena.completeDay")) 1"
    }

    private var canStartNovena: Bool {
        currentCommitment == nil && latestCommitment?.status != .completed
    }

    private var hasActiveNovena: Bool {
        currentCommitment != nil
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
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(.top, 8)
                    .zIndex(10)

                    if let imageURL = effectiveNovena.imageURL {
                        RemoteHeroImage(url: imageURL)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(title)
                            .font(AppTheme.rounded(48, weight: .bold))
                            .minimumScaleFactor(0.58)
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await progressStore.toggleFavorite(itemType: .novena, itemID: effectiveNovena.id)
                                    isFavorite = progressStore.isFavorite(itemType: .novena, itemID: effectiveNovena.id)
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
                            if let novenaStartDateString {
                                detailMetaChip(icon: "calendar.badge.clock", text: "\(localization.t("detail.novenaStartDate")): \(novenaStartDateString)")
                            }

                            if let novenaEndDateString {
                                detailMetaChip(icon: "calendar", text: "\(localization.t("detail.novenaEndDate")): \(novenaEndDateString)")
                            }

                            if !description.isEmpty {
                                Text(description)
                                    .font(AppTheme.rounded(18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(20)
                    .appGlassCard(cornerRadius: 28)

                    Text(localization.t("novena.chooseDay"))
                        .font(AppTheme.rounded(40, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], spacing: 10) {
                        ForEach(orderedDays, id: \.dayNumber) { day in
                            let active = day.dayNumber == selectedDay
                            Button {
                                selectedDay = day.dayNumber
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(localization.t("novena.dayLabel"))")
                                        .font(AppTheme.rounded(12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.72))
                                    Text("\(day.dayNumber)")
                                        .font(AppTheme.rounded(22, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(active ? AnyShapeStyle(AppTheme.primaryButtonGradient) : AnyShapeStyle(AppTheme.cardBackgroundSoft))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(active ? 0.2 : 0.1), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(active ? 1 : 0.985)
                            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: selectedDay)
                        }
                    }
                    .padding(14)
                    .appGlassCard(cornerRadius: 28)

                    if hasActiveNovena {
                        Button(localization.t("novena.stop")) {
                            Task {
                                await progressStore.stopNovena(novenaID: effectiveNovena.id)
                                selectedDay = 1
                            }
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        .padding(.top, 4)
                    } else if canStartNovena {
                        Button(localization.t("novena.start")) {
                            Task {
                                await progressStore.startNovena(novenaID: effectiveNovena.id)
                                selectedDay = 1
                            }
                        }
                        .buttonStyle(PrimaryPillButtonStyle())
                        .padding(.top, 4)
                    }

                    Divider()
                        .background(Color.white.opacity(0.35))
                        .padding(.top, 6)

                    DetailCard(title: "\(localization.t("novena.dayLabel")) \(selectedDay)") {
                        if selectedDayContent.isEmpty && selectedDayScripture.isEmpty && selectedDayPrayer.isEmpty && selectedDayReflection.isEmpty {
                            Text(localization.t("novena.noDayContent"))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(AppTheme.cardText.opacity(0.84))
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                if !selectedDayTitle.isEmpty {
                                    Text(selectedDayTitle)
                                        .font(AppTheme.rounded(21, weight: .bold))
                                        .foregroundStyle(AppTheme.cardText)
                                }
                                if !selectedDayScripture.isEmpty {
                                    Text(localization.t("novena.scripture"))
                                        .font(AppTheme.rounded(17, weight: .bold))
                                        .foregroundStyle(AppTheme.cardText)
                                    Text(selectedDayScripture)
                                        .font(AppTheme.rounded(17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                                if !selectedDayPrayer.isEmpty {
                                    Text(localization.t("novena.prayer"))
                                        .font(AppTheme.rounded(17, weight: .bold))
                                        .foregroundStyle(AppTheme.cardText)
                                    Text(selectedDayPrayer)
                                        .font(AppTheme.rounded(17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                                if !selectedDayReflection.isEmpty {
                                    Text(localization.t("novena.reflection"))
                                        .font(AppTheme.rounded(17, weight: .bold))
                                        .foregroundStyle(AppTheme.cardText)
                                    Text(selectedDayReflection)
                                        .font(AppTheme.rounded(17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                                if selectedDayScripture.isEmpty && selectedDayPrayer.isEmpty && selectedDayReflection.isEmpty && !selectedDayContent.isEmpty {
                                    Text(selectedDayContent)
                                        .font(AppTheme.rounded(17, weight: .medium))
                                        .foregroundStyle(AppTheme.cardText.opacity(0.9))
                                }
                            }
                        }
                    }

                    if currentCommitment != nil || latestCommitment?.status == .completed {
                        Button(completionButtonTitle) {
                            Task {
                                guard let active = currentCommitment else { return }
                                let total = max(1, effectiveNovena.durationDays)
                                let justCompletedFinalDay = active.currentDay >= total
                                await progressStore.completeCurrentDay(
                                    novenaID: effectiveNovena.id,
                                    totalDays: total
                                )
                                if justCompletedFinalDay {
                                    selectedDay = total
                                    showCompletionModal = true
                                } else if let next = progressStore.activeCommitment(for: effectiveNovena.id)?.currentDay {
                                    selectedDay = min(max(1, next), total)
                                } else {
                                    selectedDay = total
                                }
                            }
                        }
                        .buttonStyle(PrimaryPillButtonStyle())
                        .disabled(latestCommitment?.status == .completed)
                        .padding(.top, 4)
                    }

                    if !relatedSaints.isEmpty {
                        DetailCard(title: localization.t("detail.relatedSaints")) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(relatedSaints) { saint in
                                    Button {
                                        selectedSaintSelection = IDSelection(id: saint.id)
                                    } label: {
                                        HStack {
                                            Text(saint.name)
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
        .onAppear {
            isFavorite = progressStore.isFavorite(itemType: .novena, itemID: novena.id)
            if let day = currentCommitment?.currentDay {
                selectedDay = min(max(1, day), max(1, effectiveNovena.durationDays))
            }
            if selectedDay < 1 {
                selectedDay = orderedDays.first?.dayNumber ?? 1
            }
        }
        .task {
            let id = novena.id
            let loadedDoc: NovenaDocument? = await Task.detached(priority: .userInitiated) {
                ContentStore.novena(id: id)
            }.value
            sourceDoc = loadedDoc
            if let loadedDoc {
                hydratedNovena = mapSourceNovena(loadedDoc)
            }
            await loadRelatedSaints()
        }
        .sheet(item: $selectedSaintSelection) { selection in
            SaintDetailView(
                saint: Saint(
                    id: selection.id,
                    slug: selection.id,
                    name: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                    nameByLocale: [
                        .en: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                        .es: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                        .pl: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id
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
                displayYear: displayYear,
                onClose: { selectedSaintSelection = nil }
            )
        }
        .alert(localization.t("novena.completedTitle"), isPresented: $showCompletionModal) {
            Button(localization.t("common.done")) {
                selectedDay = 1
                Task(priority: .userInitiated) {
                    await progressStore.stopNovena(novenaID: effectiveNovena.id)
                }
            }
        } message: {
            Text("\(localization.t("novena.completedMessagePrefix")) \(title) \(localization.t("novena.completedMessageSuffix"))")
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

    private func loadRelatedSaints() async {
        let id = effectiveNovena.id
        let related = await Task.detached(priority: .userInitiated) {
            RelationResolver.relatedSaints(forNovenaID: id)
        }.value
        relatedSaints = related
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

    private func urlFromString(_ raw: String?) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let direct = URL(string: raw) { return direct }
        return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
    }
}

private struct NovenaIndexCache {
    struct MonthDay {
        let month: Int
        let day: Int
    }

    static let shared = load()

    let fixedFeastDateByID: [String: MonthDay]

    private struct IndexEntry: Decodable {
        let id: String
        let feastRule: FeastRule?
    }

    private struct FeastRule: Decodable {
        let type: String
        let month: Int?
        let day: Int?
    }

    private static func load() -> NovenaIndexCache {
        guard
            let url = Bundle.main.url(forResource: "novenas_index", withExtension: "json", subdirectory: "Resources/LegacyData")
                ?? Bundle.main.url(forResource: "novenas_index", withExtension: "json", subdirectory: "LegacyData")
                ?? Bundle.main.url(forResource: "novenas_index", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([IndexEntry].self, from: data)
        else {
            return NovenaIndexCache(fixedFeastDateByID: [:])
        }

        var map: [String: MonthDay] = [:]
        for entry in entries {
            guard
                let rule = entry.feastRule,
                rule.type == "fixed",
                let month = rule.month,
                let day = rule.day
            else {
                continue
            }
            map[entry.id] = MonthDay(month: month, day: day)
        }
        return NovenaIndexCache(fixedFeastDateByID: map)
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

struct NovenaDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NovenaDetailView(novena: LocalSeedData.novenas[0])
            .environmentObject(LocalizationManager())
            .environmentObject(
                UserProgressStore(userProgressRepository: AppEnvironment.local().userProgressRepository)
            )
    }
}
