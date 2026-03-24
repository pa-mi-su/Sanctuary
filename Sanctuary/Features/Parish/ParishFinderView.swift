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
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.72 : 1)

                        if viewModel.isLoading {
                            ParishLoadingCard(localization: localization)
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

private struct ParishLoadingCard: View {
    let localization: LocalizationManager
    @State private var animatePulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowBlue.opacity(0.18))
                    .frame(width: 78, height: 78)
                    .blur(radius: 10)

                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(AppTheme.glowGold.opacity(0.16))
                    .frame(width: animatePulse ? 70 : 46, height: animatePulse ? 70 : 46)
                    .blur(radius: animatePulse ? 12 : 6)
                    .scaleEffect(animatePulse ? 1.04 : 0.92)

                SanctuaryCrossShape()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.glowGold, Color.white.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 26, height: 40)
                    .shadow(color: AppTheme.glowGold.opacity(0.35), radius: 10, x: 0, y: 0)
                    .scaleEffect(animatePulse ? 1.04 : 0.96)
            }
            .frame(width: 72, height: 72)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    animatePulse = true
                }
            }

            VStack(spacing: 6) {
                Text(localization.t("parish.searching"))
                    .font(AppTheme.rounded(18, weight: .bold))
                    .foregroundStyle(
                        .white
                    )
                    .multilineTextAlignment(.center)

                Text(localization.t("parish.searchingDetail"))
                    .font(AppTheme.rounded(15, weight: .medium))
                    .foregroundStyle(AppTheme.subtitleText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .appGlassCard(cornerRadius: 24)
    }
}

private struct SanctuaryCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let verticalWidth = rect.width * 0.3
        let horizontalWidth = rect.width * 0.82
        let horizontalHeight = rect.height * 0.18
        let horizontalY = rect.height * 0.28

        var path = Path()
        path.addRoundedRect(
            in: CGRect(
                x: (rect.width - verticalWidth) / 2,
                y: 0,
                width: verticalWidth,
                height: rect.height
            ),
            cornerSize: CGSize(width: verticalWidth / 2, height: verticalWidth / 2)
        )
        path.addRoundedRect(
            in: CGRect(
                x: (rect.width - horizontalWidth) / 2,
                y: horizontalY,
                width: horizontalWidth,
                height: horizontalHeight
            ),
            cornerSize: CGSize(width: horizontalHeight / 2, height: horizontalHeight / 2)
        )

        return path
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
    private var cachedNearestParish: ParishSearchResult?

    override init() {
        super.init()
        manager.delegate = self
    }

    func findNearestParish() {
        guard !isLoading else { return }

        if let cachedNearestParish,
           let lastLocation,
           let currentLocation = manager.location,
           currentLocation.distance(from: lastLocation) < 250 {
            nearestParish = cachedNearestParish
            errorMessageKey = nil
            return
        }

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
            cachedNearestParish = ranked.first
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

    nonisolated private static func formattedAddress(from placemark: MKPlacemark) -> String {
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
        var bestByKey: [String: ParishSearchResult] = [:]

        let primaryPlan = buildPrimarySearchPlan(location: location)
        try await collectCandidates(for: primaryPlan, userLocation: location, bestByKey: &bestByKey)

        let primaryRanked = bestByKey.values.sorted(by: parishResultSort)
        if hasStrongNearbyMatch(in: primaryRanked) {
            return primaryRanked
        }

        let localityHint = await locationHint(for: location)
        let fallbackPlan = buildFallbackSearchPlan(localityHint: localityHint, location: location)
        try await collectCandidates(for: fallbackPlan, userLocation: location, bestByKey: &bestByKey)

        return bestByKey.values.sorted(by: parishResultSort)
    }

    private func buildPrimarySearchPlan(location: CLLocation) -> [(query: String, region: MKCoordinateRegion)] {
        let nearby = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        let local = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )

        let queries = [
            "Catholic parish",
            "Roman Catholic parish",
            "Catholic church"
        ]

        return queries.flatMap { query in
            [(query: query, region: nearby), (query: query, region: local)]
        }
    }

    private func buildFallbackSearchPlan(localityHint: String?, location: CLLocation) -> [(query: String, region: MKCoordinateRegion)] {
        let regional = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )

        var queries = [
            "Roman Catholic church",
            "Roman Catholic parish",
            "Catholic parish near me"
        ]
        if let localityHint, !localityHint.isEmpty {
            queries.append("Roman Catholic parish near \(localityHint)")
        }

        return queries.map { (query: $0, region: regional) }
    }

    private func collectCandidates(
        for plan: [(query: String, region: MKCoordinateRegion)],
        userLocation: CLLocation,
        bestByKey: inout [String: ParishSearchResult]
    ) async throws {
        try await withThrowingTaskGroup(of: [ParishSearchResult].self) { group in
            for step in plan {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = step.query
                    request.resultTypes = [.pointOfInterest, .address]
                    request.region = step.region

                    let response = try await MKLocalSearch(request: request).start()
                    return response.mapItems.compactMap { item in
                        Self.makeCandidate(from: item, userLocation: userLocation)
                    }
                }
            }

            for try await results in group {
                for result in results {
                    let key = dedupeKey(name: result.name, coordinate: result.mapItem.placemark.coordinate)
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
    }

    private func hasStrongNearbyMatch(in ranked: [ParishSearchResult]) -> Bool {
        guard let first = ranked.first else { return false }
        return first.rankingScore >= 500 && first.distanceMeters <= 25_000
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

    nonisolated private static func makeCandidate(from item: MKMapItem, userLocation: CLLocation) -> ParishSearchResult? {
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

    private func dedupeKey(name: String, coordinate: CLLocationCoordinate2D) -> String {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let normalizedName = name.lowercased()
        return "\(normalizedName)|\(String(format: "%.4f", lat))|\(String(format: "%.4f", lon))"
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
