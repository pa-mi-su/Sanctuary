import SwiftUI
import Combine
import CoreLocation
import MapKit

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
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Catholic Church"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let ranked = response.mapItems
                .filter { $0.placemark.location != nil }
                .map { item -> ParishSearchResult in
                    let parishLocation = item.placemark.location ?? location
                    return ParishSearchResult(
                        name: item.name ?? "Catholic Parish",
                        address: formattedAddress(from: item.placemark),
                        websiteURL: item.url,
                        distanceMeters: parishLocation.distance(from: location),
                        mapItem: item
                    )
                }
                .sorted { $0.distanceMeters < $1.distanceMeters }

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
}
