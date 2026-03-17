import SwiftUI
import Combine
import CoreLocation
import MapKit

private enum OSMParishSearch {
    static let endpoints = [
        URL(string: "https://overpass-api.de/api/interpreter")!,
        URL(string: "https://overpass.kumi.systems/api/interpreter")!
    ]
    static let timeoutNanoseconds: UInt64 = 2_500_000_000

    struct Response: Decodable {
        let elements: [Element]
    }

    struct Element: Decodable {
        struct Center: Decodable {
            let lat: Double
            let lon: Double
        }

        let lat: Double?
        let lon: Double?
        let center: Center?
        let tags: [String: String]?

        var coordinate: CLLocationCoordinate2D? {
            if let lat, let lon {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            if let center {
                return CLLocationCoordinate2D(latitude: center.lat, longitude: center.lon)
            }
            return nil
        }
    }
}

private enum ParishSearchHeuristics {
    static let explicitCatholicTokens = [
        "catholic",
        "roman catholic",
        "catholic parish",
        "roman catholic parish",
        "archdiocese",
        "diocese"
    ]

    static let catholicStyleTokens = [
        "catholic",
        "roman catholic",
        "parish",
        "cathedral",
        "basilica",
        "shrine",
        "abbey",
        "oratory",
        "rectory",
        "our lady",
        "holy family",
        "sacred heart",
        "immaculate",
        "annunciation",
        "assumption",
        "corpus christi",
        "st ",
        "st.",
        "saint "
    ]

    static let exclusionTokens = [
        "baptist",
        "lutheran",
        "episcopal",
        "anglican",
        "methodist",
        "presbyterian",
        "pentecostal",
        "assembly of god",
        "adventist",
        "church of christ",
        "non denominational",
        "nondenominational",
        "jehovah",
        "kingdom hall",
        "mormon",
        "lds",
        "temple beth",
        "synagogue",
        "mosque",
        "school",
        "academy",
        "center",
        "office"
    ]
}

struct ParishFinderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel = ParishFinderViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(localization.t("parish.title"))
                            .font(AppTheme.rounded(36, weight: .bold))
                            .foregroundStyle(.white)

                        Text(localization.t("parish.subtitle"))
                            .font(AppTheme.rounded(17, weight: .medium))
                            .foregroundStyle(AppTheme.subtitleText)

                        Button(localization.t("parish.findButton")) {
                            viewModel.findNearestParish()
                        }
                        .buttonStyle(PrimaryPillButtonStyle())

                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(.white)
                                Text(localization.t("parish.searching"))
                                    .font(AppTheme.rounded(15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.vertical, 8)
                        }

                        if let errorKey = viewModel.errorMessageKey {
                            Text(localization.t(errorKey))
                                .font(AppTheme.rounded(15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.vertical, 8)
                        }

                        if let parish = viewModel.nearestParish {
                            ParishCard(
                                parish: parish,
                                localization: localization,
                                onOpenMaps: { viewModel.openInMaps() },
                                onOpenWebsite: {
                                    if let websiteURL = parish.websiteURL {
                                        openURL(websiteURL)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.t("common.close")) { dismiss() }
                        .foregroundStyle(.white)
                }
#else
                ToolbarItem(placement: .navigation) {
                    Button(localization.t("common.close")) { dismiss() }
                        .foregroundStyle(.white)
                }
#endif
            }
        }
    }
}

private struct ParishCard: View {
    let parish: ParishSearchResult
    let localization: LocalizationManager
    let onOpenMaps: () -> Void
    let onOpenWebsite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(parish.name)
                .font(AppTheme.rounded(24, weight: .bold))
                .foregroundStyle(AppTheme.cardText)

            Text(parish.address)
                .font(AppTheme.rounded(16, weight: .medium))
                .foregroundStyle(AppTheme.cardText.opacity(0.88))

            Text("\(localization.t("parish.distance")): \(parish.distanceText)")
                .font(AppTheme.rounded(15, weight: .medium))
                .foregroundStyle(AppTheme.cardText.opacity(0.85))

            Button(localization.t("parish.openMaps")) {
                onOpenMaps()
            }
            .buttonStyle(PrimaryPillButtonStyle())

