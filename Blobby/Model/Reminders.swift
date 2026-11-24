import Foundation
import UserNotifications

/// Local daily reminders (work with a free Apple ID — no push server needed).
///
/// Instead of one repeating notification, each habit gets one notification per day
/// for the next 7 days. That lets us skip *today's* reminder when the habit is already
/// done. Everything is rebuilt whenever habits change and whenever the app opens.
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Reminders()

    /// Set by the app so a tapped notification can open its habit.
    weak var store: HabitStore?

    private let prefix = "habit-"
    private let daysAhead = 7   // 64 pending notifications max on iOS; 7 days x up to 9 habits fits

    /// Asks the user once; returns whether notifications are allowed.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    func reschedule(_ habits: [Habit]) {
        let center = UNUserNotificationCenter.current()
        let prefix = self.prefix
        let daysAhead = self.daysAhead

        center.getPendingNotificationRequests { pending in
            let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            let cal = Calendar.current
            let now = Date()
            for habit in habits {
                guard let hour = habit.reminderHour else { continue }
                for d in 0..<daysAhead {
                    guard let day = cal.date(byAdding: .day, value: d, to: now) else { continue }
                    if !habit.isScheduled(on: day) { continue }        // rest day
                    if d == 0 && habit.isDone(on: day) { continue }   // already done today: stay quiet

                    var comps = cal.dateComponents([.year, .month, .day], from: day)
                    comps.hour = hour
                    comps.minute = habit.reminderMinute ?? 0
                    guard let fire = cal.date(from: comps), fire > now else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "\(habit.emoji) \(habit.kind.reminderTitle(habit: habit.name))"
                    switch habit.type {
                    case .checkIn:
                        content.body = habit.deadlineText.map { "Check in by \($0) to keep your streak." }
                            ?? "Tap to check in for today."
                    case .limit:
                        content.body = "Limit: \(habit.goal.clean) \(habit.unitLabel(for: habit.goal)) today. Tap to log what you've used."
                    case .count:
                        if d == 0 {
                            let left = max(habit.goal - habit.amount(on: day), 0)
                            content.body = "\(left.clean) \(habit.unitLabel(for: left)) to go today. Tap to log it."
                        } else {
                            content.body = "Today's goal: \(habit.goal.clean) \(habit.unitLabel(for: habit.goal)). Tap to log it."
                        }
                    }
                    content.sound = .default
                    content.userInfo = ["habitID": habit.id.uuidString]

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(identifier: "\(prefix)\(habit.id.uuidString)-\(d)",
                                                        content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the banner even when Blobby is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Tapping a reminder opens that habit.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let raw = response.notification.request.content.userInfo["habitID"] as? String,
           let id = UUID(uuidString: raw) {
            DispatchQueue.main.async { [weak self] in
                self?.store?.openRequest = id
            }
        }
        completionHandler()
    }
}
