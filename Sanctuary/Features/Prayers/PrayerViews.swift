import SwiftUI
import Combine

@MainActor
final class PrayersSearchViewModel: ObservableObject {
    private struct IndexedPrayer: Sendable {
        let prayer: Prayer
        let searchableText: String
    }

    @Published var query: String = ""
    @Published private(set) var prayers: [Prayer] = []
    @Published private(set) var isLoading = false

    private let environment: AppEnvironment
    private var locale: ContentLocale = .en
    private var allPrayers: [Prayer] = []
    private var indexedPrayers: [IndexedPrayer] = []
    private var filterTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func setLocale(_ locale: ContentLocale) {
        self.locale = locale
        rebuildIndex()
        scheduleFilter(immediate: true)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            allPrayers = try await environment.contentRepository.listPrayers(locale: locale, category: nil, query: nil)
            rebuildIndex()
            scheduleFilter(immediate: true)
        } catch {
            allPrayers = []
            indexedPrayers = []
            prayers = []
        }
    }

    func search() async {
        scheduleFilter()
    }

    func title(for prayer: Prayer, locale: ContentLocale) -> String {
        prayer.titleByLocale[locale] ?? prayer.titleByLocale[.en] ?? prayer.slug
    }

    func subtitle(for prayer: Prayer, locale: ContentLocale) -> String {
        let body = prayer.bodyByLocale[locale] ?? prayer.bodyByLocale[.en] ?? ""
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "..." : firstLine
    }

    private func scheduleFilter(immediate: Bool = false) {
        filterTask?.cancel()
        let q = normalized(query)

        guard !q.isEmpty else {
            prayers = allPrayers
            return
        }

        let snapshot = indexedPrayers
        filterTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
            guard !Task.isCancelled else { return }

            let filtered = await Task.detached(priority: .userInitiated) {
                snapshot
                    .filter { $0.searchableText.contains(q) }
                    .map(\.prayer)
            }.value

            guard !Task.isCancelled else { return }
            guard normalized(self.query) == q else { return }
            self.prayers = filtered
        }
    }

    private func rebuildIndex() {
        indexedPrayers = allPrayers.map { prayer in
            let title = prayer.titleByLocale[locale] ?? prayer.titleByLocale[.en] ?? prayer.slug
            let body = prayer.bodyByLocale[locale] ?? prayer.bodyByLocale[.en] ?? ""
            let blob = "\(title) \(prayer.slug) \(prayer.category) \(body) \(prayer.tags.joined(separator: " "))"
            return IndexedPrayer(prayer: prayer, searchableText: normalized(blob))
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PrayersSearchView: View {
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: PrayersSearchViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: PrayersSearchViewModel(environment: environment))
    }

    private var locale: ContentLocale { localization.language.contentLocale }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack {
                        Button {
                            dismiss()
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
                        .highPriorityGesture(TapGesture().onEnded { dismiss() })
                        Spacer()
                        Text(localization.t("search.prayersTitle"))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(.white)
                        Spacer()
                        Color.clear.frame(width: 52, height: 52)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.cardText.opacity(0.75))
                        TextField(localization.t("search.prayersPrompt"), text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await viewModel.search() } }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())

                    HStack {
                        Text("\(viewModel.prayers.count) \(localization.t("search.results"))")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                    }

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.prayers) { prayer in
                                NavigationLink {
                                    PrayerDetailView(prayer: prayer)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.title(for: prayer, locale: locale))
                                            .font(.system(size: 20, weight: .heavy))
                                            .foregroundStyle(AppTheme.cardText)
                                        Text(viewModel.subtitle(for: prayer, locale: locale))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(AppTheme.cardText.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                if viewModel.isLoading {
                    ProgressView().tint(.white)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            viewModel.setLocale(locale)
            await viewModel.load()
        }
        .onChange(of: localization.language) { newValue in
            Task {
                viewModel.setLocale(newValue.contentLocale)
                await viewModel.search()
            }
        }
        .onChange(of: viewModel.query) { _ in
            Task { await viewModel.search() }
        }
    }
}

private struct BundledPrayerDocument: Decodable {
    struct Source: Decodable {
        let type: String?
        let title: String?
    }