            if parish.websiteURL != nil {
                Button(localization.t("parish.website")) {
                    onOpenWebsite()
                }
                .buttonStyle(SecondaryPillButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ParishSearchResult {
    let name: String
    let address: String
    let websiteURL: URL?
    let distanceMeters: CLLocationDistance
    let mapItem: MKMapItem
    let rankingScore: Int

    var distanceText: String {
        if distanceMeters >= 1609.34 {
            let miles = distanceMeters / 1609.34
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.0f m", distanceMeters)
    }
}

@MainActor
final class ParishFinderViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var nearestParish: ParishSearchResult?
    @Published var isLoading = false
    @Published var errorMessageKey: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var pendingSearch = false
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
    }

    func findNearestParish() {
        nearestParish = nil
        errorMessageKey = nil
        isLoading = true

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            pendingSearch = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isLoading = false
            errorMessageKey = "parish.error.locationDenied"
        @unknown default:
            isLoading = false
            errorMessageKey = "parish.error.generic"
        }
    }

    func openInMaps() {
        guard let mapItem = nearestParish?.mapItem else { return }
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pendingSearch else { return }
        pendingSearch = false
        findNearestParish()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessageKey = "parish.error.generic"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLoading = false
            errorMessageKey = "parish.error.noLocation"
            return
        }
        lastLocation = location
        Task { await searchNearestParish(from: location) }
    }

    private func searchNearestParish(from location: CLLocation) async {
        do {
            let ranked = try await rankedParishResults(from: location)
            nearestParish = ranked.first
            if nearestParish == nil {
                errorMessageKey = "parish.error.noneFound"
            } else {
                errorMessageKey = nil
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessageKey = "parish.error.generic"
        }
    }

    private func formattedAddress(from placemark: MKPlacemark) -> String {
        let parts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return placemark.title ?? "Address unavailable"
        }
        return parts.joined(separator: ", ")
    }

    private func rankedParishResults(from location: CLLocation) async throws -> [ParishSearchResult] {
        let mapKitResults = try await rankedMapKitParishResults(from: location)
        if !mapKitResults.isEmpty {
            return mapKitResults
        }

        // Maps is the primary path because it is much more reliable on-device.
        // Public Overpass instances are only used as a short backup when Maps finds nothing.
        let osmResults = try? await timeoutAfter(OSMParishSearch.timeoutNanoseconds) {
            try await self.rankedOSMParishResults(from: location)
        }
        if let osmResults, !osmResults.isEmpty {
            return osmResults
        }

        return []
    }

    private func rankedOSMParishResults(from location: CLLocation) async throws -> [ParishSearchResult] {
        let query = buildOverpassQuery(from: location.coordinate)
        let body = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        var collected: [ParishSearchResult] = []

        for endpoint in OSMParishSearch.endpoints {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                continue
            }

            let decoded = try JSONDecoder().decode(OSMParishSearch.Response.self, from: data)
            collected = decoded.elements.compactMap { makeOSMCandidate(from: $0, userLocation: location) }
            if !collected.isEmpty { break }
        }

