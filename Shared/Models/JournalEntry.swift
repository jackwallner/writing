import Foundation

/// What was written for one prompt on one day.
struct JournalEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    /// The day it was written, as `Days.key`.
    var day: String
    var promptID: String
    var text: String = ""
    /// Written on paper or somewhere else, so the day counts with no text here.
    var elsewhere: Bool = false
    var created: Date = .now
    var updated: Date = .now

    /// Whether this entry puts a check on its day.
    var counts: Bool { elsewhere || !trimmed.isEmpty }

    var words: Int { JournalEntry.wordCount(text) }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    static func wordCount(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}

/// Streak arithmetic over the set of days that have a check.
enum Streak {
    /// Consecutive written days ending today, or ending yesterday while today is still open.
    static func current(written: Set<String>, today: Date = .now, calendar: Calendar = Days.calendar) -> Int {
        var day = calendar.startOfDay(for: today)
        if !written.contains(Days.key(day, calendar: calendar)) {
            day = Days.adding(-1, to: day, calendar: calendar)
        }
        var count = 0
        while written.contains(Days.key(day, calendar: calendar)) {
            count += 1
            day = Days.adding(-1, to: day, calendar: calendar)
        }
        return count
    }

    /// The longest run of consecutive written days ever.
    static func longest(written: Set<String>, calendar: Calendar = Days.calendar) -> Int {
        let days = written.compactMap { Days.date($0, calendar: calendar) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, Days.adding(1, to: previous, calendar: calendar) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}
