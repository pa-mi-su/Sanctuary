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

    func load<T: Decodable>(_ resourceName: String, as type: T.Type) throws -> T {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoaderError.missingResource(resourceName)
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    enum LoaderError: Error {
        case missingResource(String)
    }
}

