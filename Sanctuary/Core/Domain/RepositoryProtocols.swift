import Foundation

struct FeastDateFilter: Sendable {
    let month: Int
    let day: Int
}

protocol ContentRepository: Sendable {
    func listSaints(
        locale: ContentLocale,
        feastDate: FeastDateFilter?,
        query: String?
    ) async throws -> [Saint]

    func fetchSaint(
        slug: String,
        locale: ContentLocale
    ) async throws -> Saint?

    func listNovenas(
        locale: ContentLocale,
        tag: String?,
        query: String?
    ) async throws -> [Novena]

    func fetchNovena(
        slug: String,
        locale: ContentLocale
    ) async throws -> Novena?

    func listPrayers(
        locale: ContentLocale,
        category: String?,
        query: String?
    ) async throws -> [Prayer]

    func fetchLiturgicalDay(for date: Date) async throws -> LiturgicalDay?
}

protocol UserProgressRepository: Sendable {
    func listFavorites(userID: String) async throws -> [UserFavorite]
    func addFavorite(
        userID: String,
        itemType: FavoriteItemType,
        itemID: String
    ) async throws
    func removeFavorite(
        userID: String,
        itemType: FavoriteItemType,
        itemID: String
    ) async throws

    func listNovenaCommitments(userID: String) async throws -> [UserNovenaCommitment]
    func upsertNovenaCommitment(_ commitment: UserNovenaCommitment) async throws
    func completeNovenaDay(
        userID: String,
        novenaID: String,
        day: Int,
        completedAt: Date
    ) async throws -> UserNovenaCommitment
    func removeNovenaCommitment(
        userID: String,
        novenaID: String
    ) async throws
}

protocol SearchRepository: Sendable {
    func searchSaints(query: String, locale: ContentLocale) async throws -> [Saint]
    func searchNovenas(query: String, locale: ContentLocale) async throws -> [Novena]
    func searchPrayers(query: String, locale: ContentLocale) async throws -> [Prayer]
}
