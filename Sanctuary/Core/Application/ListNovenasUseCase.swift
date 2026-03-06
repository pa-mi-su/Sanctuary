import Foundation

struct ListNovenasUseCase: Sendable {
    private let contentRepository: any ContentRepository

    init(contentRepository: any ContentRepository) {
        self.contentRepository = contentRepository
    }

    func execute(locale: ContentLocale, query: String?) async throws -> [Novena] {
        try await contentRepository.listNovenas(locale: locale, tag: nil, query: query)
    }
}

