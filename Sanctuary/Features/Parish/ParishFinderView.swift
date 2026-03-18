import SwiftUI
import Combine
import CoreLocation
import MapKit

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
        try await rankedMapKitParishResults(from: location)
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

    private func buildQueries(localityHint: String?) -> [String] {
        var queries = [
            "Catholic parish",
            "Roman Catholic church",
            "Catholic church",
            "Roman Catholic parish",
            "church catholic",
            "Catholic parish near me",
            "Roman Catholic parish near me"
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
        rankingScore -= Int(distanceMeters / 5_000.0)

        return ParishSearchResult(
            name: name,
            address: address,
            websiteURL: item.url,
            distanceMeters: distanceMeters,
            mapItem: item,
            rankingScore: rankingScore
        )
    }

    private func dedupeKey(for item: MKMapItem) -> String {
        let name = (item.name ?? "").lowercased()
        let lat = item.placemark.coordinate.latitude
        let lon = item.placemark.coordinate.longitude
        return "\(name)|\(String(format: "%.4f", lat))|\(String(format: "%.4f", lon))"
    }

    private func isBetterCandidate(_ lhs: ParishSearchResult, than rhs: ParishSearchResult) -> Bool {
        if abs(lhs.distanceMeters - rhs.distanceMeters) > 15.0 {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        return lhs.rankingScore > rhs.rankingScore
    }

    private func parishResultSort(_ lhs: ParishSearchResult, _ rhs: ParishSearchResult) -> Bool {
        if abs(lhs.distanceMeters - rhs.distanceMeters) > 15.0 {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        return lhs.rankingScore > rhs.rankingScore
    }
}
