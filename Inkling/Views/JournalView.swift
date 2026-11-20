import SwiftUI

/// Every month with its checked days, newest first, under the streak numbers.
struct JournalView: View {
    let today: Date
    @Binding var path: [Route]
    private let journal = Journal.shared

    /// The first day of each month from the earliest writing (or this month) to now, newest first.
    private var months: [Date] {
        let calendar = Days.calendar
        let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let earliest = journal.writtenDays.compactMap { Days.date($0) }.min() ?? today
        let firstMonth = calendar.dateInterval(of: .month, for: min(earliest, today))?.start ?? thisMonth
        var result: [Date] = []
        var month = thisMonth
        while month >= firstMonth, result.count < 240 {
            result.append(month)
            month = calendar.date(byAdding: .month, value: -1, to: month) ?? firstMonth.addingTimeInterval(-1)
        }
        return result
    }

    var body: some View {
        let written = journal.writtenDays
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(alignment: .top, spacing: 12) {
                    stat(journal.currentStreak(today: today), "Day streak", id: "journal.current")
                    stat(journal.longestStreak, "Longest", id: "journal.longest")
                    stat(written.count, "Days written", id: "journal.total")
                }
                ForEach(months, id: \.self) { month in
                    MonthGrid(month: month, today: today, written: written) { day in
                        path.append(.day(Days.key(day)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: Int, _ label: LocalizedStringKey, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(Theme.serif(.title, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// One month as a grid of day circles.
struct MonthGrid: View {
    let month: Date
    let today: Date
    let written: Set<String>
    let open: (Date) -> Void

    private var cells: [Date?] {
        let calendar = Days.calendar
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days = range.map { Days.adding($0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    private var weekdaySymbols: [String] {
        let calendar = Days.calendar
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        VStack(alignment: .leading, spacing: 12) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(Theme.serif(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isFuture = Days.calendar.startOfDay(for: day) > Days.calendar.startOfDay(for: today)
                        Button { open(day) } label: {
                            DayMark(day: day, today: today, written: written.contains(Days.key(day)), label: .number)
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
    }
}