        return collected.sorted(by: parishResultSort)
    }

    private func rankedMapKitParishResults(from location: CLLocation) async throws -> [ParishSearchResult] {
        let localityHint = await locationHint(for: location)
        let queries = buildQueries(localityHint: localityHint)
        let regions = [
            MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)),
            MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)),
            MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)),
            MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.7, longitudeDelta: 0.7))
        ]

        var bestByKey: [String: ParishSearchResult] = [:]

        for query in queries {
            for region in regions {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = [.pointOfInterest, .address]
                request.region = region

                let response = try await MKLocalSearch(request: request).start()
                for item in response.mapItems {
                    guard let result = makeCandidate(from: item, userLocation: location) else { continue }
                    let key = dedupeKey(for: item)
                    if let existing = bestByKey[key] {
                        if isBetterCandidate(result, than: existing) {
                            bestByKey[key] = result
                        }
                    } else {
                        bestByKey[key] = result
                    }
                }
            }
        }

        return bestByKey.values.sorted(by: parishResultSort)
    }

    private func buildOverpassQuery(from coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.6f", coordinate.latitude)
        let lon = String(format: "%.6f", coordinate.longitude)
        return """
        [out:json][timeout:15];
        (
          nwr(around:30000,\(lat),\(lon))["amenity"="place_of_worship"]["religion"~"^(christian|roman_catholic|catholic)$",i]["denomination"~"(roman_)?catholic",i];
          nwr(around:30000,\(lat),\(lon))["amenity"="place_of_worship"]["name"~"Catholic|Parish|Our Lady|Sacred Heart|Immaculate|Holy Family|Saint |St\\.",i];
          nwr(around:30000,\(lat),\(lon))["building"~"church|cathedral|chapel|basilica",i]["name"~"Catholic|Parish|Our Lady|Sacred Heart|Immaculate|Holy Family|Saint |St\\.",i];
        );
        out center tags;
        """
    }

    private func buildQueries(localityHint: String?) -> [String] {
        var queries = [
            "Catholic parish",
            "Roman Catholic church",
            "Catholic church",
            "Roman Catholic parish",
            "church catholic"
        ]
        if let localityHint, !localityHint.isEmpty {
            queries.append("Catholic parish near \(localityHint)")
            queries.append("Roman Catholic church near \(localityHint)")
            queries.append("Roman Catholic parish near \(localityHint)")
        }
        return queries
    }

    private func locationHint(for location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            return placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea
        } catch {
            return nil
        }
    }

    private func makeCandidate(from item: MKMapItem, userLocation: CLLocation) -> ParishSearchResult? {
        guard let parishLocation = item.placemark.location else { return nil }

        let name = item.name ?? "Catholic Parish"
        let address = formattedAddress(from: item.placemark)
        let urlString = item.url?.absoluteString ?? ""
        let haystack = "\(name) \(address) \(urlString)".lowercased()

        if ParishSearchHeuristics.exclusionTokens.contains(where: { haystack.contains($0) }) {
            return nil
        }

        let explicitCatholic = ParishSearchHeuristics.explicitCatholicTokens.contains { haystack.contains($0) }
        let catholicStyleHits = ParishSearchHeuristics.catholicStyleTokens.filter { haystack.contains($0) }.count
        guard explicitCatholic || catholicStyleHits > 0 else { return nil }

        var rankingScore = 0
        if explicitCatholic { rankingScore += 500 }
        rankingScore += catholicStyleHits * 80
        if name.lowercased().contains("parish") { rankingScore += 120 }
        if name.lowercased().contains("roman catholic") { rankingScore += 100 }

        let distanceMeters = parishLocation.distance(from: userLocation)
        rankingScore -= Int(distanceMeters / 1_500.0)

        return ParishSearchResult(
            name: name,
            address: address,
            websiteURL: item.url,
            distanceMeters: distanceMeters,
            mapItem: item,
            rankingScore: rankingScore
        )
    }

    private func makeOSMCandidate(from element: OSMParishSearch.Element, userLocation: CLLocation) -> ParishSearchResult? {
        guard let coordinate = element.coordinate else { return nil }
        let tags = element.tags ?? [:]
        let name = tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let haystack = [
            name,
            tags["operator"],
            tags["denomination"],
            tags["religion"],
            tags["addr:city"],
            tags["addr:state"]
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        if ParishSearchHeuristics.exclusionTokens.contains(where: { haystack.contains($0) }) {
            return nil
        }

        let catholicStyleHits = ParishSearchHeuristics.catholicStyleTokens.filter { haystack.contains($0) }.count
        let explicitCatholic =
            (tags["denomination"]?.lowercased().contains("catholic") == true) ||
            (tags["religion"]?.lowercased().contains("catholic") == true) ||
            (haystack.contains("catholic"))

        guard explicitCatholic || catholicStyleHits > 0 else { return nil }

        let parishLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceMeters = parishLocation.distance(from: userLocation)

        var rankingScore = 0
        if explicitCatholic { rankingScore += 1000 }
        if tags["amenity"] == "place_of_worship" { rankingScore += 150 }
        if tags["building"]?.lowercased().contains("church") == true { rankingScore += 100 }
        rankingScore += catholicStyleHits * 80
        if name.lowercased().contains("parish") { rankingScore += 120 }
        if name.lowercased().contains("roman catholic") { rankingScore += 100 }
        rankingScore -= Int(distanceMeters / 1_500.0)

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        let websiteURL = URL(string: tags["website"] ?? tags["contact:website"] ?? "")

        return ParishSearchResult(
            name: name,
            address: formattedAddress(from: tags),
            websiteURL: websiteURL,
            distanceMeters: distanceMeters,
            mapItem: mapItem,
            rankingScore: rankingScore
        )
    }

    private func dedupeKey(for item: MKMapItem) -> String {
        let name = (item.name ?? "").lowercased()
        let lat = item.placemark.coordinate.latitude
        let lon = item.placemark.coordinate.longitude
        return "\(name)|\(String(format: "%.4f", lat))|\(String(format: "%.4f", lon))"
    }

    private func formattedAddress(from tags: [String: String]) -> String {
        let parts = [
            tags["addr:housenumber"],
            tags["addr:street"],
            tags["addr:city"],
            tags["addr:state"],
            tags["addr:postcode"]
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.isEmpty ? "Address unavailable" : parts.joined(separator: ", ")
    }

    private func isBetterCandidate(_ lhs: ParishSearchResult, than rhs: ParishSearchResult) -> Bool {
        if abs(lhs.distanceMeters - rhs.distanceMeters) > 160.0 {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }
        return lhs.distanceMeters < rhs.distanceMeters
    }

    private func parishResultSort(_ lhs: ParishSearchResult, _ rhs: ParishSearchResult) -> Bool {
        if abs(lhs.distanceMeters - rhs.distanceMeters) > 160.0 {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }
        return lhs.distanceMeters < rhs.distanceMeters
    }

    private func timeoutAfter<T>(
        _ nanoseconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
