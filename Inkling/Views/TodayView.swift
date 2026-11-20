import StoreKit
import SwiftUI

/// Where to go from Today.
enum Route: Hashable {
    case prompt(Prompt, day: String)
    case journal
    case day(String)
}

/// The day's three prompts, the week's checks, and the streak.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var today = Date.now
    @State private var path: [Route] = []
    @State private var showSettings = false
    @State private var showPaywall = false
    private let journal = Journal.shared
    private let library = PromptLibrary.bundled

    private var todayKey: String { Days.key(today) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    Button { path.append(.journal) } label: { WeekStrip(today: today, journal: journal) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("today.week")
                    VStack(spacing: 20) {
                        ForEach(library.options(for: today)) { prompt in
                            NavigationLink(value: Route.prompt(prompt, day: todayKey)) {
                                PromptCard(prompt: prompt, entry: journal.entry(day: todayKey, promptID: prompt.id))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.prompt")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("today.settings")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .prompt(prompt, day): PromptView(prompt: prompt, day: day)
                case .journal: JournalView(today: today, path: $path)
                case let .day(day): DayView(day: day, today: today, path: $path, showPaywall: $showPaywall)
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { today = .now } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in today = .now }
        .onChange(of: path) { _, new in if new.isEmpty { askForReviewIfDue() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(today.formatted(.dateTime.weekday(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondary)
                .textCase(.uppercase)
                .kerning(1.2)
            Text(today.formatted(.dateTime.month(.wide).day()))
                .font(Theme.serif(.largeTitle, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, 4)
    }

    /// Back on Today after writing: ask for a rating once the moment has settled and nothing else is on screen.
    private func askForReviewIfDue() {
        let prompt = ReviewPrompt()
        guard prompt.shouldAsk() else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard path.isEmpty, !showSettings, !showPaywall, prompt.shouldAsk() else { return }
            prompt.markAsked()
            requestReview()
        }
    }
}

/// A prompt as a card: its painting, then its words.
struct PromptCard: View {
    let prompt: Prompt
    let entry: JournalEntry?
    var height: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtView(name: prompt.art)
                .frame(height: height)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt.text)
                    .font(Theme.serif(.title3))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let entry, entry.counts {
                    Label(entry.words > 0 ? String(localized: "\(entry.words) words") : String(localized: "Written"), systemImage: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// This week, one circle a day, checked on days with writing.
struct WeekStrip: View {
    let today: Date
    let journal: Journal

    private var days: [Date] {
        let calendar = Days.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).map { Days.adding($0, to: start) }
    }

    var body: some View {
        let streak = journal.currentStreak(today: today)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayMark(day: day, today: today, written: journal.isWritten(day), label: .weekday)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 6) {
                Text(streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(streak > 0 ? Theme.ink : Theme.secondary)
                    .accessibilityIdentifier("today.streak")
                Spacer()
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the calendar")
    }
}

/// One day's circle: a check when written, a ring on today, faint in the future.
struct DayMark: View {
    enum Caption { case weekday, number }
    let day: Date
    let today: Date
    let written: Bool
    let label: Caption

    private var isToday: Bool { Days.key(day) == Days.key(today) }
    private var isFuture: Bool { Days.calendar.startOfDay(for: day) > Days.calendar.startOfDay(for: today) }

    var body: some View {
        VStack(spacing: 6) {
            if label == .weekday {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.secondary)
            }
            ZStack {
                Circle()
                    .fill(written ? Theme.accent : Color.clear)
                Circle()
                    .strokeBorder(isToday && !written ? Theme.accent : Theme.rule, lineWidth: isToday && !written ? 2 : 1)
                    .opacity(written ? 0 : 1)
                if written {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                } else if label == .number {
                    Text(day.formatted(.dateTime.day()))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(isFuture ? Theme.secondary.opacity(0.5) : Theme.ink)
                }
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(written ? String(localized: "Written") : "")
    }
}
