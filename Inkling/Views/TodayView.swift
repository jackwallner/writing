import StoreKit
import SwiftUI

/// Where to go from Today.
enum Route: Hashable {
    /// `source` names the card the page grows out of.
    case prompt(Prompt, day: String, source: String)
    case journal
    case day(String)
}

/// The day's three paintings, hung one at a time in a room lit by their own colors.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var today = Date.now
    @State private var path: [Route] = []
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var page: String?
    @State private var palettes: [String: Palette] = [:]
    @State private var width: CGFloat = 393
    @Namespace private var zoom
    private let journal = Journal.shared
    private let library = PromptLibrary.bundled

    private var todayKey: String { Days.key(today) }
    private var options: [Prompt] { library.options(for: today) }
    private var current: Prompt? { options.first { $0.id == page } ?? options.first }
    /// Side room around a plate; wide screens keep the plate a readable width.
    private var margin: CGFloat { max(28, (width - 520) / 2) }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                pager
                PageMarks(count: options.count, index: options.firstIndex { $0.id == current?.id } ?? 0)
                    .padding(.top, 14)
                Button { path.append(.journal) } label: { WeekBar(today: today, journal: journal, library: library) }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("today.week")
                    .padding(.horizontal, margin - 8)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .background {
                RoomBackdrop(palette: current.flatMap { palettes[$0.art] } ?? .neutral, paused: !path.isEmpty || showSettings)
                    .ignoresSafeArea()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .prompt(prompt, day, source):
                    PromptView(prompt: prompt, day: day)
                        .navigationTransition(.zoom(sourceID: source, in: zoom))
                case .journal: JournalView(today: today, path: $path)
                case let .day(day): DayView(day: day, today: today, zoom: zoom, path: $path, showPaywall: $showPaywall)
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task(id: todayKey) { await light() }
        .onOpenURL(perform: open)
        .sensoryFeedback(.selection, trigger: page)
        .onChange(of: scenePhase) { _, phase in if phase == .active { today = .now } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in today = .now }
        .onChange(of: path) { _, new in if new.isEmpty { askForReviewIfDue() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(today.formatted(.dateTime.weekday(.wide)))
                    .plaque(.caption)
                    .foregroundStyle(Theme.secondary)
                Text(today.formatted(.dateTime.month(.wide).day()))
                    .font(Theme.serif(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .glass(in: Circle(), interactive: true)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("today.settings")
        }
        .padding(.horizontal, margin)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(options) { prompt in
                    NavigationLink(value: Route.prompt(prompt, day: todayKey, source: prompt.id)) {
                        Plate(prompt: prompt, entry: journal.entry(day: todayKey, promptID: prompt.id))
                    }
                    .buttonStyle(PressStyle())
                    .matchedTransitionSource(id: prompt.id, in: zoom)
                    .containerRelativeFrame(.horizontal)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.93)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                    .id(prompt.id)
                    .accessibilityIdentifier("today.prompt")
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    /// Samples each painting's colors so the room can take them on.
    private func light() async {
        for prompt in options where palettes[prompt.art] == nil {
            if let palette = await Art.palette(prompt.art) {
                palettes[prompt.art] = palette
            }
        }
    }

    /// A widget tap lands on its prompt: `inkling://prompt/<id>`.
    private func open(_ url: URL) {
        guard url.scheme == "inkling", url.host == "prompt",
              let prompt = options.first(where: { $0.id == url.lastPathComponent }) else { return }
        showSettings = false
        showPaywall = false
        page = prompt.id
        path = [.prompt(prompt, day: todayKey, source: prompt.id)]
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

/// One painting on the wall: the whole work, its plaque, its prompt, and the way in.
struct Plate: View {
    let prompt: Prompt
    let entry: JournalEntry?

    var body: some View {
        VStack(spacing: 0) {
            ArtView(name: prompt.art, whole: true, alignment: .bottom)
                .shadow(color: .black.opacity(0.32), radius: 22, y: 14)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 120)
                .padding(.bottom, 18)
            Text(prompt.maker)
                .plaque()
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .padding(.bottom, 10)
            Text(prompt.text)
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            action
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var action: some View {
        if let entry, entry.counts {
            Label(entry.words > 0 ? String(localized: "\(entry.words) words") : String(localized: "Written"), systemImage: "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .frame(minHeight: 46)
                .glass()
        } else {
            Label("Write", systemImage: "pencil.line")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 26)
                .frame(minHeight: 46)
                .background(Theme.ink, in: Capsule())
        }
    }
}

/// Which of the day's paintings is on the wall.
struct PageMarks: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { mark in
                Capsule()
                    .fill(Theme.ink.opacity(mark == index ? 0.9 : 0.25))
                    .frame(width: mark == index ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.35), value: index)
        .accessibilityHidden(true)
    }
}

/// The streak beside this week, each written day wearing the painting it was written to.
struct WeekBar: View {
    let today: Date
    let journal: Journal
    let library: PromptLibrary

    private var days: [Date] {
        let start = Days.calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).map { Days.adding($0, to: start) }
    }

    var body: some View {
        let streak = journal.currentStreak(today: today)
        let art = journal.artByDay(library: library)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: -2) {
                Text(streak, format: .number)
                    .font(Theme.numeral(32))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(.spring(duration: 0.5), value: streak)
                Text("day streak")
                    .plaque()
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 4)
            HStack(spacing: 7) {
                ForEach(days, id: \.self) { day in
                    DayDot(day: day, today: today, art: art[Days.key(day)], written: journal.isWritten(day))
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 72)
        .glass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak"))
        .accessibilityHint("Opens the calendar")
        .accessibilityAddTraits(.isButton)
    }
}

/// One day of the week: its painting once written, a ring on today, a point otherwise.
struct DayDot: View {
    let day: Date
    let today: Date
    let art: String?
    let written: Bool

    private var isToday: Bool { Days.key(day) == Days.key(today) }
    private var isFuture: Bool { Days.calendar.startOfDay(for: day) > Days.calendar.startOfDay(for: today) }

    var body: some View {
        ZStack {
            if written {
                if let art {
                    ArtView(name: art, size: .tile).clipShape(Circle())
                } else {
                    Circle().fill(Theme.ink)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.paper)
                }
                Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5)
            } else if isToday {
                Circle().strokeBorder(Theme.ink, lineWidth: 1.5)
            } else {
                Circle().fill(Theme.ink.opacity(isFuture ? 0.12 : 0.28)).frame(width: 5, height: 5)
            }
        }
        .frame(width: 24, height: 24)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(duration: 0.5, bounce: 0.35), value: written)
    }
}
