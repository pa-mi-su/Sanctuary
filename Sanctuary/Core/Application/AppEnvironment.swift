import Foundation

struct AppEnvironment {
    let contentRepository: any ContentRepository
    let userProgressRepository: any UserProgressRepository
    let searchRepository: any SearchRepository

    static func local() -> AppEnvironment {
        // Avoid eager large in-memory seed payload allocation at startup.
        let contentRepository = LocalContentRepository(fallbackToSeed: false)
        let userProgressRepository = LocalUserProgressRepository()
        let searchRepository = LocalSearchRepository(contentRepository: contentRepository)

        return AppEnvironment(
            contentRepository: contentRepository,
            userProgressRepository: userProgressRepository,
            searchRepository: searchRepository
        )
    }
}