    let id: String
    let title: String?
    let title_es: String?
    let title_pl: String?
    let alternateTitle: String?
    let alternateTitle_es: String?
    let alternateTitle_pl: String?
    let photoUrl: String?
    let prayerText: String?
    let prayerText_es: String?
    let prayerText_pl: String?
    let note: String?
    let note_es: String?
    let note_pl: String?
    let source: Source?
}

private enum BundledPrayerStore {
    private static var cache: [String: BundledPrayerDocument] = [:]
    private static let lock = NSLock()

    static func prayer(id: String) -> BundledPrayerDocument? {
        lock.lock()
        if let cached = cache[id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loader = LocalBundleJSONLoader(bundle: .main)
        let subdirs: [String?] = ["Resources/LegacyData/prayers", "LegacyData/prayers", "prayers", nil]
        guard let loaded = try? loader.load(id, as: BundledPrayerDocument.self, subdirectoryCandidates: subdirs) else {
            return nil
        }

        lock.lock()
        cache[id] = loaded
        lock.unlock()
        return loaded
    }
}

struct PrayerDetailView: View {
    let prayer: Prayer
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @State private var bundledPrayer: BundledPrayerDocument?

    private var locale: ContentLocale { localization.language.contentLocale }

    private var title: String {
        localizedFromBundle(base: bundledPrayer?.title, es: bundledPrayer?.title_es, pl: bundledPrayer?.title_pl)
            ?? prayer.titleByLocale[locale]
            ?? prayer.titleByLocale[.en]
            ?? prayer.slug
    }

    private var alternateTitle: String {
        localizedFromBundle(base: bundledPrayer?.alternateTitle, es: bundledPrayer?.alternateTitle_es, pl: bundledPrayer?.alternateTitle_pl) ?? ""
    }

    private var prayerText: String {
        localizedFromBundle(base: bundledPrayer?.prayerText, es: bundledPrayer?.prayerText_es, pl: bundledPrayer?.prayerText_pl)
            ?? prayer.bodyByLocale[locale]
            ?? prayer.bodyByLocale[.en]
            ?? ""
    }

    private var noteText: String {
        localizedFromBundle(base: bundledPrayer?.note, es: bundledPrayer?.note_es, pl: bundledPrayer?.note_pl) ?? ""
    }

    private var sourceTitle: String {
        bundledPrayer?.source?.title ?? ""
    }

    private var imageURL: URL? {
        guard let raw = bundledPrayer?.photoUrl, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    private func handleBack() {
        dismiss()
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Button { handleBack() } label: {
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

                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(.top, 8)
                    .zIndex(10)

                    if let imageURL {
                        PrayerHeroImage(url: imageURL)
                    }

                    Text(title)
                        .font(.system(size: 56, weight: .heavy))
                        .minimumScaleFactor(0.62)
                        .foregroundStyle(.white)

                    if !alternateTitle.isEmpty {
                        Text(alternateTitle)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    PrayerSectionCard(title: localization.t("novena.prayer"), bodyText: prayerText)

                    if !noteText.isEmpty {
                        PrayerSectionCard(title: localization.t("detail.note"), bodyText: noteText)
                    }

                    if !sourceTitle.isEmpty {
                        Text(sourceTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let id = prayer.id
            let loaded = await Task.detached(priority: .userInitiated) {
                BundledPrayerStore.prayer(id: id)
            }.value
            bundledPrayer = loaded
        }
    }

    private func localizedFromBundle(base: String?, es: String?, pl: String?) -> String? {
        switch locale {
        case .en: return (base?.isEmpty == false ? base : nil) ?? es ?? pl
        case .es: return (es?.isEmpty == false ? es : nil) ?? base ?? pl
        case .pl: return (pl?.isEmpty == false ? pl : nil) ?? base ?? es
        }
    }
}

private struct PrayerSectionCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.cardText)
            Divider().background(AppTheme.cardText.opacity(0.2))
            Text(bodyText)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.cardText.opacity(0.92))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PrayerHeroImage: View {
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
                    Image(systemName: "photo")
                        .font(.system(size: 46))
                        .foregroundStyle(.white.opacity(0.7))
                @unknown default:
                    EmptyView()
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
