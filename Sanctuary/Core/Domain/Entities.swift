import Foundation

enum ContentLocale: String, Codable, CaseIterable, Sendable {
    case en
    case es
    case pl
}

struct LocalizedText: Codable, Hashable, Sendable {
    let locale: ContentLocale
    let value: String
}

struct Saint: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let feastMonth: Int
    let feastDay: Int
    let imageURL: URL?
    let tags: [String]
    let patronages: [String]
    let feastLabelByLocale: [ContentLocale: String]
    let summaryByLocale: [ContentLocale: String]
    let biographyByLocale: [ContentLocale: String]
    let prayersByLocale: [ContentLocale: [String]]
    let sources: [String]
}

struct NovenaDay: Codable, Hashable, Sendable {
    let dayNumber: Int
    let titleByLocale: [ContentLocale: String]
    let scriptureByLocale: [ContentLocale: String]
    let prayerByLocale: [ContentLocale: String]
    let reflectionByLocale: [ContentLocale: String]
    let bodyByLocale: [ContentLocale: String]
}

struct Novena: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let titleByLocale: [ContentLocale: String]
    let descriptionByLocale: [ContentLocale: String]
    let durationDays: Int
    let tags: [String]
    let imageURL: URL?
    let days: [NovenaDay]
}

struct Prayer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let category: String
    let titleByLocale: [ContentLocale: String]
    let bodyByLocale: [ContentLocale: String]
    let tags: [String]
}

enum LiturgicalSeason: String, Codable, CaseIterable, Sendable {
    case advent
    case christmas
    case lent
    case easter
    case ordinary
}

struct LiturgicalDay: Codable, Hashable, Sendable {
    let date: Date
    let season: LiturgicalSeason
    let rank: String
    let observances: [String]
    let readingURL: URL?
}

enum FavoriteItemType: String, Codable, CaseIterable, Sendable {
    case saint
    case novena
    case prayer
}

struct UserFavorite: Codable, Hashable, Sendable {
    let userID: String
    let itemType: FavoriteItemType
    let itemID: String
    let createdAt: Date
}

enum CommitmentStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
}

struct ReminderConfig: Codable, Hashable, Sendable {
    let enabled: Bool
    let morningHour: Int?
    let eveningHour: Int?
    let timeZoneID: String
}

struct UserNovenaCommitment: Codable, Hashable, Sendable {
    let userID: String
    let novenaID: String
    let startedAt: Date
    let currentDay: Int
    let completedDays: [Int]
    let reminder: ReminderConfig
    let status: CommitmentStatus
    let updatedAt: Date
}
