import SwiftUI

/// One day from the calendar: what was written, then that day's three paintings.
struct DayView: View {
    let day: String
    let today: Date
    let zoom: Namespace.ID
    @Binding var path: [Route]
    @Binding var showPaywall: Bool
    private let journal = Journal.shared
    private let library = PromptLibrary.bundled
    private let subscription = SubscriptionService.shared

    private var date: Date { Days.date(day) ?? today }
    private var isToday: Bool { day == Days.key(today) }
    /// Earlier days' prompts are Pro; today's are everyone's.
    private var locked: Bool { !isToday && !subscription.isPro }

    var body: some View {
        let entries = journal.entries(on: day)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(entries) { entry in
                    if let prompt = library.prompt(id: entry.promptID) {
                        let source = "written-\(entry.id)"
                        Button { path.append(.prompt(prompt, day: day, source: source)) } label: { written(entry, prompt: prompt) }
                            .buttonStyle(PressStyle())
                            .matchedTransitionSource(id: source, in: zoom)
                    }
                }
                // A prompt already written to shows once, as its page above.
                let unwritten = library.options(for: date).filter { option in !entries.contains { $0.promptID == option.id } }
                if !unwritten.isEmpty {
                    Text(isToday ? "Today's Prompts" : "Prompts")
                        .plaque(.caption)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, entries.isEmpty ? 4 : 14)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(unwritten) { prompt in
                    let source = "day-\(prompt.id)"
                    Button { open(prompt, source: source) } label: {
                        Poster(prompt: prompt, locked: locked, written: journal.entry(day: Days.key(today), promptID: prompt.id)?.counts ?? false)
                    }
                    .buttonStyle(PressStyle())
                    .matchedTransitionSource(id: source, in: zoom)
                    .accessibilityIdentifier("day.prompt")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle(date.formatted(.dateTime.month(.wide).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(date.formatted(.dateTime.month(.wide).day()))
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// Writing on any day's prompt counts for today, so the calendar only ever checks days that had writing.
    private func open(_ prompt: Prompt, source: String) {
        if locked { showPaywall = true; return }
        path.append(.prompt(prompt, day: Days.key(today), source: source))
    }

    /// A page of writing under a band of its painting.
    private func written(_ entry: JournalEntry, prompt: Prompt) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtView(name: prompt.art)
                .frame(height: 132)
            VStack(alignment: .leading, spacing: 12) {
                Text(prompt.text)
                    .font(Theme.serif(.subheadline))
                    .italic()
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if entry.text.isEmpty {
                    Label("Written elsewhere", systemImage: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text(entry.text)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .lineLimit(14)
                    Text(entry.words == 1 ? String(localized: "1 word") : String(localized: "\(entry.words) words"))
                        .plaque()
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A painting as a poster, its prompt set across the foot.
struct Poster: View {
    let prompt: Prompt
    var locked = false
    var written = false

    var body: some View {
        ArtView(name: prompt.art)
            .frame(height: 250)
            .overlay {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.2), .init(color: .black.opacity(0.78), location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(prompt.maker)
                        .plaque()
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(prompt.text)
                        .font(Theme.serif(.headline, weight: .regular))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                if locked || written {
                    Image(systemName: locked ? "lock.fill" : "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.42), in: Circle())
                        .padding(14)
                        .accessibilityLabel(locked ? Text("Pro") : Text("Written"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
