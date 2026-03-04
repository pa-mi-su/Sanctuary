import Foundation

struct AppEnvironment {
    let contentRepository: any ContentRepository
    let userProgressRepository: any UserProgressRepository
    let searchRepository: any SearchRepository

    static func local() -> AppEnvironment {
        let contentRepository = LocalContentRepository()
        let userProgressRepository = LocalUserProgressRepository()
        let searchRepository = LocalSearchRepository(contentRepository: contentRepository)

        return AppEnvironment(
            contentRepository: contentRepository,
            userProgressRepository: userProgressRepository,
            searchRepository: searchRepository
        )
    }
}

