import Foundation
import Combine

@MainActor
final class NovenasListViewModel: ObservableObject {
    private struct IndexedNovena: Sendable {
        let novena: Novena
        let document: SearchMatcher.Document
    }

    @Published private(set) var novenas: [Novena] = []
    @Published var query: String = "" {
        didSet { scheduleFilter() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let useCase: ListNovenasUseCase
    private var locale: ContentLocale
    private var allNovenas: [Novena] = []
    private var indexedNovenas: [IndexedNovena] = []
    private var filterTask: Task<Void, Never>?

    init(useCase: ListNovenasUseCase, locale: ContentLocale = .en) {
        self.useCase = useCase
        self.locale = locale
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
            allNovenas = try await useCase.execute(locale: locale, query: nil)
            rebuildIndex()
            scheduleFilter(immediate: true)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load novenas."
            allNovenas = []
            indexedNovenas = []
            novenas = []
        }
    }

    func search() async {
        scheduleFilter(immediate: true)
        errorMessage = nil
    }

    func title(for novena: Novena) -> String {
        novena.titleByLocale[locale] ?? novena.titleByLocale[.en] ?? novena.slug
    }

    func summary(for novena: Novena) -> String {
        novena.descriptionByLocale[locale] ?? novena.descriptionByLocale[.en] ?? ""
    }

    func dayText(for novena: Novena) -> String {
        "\(novena.durationDays)-day novena"
    }

    private func scheduleFilter(immediate: Bool = false) {
        filterTask?.cancel()
        let q = normalized(query)

        guard !q.isEmpty else {
            novenas = allNovenas
            return
        }

        let snapshot = indexedNovenas
        filterTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            guard !Task.isCancelled else { return }

            let filtered = await Task.detached(priority: .userInitiated) {
                let rankedIDs = SearchMatcher.rankedIDs(for: q, in: snapshot) { $0.document }
                let novenaByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.novena.id, $0.novena) })
                return rankedIDs.compactMap { novenaByID[$0] }
            }.value

            guard !Task.isCancelled else { return }
            guard normalized(self.query) == q else { return }
            self.novenas = filtered
        }
    }

    private func rebuildIndex() {
        indexedNovenas = allNovenas.map { novena in
            let titleText = title(for: novena)
            let summaryText = summary(for: novena)
            let tags = novena.tags.joined(separator: " ")
            let document = SearchMatcher.Document(
                itemID: novena.id,
                primaryText: titleText,
                secondaryText: "\(novena.slug) \(tags)",
                auxiliaryText: summaryText
            )
            return IndexedNovena(novena: novena, document: document)
        }
    }

    private func normalized(_ value: String) -> String {
        SearchMatcher.normalize(value)
    }
}
