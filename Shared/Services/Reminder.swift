import Foundation
import Observation
import UserNotifications

/// One quiet notification a day, at a time the person picks.
@MainActor
@Observable
final class Reminder {
    static let shared = Reminder()
    private static let identifier = "daily-prompts"
    private let defaults: UserDefaults

    private(set) var isOn: Bool
    private(set) var time: DateComponents

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.bool(forKey: "reminder.on")
        time = DateComponents(
            hour: defaults.object(forKey: "reminder.hour") as? Int ?? 8,
            minute: defaults.object(forKey: "reminder.minute") as? Int ?? 0
        )
    }

    var date: Date { Days.calendar.date(from: time) ?? .now }

    /// Turns the reminder on after asking for permission. False when notifications are refused.
    @discardableResult
    func turnOn() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { setOn(false); return false }
        setOn(true)
        schedule()
        return true
    }

    func turnOff() {
        setOn(false)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    func setTime(_ date: Date) {
        time = Days.calendar.dateComponents([.hour, .minute], from: date)
        defaults.set(time.hour, forKey: "reminder.hour")
        defaults.set(time.minute, forKey: "reminder.minute")
        if isOn { schedule() }
    }

    private func setOn(_ on: Bool) {
        isOn = on
        defaults.set(on, forKey: "reminder.on")
    }

    private func schedule() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Today's prompts are here", comment: "Daily reminder title")
        content.body = String(localized: "Three new pictures to write about.", comment: "Daily reminder body")
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        UNUserNotificationCenter.current().add(request)
    }
}
