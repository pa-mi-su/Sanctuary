import Foundation

struct LocalBundleJSONLoader {
    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle) {
        self.bundle = bundle
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Decodable>(
        _ resourceName: String,
        as type: T.Type,
        subdirectoryCandidates: [String?] = [nil, "Resources", "LegacyData", "Resources/LegacyData"]
    ) throws -> T {
        guard let url = firstResourceURL(resourceName, withExtension: "json", subdirectoryCandidates: subdirectoryCandidates) else {
            throw LoaderError.missingResource(resourceName)
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    func urlsForJSON(subdirectoryCandidates: [String]) -> [URL] {
        var all: [URL] = []
        if let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            all.append(contentsOf: urls)
        }
        for subdirectory in subdirectoryCandidates {
            if let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: subdirectory) {
                all.append(contentsOf: urls)
            }
        }
        return Array(Set(all))
    }

    private func firstResourceURL(
        _ resourceName: String,
        withExtension ext: String,
        subdirectoryCandidates: [String?]
    ) -> URL? {
        for subdirectory in subdirectoryCandidates {
            if let url = bundle.url(forResource: resourceName, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        let filename = "\(resourceName).\(ext)"
        if let enumerator = FileManager.default.enumerator(
            at: bundle.bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator where url.lastPathComponent == filename {
                return url
            }
        }
        return nil
    }

    enum LoaderError: Error {
        case missingResource(String)
    }
}
