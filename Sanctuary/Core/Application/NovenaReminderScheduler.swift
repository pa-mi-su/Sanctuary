import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

actor NovenaReminderScheduler {
    static let shared = NovenaReminderScheduler()

    private let morningIdentifier = "sanctuary.novena.digest.morning"
    private let eveningIdentifier = "sanctuary.novena.digest.evening"
    private let morningHour = 9
    private let eveningHour = 18

    func syncDigestReminder(activeCommitmentCount: Int) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningIdentifier, eveningIdentifier])

        guard activeCommitmentCount > 0 else { return }
        guard await isAuthorizedForNotifications(center: center) else { return }

        let title = "Novena reminder"
        let body = "You have \(activeCommitmentCount) novena\(activeCommitmentCount == 1 ? "" : "s") in progress. Take a minute to pray."

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
        #endif
    }

    #if canImport(UserNotifications)
    private func isAuthorizedForNotifications(center: UNUserNotificationCenter) async -> Bool {
        let settings = await notificationSettings(center: center)
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
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
