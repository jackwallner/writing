import Foundation

/// Calendar days as the person lives them, in the device's current time zone.
enum Days {
    /// The library's first day. Any fixed date works; it only sets the order.
    static let epoch: Date = {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 1
        parts.day = 1
        parts.hour = 12
        return Calendar(identifier: .gregorian).date(from: parts) ?? .distantPast
    }()

    /// Built fresh each time so a time zone change while the app is open is followed.
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar
    }

    /// "2026-11-20" for the day containing `date`.
    static func key(_ date: Date, calendar: Calendar = Days.calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The start of the day a key names, or nil for a malformed key.
    static func date(_ key: String, calendar: Calendar = Days.calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func adding(_ days: Int, to date: Date, calendar: Calendar = Days.calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) ?? date
    }
}
