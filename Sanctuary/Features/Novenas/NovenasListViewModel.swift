import Foundation
import Combine

@MainActor
final class NovenasListViewModel: ObservableObject {
    @Published private(set) var novenas: [Novena] = []
    @Published var query: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let useCase: ListNovenasUseCase
    private var locale: ContentLocale

    init(useCase: ListNovenasUseCase, locale: ContentLocale = .en) {
        self.useCase = useCase
        self.locale = locale
    }

    func setLocale(_ locale: ContentLocale) {
        self.locale = locale
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            novenas = try await useCase.execute(locale: locale, query: nil)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load novenas."
            novenas = []
        }
    }

    func search() async {
        isLoading = true
        defer { isLoading = false }

        do {
            novenas = try await useCase.execute(locale: locale, query: query)
            errorMessage = nil
        } catch {
            errorMessage = "Search failed."
            novenas = []
        }
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
}
