import Foundation

struct LocalSearchRepository: SearchRepository {
    private let contentRepository: any ContentRepository

    init(contentRepository: any ContentRepository) {
        self.contentRepository = contentRepository
    }

    func searchSaints(query: String, locale: ContentLocale) async throws -> [Saint] {
        try await contentRepository.listSaints(locale: locale, feastDate: nil, query: query)
    }

    func searchNovenas(query: String, locale: ContentLocale) async throws -> [Novena] {
        try await contentRepository.listNovenas(locale: locale, tag: nil, query: query)
    }

    func searchPrayers(query: String, locale: ContentLocale) async throws -> [Prayer] {
        try await contentRepository.listPrayers(locale: locale, category: nil, query: query)
    }
}

