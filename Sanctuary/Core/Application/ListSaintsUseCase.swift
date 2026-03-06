import Foundation

struct ListSaintsUseCase: Sendable {
    private let contentRepository: any ContentRepository

    init(contentRepository: any ContentRepository) {
        self.contentRepository = contentRepository
    }

    func execute(locale: ContentLocale, query: String?) async throws -> [Saint] {
        try await contentRepository.listSaints(locale: locale, feastDate: nil, query: query)
    }
}

