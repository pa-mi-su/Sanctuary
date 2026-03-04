import Foundation
import Combine

@MainActor
final class SaintsListViewModel: ObservableObject {
    @Published private(set) var saints: [Saint] = []
    @Published var query: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let useCase: ListSaintsUseCase
    private var locale: ContentLocale

    init(useCase: ListSaintsUseCase, locale: ContentLocale = .en) {
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
            saints = try await useCase.execute(locale: locale, query: nil)
            errorMessage = nil
        } catch {
            saints = []
            errorMessage = "Unable to load saints."
        }
    }

    func search() async {
        isLoading = true
        defer { isLoading = false }

        do {
            saints = try await useCase.execute(locale: locale, query: query)
            errorMessage = nil
        } catch {
            saints = []
            errorMessage = "Search failed."
        }
    }

    func biography(for saint: Saint) -> String {
        saint.biographyByLocale[locale] ?? saint.biographyByLocale[.en] ?? ""
    }
}
