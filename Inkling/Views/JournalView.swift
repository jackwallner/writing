import SwiftUI

/// The streak, then every month as a wall of the paintings written to, newest first.
struct JournalView: View {
    let today: Date
    @Binding var path: [Route]
    private let journal = Journal.shared
    private let library = PromptLibrary.bundled

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
        let art = journal.artByDay(library: library)
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                summary(days: art.count)
                ForEach(months, id: \.self) { month in
                    MonthWall(month: month, today: today, art: art, written: journal.writtenDays) { day in
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

    private func summary(days: Int) -> some View {
        let streak = journal.currentStreak(today: today)
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: -4) {
                Text(streak, format: .number)
                    .font(Theme.numeral(104))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("day streak")
                    .plaque(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journal.current")
            HStack(alignment: .top, spacing: 0) {
                stat(journal.longestStreak, "Longest", id: "journal.longest")
                divider
                stat(journal.writtenDays.count, "Days", id: "journal.total")
                divider
                stat(journal.totalWords, "Words", id: "journal.words")
            }
            .padding(.vertical, 16)
            .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
        .padding(.top, 4)
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 40).padding(.horizontal, 16)
    }

    private func stat(_ value: Int, _ label: LocalizedStringKey, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .font(Theme.serif(.title2, weight: .medium))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .plaque()
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// One month: each written day is a tile of its painting, the rest are plain numbers.
struct MonthWall: View {
    let month: Date
    let today: Date
    let art: [String: String]
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
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(Theme.serif(.title2, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(month.formatted(.dateTime.year()))
                    .plaque(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .plaque()
                        .foregroundStyle(Theme.secondary)
                        .padding(.bottom, 2)
                        .accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let key = Days.key(day)
                        let isFuture = Days.calendar.startOfDay(for: day) > Days.calendar.startOfDay(for: today)
                        Button { open(day) } label: {
                            DayTile(day: day, isToday: key == Days.key(today), isFuture: isFuture, written: written.contains(key), art: art[key])
                        }
                        .buttonStyle(PressStyle())
                        .disabled(isFuture)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

/// One day on the wall.
struct DayTile: View {
    let day: Date
    let isToday: Bool
    let isFuture: Bool
    let written: Bool
    let art: String?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if written {
                    if let art {
                        ArtView(name: art, size: .tile)
                            .overlay(alignment: .bottomLeading) {
                                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                            }
                    } else {
                        Theme.ink
                    }
                } else if !isFuture {
                    Theme.card
                }
            }
            .clipShape(shape)
            .overlay(alignment: written ? .bottomLeading : .center) {
                Text(day.formatted(.dateTime.day()))
                    .font(written ? .caption2.weight(.bold) : .footnote)
                    .monospacedDigit()
                    .foregroundStyle(written ? Color.white : isFuture ? Theme.secondary.opacity(0.45) : Theme.ink)
                    .padding(written ? 5 : 0)
            }
            .overlay {
                if isToday { shape.strokeBorder(Theme.ink, lineWidth: 1.5) }
            }
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityValue(written ? String(localized: "Written") : "")
    }
}
