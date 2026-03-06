import Foundation

actor LocalUserProgressRepository: UserProgressRepository {
    private var favoritesByUser: [String: [String: UserFavorite]] = [:]
    private var commitmentsByUser: [String: [String: UserNovenaCommitment]] = [:]
    private let favoritesKey = "sanctuary.userProgress.favorites.v1"
    private let commitmentsKey = "sanctuary.userProgress.commitments.v1"
    private let resetMigrationKey = "sanctuary.userProgress.reset.v1"

    init() {
        runOneTimeResetMigration()
        loadPersistedState()
    }

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
        persistState()
    }

    func removeFavorite(
        userID: String,
        itemType: FavoriteItemType,
        itemID: String
    ) async throws {
        var favorites = favoritesByUser[userID] ?? [:]
        favorites.removeValue(forKey: favoriteID(itemType: itemType, itemID: itemID))
        favoritesByUser[userID] = favorites
        persistState()
    }

    func listNovenaCommitments(userID: String) async throws -> [UserNovenaCommitment] {
        Array((commitmentsByUser[userID] ?? [:]).values)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsertNovenaCommitment(_ commitment: UserNovenaCommitment) async throws {
        var userCommitments = commitmentsByUser[commitment.userID] ?? [:]
        userCommitments[commitment.novenaID] = commitment
        commitmentsByUser[commitment.userID] = userCommitments
        persistState()
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
        guard existing.status == .active else {
            throw NSError(domain: "LocalUserProgressRepository", code: 409)
        }
        guard day == existing.currentDay else {
            throw NSError(domain: "LocalUserProgressRepository", code: 422)
        }

        let nextCompleted = Set(existing.completedDays + [day]).sorted()
        let nextDay = day + 1

        existing = UserNovenaCommitment(
            userID: existing.userID,
            novenaID: existing.novenaID,
            startedAt: existing.startedAt,
            currentDay: nextDay,
            completedDays: nextCompleted,
            reminder: existing.reminder,
            status: .active,
            updatedAt: completedAt
        )

        var userCommitments = commitmentsByUser[userID] ?? [:]
        userCommitments[novenaID] = existing
        commitmentsByUser[userID] = userCommitments
        persistState()

        return existing
    }

    func removeNovenaCommitment(
        userID: String,
        novenaID: String
    ) async throws {
        var userCommitments = commitmentsByUser[userID] ?? [:]
        userCommitments.removeValue(forKey: novenaID)
        commitmentsByUser[userID] = userCommitments
        persistState()
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = defaults.data(forKey: favoritesKey),
           let decoded = try? decoder.decode([String: [String: UserFavorite]].self, from: data) {
            favoritesByUser = decoded
        }

        if let data = defaults.data(forKey: commitmentsKey),
           let decoded = try? decoder.decode([String: [String: UserNovenaCommitment]].self, from: data) {
            commitmentsByUser = decoded
        }
    }

    private func runOneTimeResetMigration() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: resetMigrationKey) == false else { return }
        defaults.removeObject(forKey: favoritesKey)
        defaults.removeObject(forKey: commitmentsKey)
        defaults.set(true, forKey: resetMigrationKey)
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let favoritesData = try? encoder.encode(favoritesByUser) {
            defaults.set(favoritesData, forKey: favoritesKey)
        }
        if let commitmentsData = try? encoder.encode(commitmentsByUser) {
            defaults.set(commitmentsData, forKey: commitmentsKey)
        }
    }

    private func favoriteID(itemType: FavoriteItemType, itemID: String) -> String {
        "\(itemType.rawValue):\(itemID.lowercased())"
    }
}
