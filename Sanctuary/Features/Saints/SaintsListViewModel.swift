import Foundation
import Combine

@MainActor
final class SaintsListViewModel: ObservableObject {
    private struct IndexedSaint: Sendable {
        let saint: Saint
        let document: SearchMatcher.Document
    }

    @Published private(set) var saints: [Saint] = []
    @Published var query: String = "" {
        didSet { scheduleFilter() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let useCase: ListSaintsUseCase
    private var locale: ContentLocale
    private var allSaints: [Saint] = []
    private var indexedSaints: [IndexedSaint] = []
    private var filterTask: Task<Void, Never>?

    init(useCase: ListSaintsUseCase, locale: ContentLocale = .en) {
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
            allSaints = try await useCase.execute(locale: locale, query: nil)
            rebuildIndex()
            scheduleFilter(immediate: true)
            errorMessage = nil
        } catch {
            allSaints = []
            indexedSaints = []
            saints = []
            errorMessage = "Unable to load saints."
        }
    }

    func search() async {
        scheduleFilter(immediate: true)
        errorMessage = nil
    }

    func biography(for saint: Saint) -> String {
        saint.biographyByLocale[locale] ?? saint.biographyByLocale[.en] ?? ""
    }

    func summary(for saint: Saint) -> String {
        saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
    }

    func displayName(for saint: Saint) -> String {
        saint.displayName(locale: locale)
    }

    private func scheduleFilter(immediate: Bool = false) {
        filterTask?.cancel()
        let q = normalized(query)

        guard !q.isEmpty else {
            saints = allSaints
            return
        }

        let snapshot = indexedSaints
        filterTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            guard !Task.isCancelled else { return }

            let filtered = await Task.detached(priority: .userInitiated) {
                let rankedIDs = SearchMatcher.rankedIDs(for: q, in: snapshot) { $0.document }
                let saintByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.saint.id, $0.saint) })
                return rankedIDs.compactMap { saintByID[$0] }
            }.value

            guard !Task.isCancelled else { return }
            guard normalized(self.query) == q else { return }
            self.saints = filtered
        }
    }

    private func rebuildIndex() {
        indexedSaints = allSaints.map { saint in
            let summary = saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
            let bio = saint.biographyByLocale[locale] ?? saint.biographyByLocale[.en] ?? ""
            let document = SearchMatcher.Document(
                itemID: saint.id,
                primaryText: saint.displayName(locale: locale),
                secondaryText: saint.slug,
                auxiliaryText: "\(summary) \(bio)"
            )
            return IndexedSaint(saint: saint, document: document)
        }
    }

    private func normalized(_ value: String) -> String {
        SearchMatcher.normalize(value)
    }
}
