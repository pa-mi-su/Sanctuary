import Foundation

actor LocalUserProgressRepository: UserProgressRepository {
    private var favoritesByUser: [String: [String: UserFavorite]] = [:]
    private var commitmentsByUser: [String: [String: UserNovenaCommitment]] = [:]

    func listFavorites(userID: String) async throws -> [UserFavorite] {
        let favorites = favoritesByUser[userID] ?? [:]
        return Array(favorites.values)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func addFavorite(
        userID: String,
        itemType: FavoriteItemType,
        itemID: String
    ) async throws {
        var favorites = favoritesByUser[userID] ?? [:]
        let favorite = UserFavorite(
            userID: userID,
            itemType: itemType,
            itemID: itemID,
            createdAt: Date()
        )
        favorites[favoriteID(itemType: itemType, itemID: itemID)] = favorite
        favoritesByUser[userID] = favorites
    }

    func removeFavorite(
        userID: String,
        itemType: FavoriteItemType,
        itemID: String
    ) async throws {
        var favorites = favoritesByUser[userID] ?? [:]
        favorites.removeValue(forKey: favoriteID(itemType: itemType, itemID: itemID))
        favoritesByUser[userID] = favorites
    }

    func listNovenaCommitments(userID: String) async throws -> [UserNovenaCommitment] {
        Array((commitmentsByUser[userID] ?? [:]).values)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsertNovenaCommitment(_ commitment: UserNovenaCommitment) async throws {
        var userCommitments = commitmentsByUser[commitment.userID] ?? [:]
        userCommitments[commitment.novenaID] = commitment
        commitmentsByUser[commitment.userID] = userCommitments
    }

    func completeNovenaDay(
        userID: String,
        novenaID: String,
        day: Int,
        completedAt: Date
    ) async throws -> UserNovenaCommitment {
        guard var existing = commitmentsByUser[userID]?[novenaID] else {
            throw NSError(domain: "LocalUserProgressRepository", code: 404)
        }

        let nextCompleted = Set(existing.completedDays + [day]).sorted()
        let maxCompleted = nextCompleted.max() ?? existing.currentDay
        let nextStatus: CommitmentStatus = maxCompleted >= existing.currentDay ? .active : existing.status

        existing = UserNovenaCommitment(
            userID: existing.userID,
            novenaID: existing.novenaID,
            startedAt: existing.startedAt,
            currentDay: max(existing.currentDay, maxCompleted + 1),
            completedDays: nextCompleted,
            reminder: existing.reminder,
            status: nextStatus,
            updatedAt: completedAt
        )

        var userCommitments = commitmentsByUser[userID] ?? [:]
        userCommitments[novenaID] = existing
        commitmentsByUser[userID] = userCommitments

        return existing
    }

    private func favoriteID(itemType: FavoriteItemType, itemID: String) -> String {
        "\(itemType.rawValue):\(itemID.lowercased())"
    }
}
