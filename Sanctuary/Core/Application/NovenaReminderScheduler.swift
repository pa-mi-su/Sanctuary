import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

actor NovenaReminderScheduler {
    static let shared = NovenaReminderScheduler()

    private let morningIdentifier = "sanctuary.novena.digest.morning"
    private let eveningIdentifier = "sanctuary.novena.digest.evening"
    private let morningHour = 8
    private let eveningHour = 20

    func syncDigestReminder(activeCommitmentCount: Int) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningIdentifier, eveningIdentifier])
        guard await ensureAuthorizedForNotifications(center: center) else { return }

        if activeCommitmentCount > 0 {
            let title = "Continue your novena"
            let body = activeCommitmentCount == 1
                ? "You have a novena in progress. Take a calm moment to continue your prayer in Sanctuary."
                : "You have \(activeCommitmentCount) novenas in progress. Take a calm moment to continue your prayer in Sanctuary."

            await scheduleDailyDigest(
                center: center,
                identifier: morningIdentifier,
                title: title,
                body: body,
                hour: morningHour,
                activeCommitmentCount: activeCommitmentCount
            )
            await scheduleDailyDigest(
                center: center,
                identifier: eveningIdentifier,
                title: title,
                body: body,
                hour: eveningHour,
                activeCommitmentCount: activeCommitmentCount
            )
            return
        }

        await scheduleDailyDigest(
            center: center,
            identifier: morningIdentifier,
            title: "Your sanctuary is calling",
            body: "Spend a peaceful moment exploring saints, prayer, and perhaps beginning a novena today.",
            hour: morningHour,
            activeCommitmentCount: 0
        )
        #endif
    }

    #if canImport(UserNotifications)
    private func ensureAuthorizedForNotifications(center: UNUserNotificationCenter) async -> Bool {
        let settings = await notificationSettings(center: center)
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await requestAuthorization(center: center)
        @unknown default:
            return false
        }
    }

    private func scheduleDailyDigest(
        center: UNUserNotificationCenter,
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        activeCommitmentCount: Int
    ) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.timeZone = .current

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "kind": "novena-reminder-digest",
            "inProgressCount": activeCommitmentCount,
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        _ = try? await add(center: center, request: request)
    }

    private func notificationSettings(center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization(center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func add(center: UNUserNotificationCenter, request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    #endif
}
