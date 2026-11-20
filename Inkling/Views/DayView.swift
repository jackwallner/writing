import SwiftUI

/// One day from the calendar: what was written, then that day's three prompts.
struct DayView: View {
    let day: String
    let today: Date
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
            VStack(alignment: .leading, spacing: 20) {
                ForEach(entries) { entry in
                    if let prompt = library.prompt(id: entry.promptID) {
                        Button { path.append(.prompt(prompt, day: day)) } label: { written(entry, prompt: prompt) }
                            .buttonStyle(.plain)
                    }
                }
                Text(isToday ? "Today's Prompts" : "Prompts")
                    .font(Theme.serif(.title3, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, entries.isEmpty ? 0 : 12)
                    .accessibilityAddTraits(.isHeader)
                ForEach(library.options(for: date)) { prompt in
                    Button { open(prompt) } label: {
                        PromptCard(prompt: prompt, entry: journal.entry(day: Days.key(today), promptID: prompt.id), height: 150)
                            .overlay(alignment: .topTrailing) {
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(9)
                                        .background(.black.opacity(0.45), in: Circle())
                                        .padding(12)
                                        .accessibilityLabel("Pro")
                                }
                            }
                    }
                    .buttonStyle(.plain)
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
    }

    /// Writing on any day's prompt counts for today, so the calendar only ever checks days that had writing.
    private func open(_ prompt: Prompt) {
        if locked { showPaywall = true; return }
        path.append(.prompt(prompt, day: Days.key(today)))
    }

    private func written(_ entry: JournalEntry, prompt: Prompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ArtView(name: prompt.art)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(prompt.text)
                    .font(Theme.serif(.headline))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if entry.text.isEmpty {
                Label("Written elsewhere", systemImage: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Text(entry.text)
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
