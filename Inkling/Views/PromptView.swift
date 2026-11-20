import SwiftUI

/// One prompt, full size, with room to write under it.
struct PromptView: View {
    let prompt: Prompt
    /// The day the writing counts for.
    let day: String
    @State private var entry: JournalEntry
    @State private var countedOnOpen: Bool
    @FocusState private var focused: Bool
    private let journal = Journal.shared

    init(prompt: Prompt, day: String) {
        self.prompt = prompt
        self.day = day
        let existing = Journal.shared.entry(day: day, promptID: prompt.id)
        _entry = State(initialValue: existing ?? JournalEntry(day: day, promptID: prompt.id))
        _countedOnOpen = State(initialValue: existing?.counts ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ArtView(name: prompt.art)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(prompt.credit)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(prompt.text)
                    .font(Theme.serif(.title2))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)
                Rectangle().fill(Theme.rule).frame(height: 1).padding(.vertical, 22)
                TextField("Start writing", text: $entry.text, axis: .vertical)
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(7)
                    .focused($focused)
                    .frame(minHeight: 240, alignment: .topLeading)
                    .accessibilityIdentifier("prompt.editor")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if entry.words > 0 {
                    Text(entry.words == 1 ? String(localized: "1 word") : String(localized: "\(entry.words) words"))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .accessibilityIdentifier("prompt.words")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { markButton }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }.fontWeight(.semibold)
            }
        }
        .onChange(of: entry.text) { _, text in
            // Typing is the check; a written-elsewhere mark gives way to the words.
            if !text.isEmpty { entry.elsewhere = false }
        }
        .task(id: entry.text) {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
        .onDisappear(perform: finish)
    }

    /// Marks the day written without typing here, for writing done on paper.
    @ViewBuilder
    private var markButton: some View {
        if entry.counts {
            Button {
                if entry.text.isEmpty { entry.elsewhere = false; save() }
            } label: {
                Image(systemName: "checkmark.circle.fill").font(.title3)
            }
            .accessibilityLabel("Written")
            .accessibilityIdentifier("prompt.mark")
        } else {
            Button {
                entry.elsewhere = true
                save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Text("Wrote It").fontWeight(.semibold)
            }
            .accessibilityIdentifier("prompt.mark")
        }
    }

    private func save() { journal.save(entry) }

    private func finish() {
        save()
        if entry.counts && !countedOnOpen { ReviewPrompt().recordPositiveMoment() }
    }
}
