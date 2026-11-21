import SwiftUI

/// A timed stretch of writing.
struct Sprint: Equatable {
    let start: Date
    let minutes: Int
    var end: Date { start.addingTimeInterval(Double(minutes) * 60) }
}

/// The page: the painting across the top, its prompt, and room to write under it.
struct PromptView: View {
    let prompt: Prompt
    /// The day the writing counts for.
    let day: String
    @State private var entry: JournalEntry
    @State private var countedOnOpen: Bool
    @State private var aspect: CGFloat
    @State private var size = CGSize(width: 393, height: 852)
    @State private var showArt = false
    @State private var sprint: Sprint?
    @State private var sprintsDone = 0
    @State private var question: String?
    @State private var asking = false
    @FocusState private var focused: Bool
    @Namespace private var viewer
    private let journal = Journal.shared

    init(prompt: Prompt, day: String) {
        self.prompt = prompt
        self.day = day
        let existing = Journal.shared.entry(day: day, promptID: prompt.id)
        _entry = State(initialValue: existing ?? JournalEntry(day: day, promptID: prompt.id))
        _countedOnOpen = State(initialValue: existing?.counts ?? false)
        _aspect = State(initialValue: Art.cached(prompt.art).map { $0.size.width / max($0.size.height, 1) } ?? 1)
    }

    /// A wide painting shows whole; a tall one is cropped to no more than a square or half the screen.
    private var headerHeight: CGFloat {
        max(220, min(size.width / max(aspect, 1), size.height * 0.5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    Text(prompt.title)
                        .font(Theme.serif(.subheadline))
                        .italic()
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(prompt.maker)
                        .plaque()
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 5)
                    Text(prompt.text)
                        .font(Theme.serif(.title2))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                        .accessibilityAddTraits(.isHeader)
                    Rectangle().fill(Theme.rule).frame(width: 44, height: 1).padding(.vertical, 24)
                    TextField("Start writing", text: $entry.text, axis: .vertical)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(8)
                        .focused($focused)
                        .frame(minHeight: 220, alignment: .topLeading)
                        .accessibilityIdentifier("prompt.editor")
                    if let question {
                        Text(question)
                            .font(Theme.serif(.body))
                            .italic()
                            .foregroundStyle(Theme.accent)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .accessibilityIdentifier("prompt.question")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.paper)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { markButton } }
        .fullScreenCover(isPresented: $showArt) {
            ArtViewer(prompt: prompt).navigationTransition(.zoom(sourceID: "art", in: viewer))
        }
        .sensoryFeedback(.success, trigger: sprintsDone)
        .onChange(of: entry.text) { _, text in
            // Typing is the check; a written-elsewhere mark gives way to the words.
            if !text.isEmpty { entry.elsewhere = false }
        }
        .task(id: entry.text) {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
        .task(id: sprint) {
            guard let sprint else { return }
            try? await Task.sleep(until: .now + .seconds(max(0, sprint.end.timeIntervalSinceNow)), clock: .continuous)
            guard !Task.isCancelled else { return }
            self.sprint = nil
            sprintsDone += 1
        }
        .task {
            if let image = await Art.image(prompt.art) { aspect = image.size.width / max(image.size.height, 1) }
        }
        .onDisappear(perform: finish)
    }

    private var header: some View {
        ArtView(name: prompt.art)
            .frame(height: headerHeight)
            // Pulling down stretches the painting instead of showing paper above it.
            .visualEffect { content, proxy in
                let pull = max(0, proxy.frame(in: .scrollView).minY)
                return content.scaleEffect(1 + pull / max(proxy.size.height, 1), anchor: .bottom)
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.38), in: Circle())
                    .padding(14)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onTapGesture { showArt = true }
            .matchedTransitionSource(id: "art", in: viewer)
            .accessibilityElement()
            .accessibilityLabel(prompt.credit)
            .accessibilityAddTraits([.isImage, .isButton])
            .accessibilityIdentifier("prompt.art")
    }

    /// Floats over the page and rides the keyboard: the count, the timer, a question, sharing.
    private var bar: some View {
        HStack(spacing: 0) {
            status
                .padding(.leading, 20)
            Spacer(minLength: 8)
            if Muse.isAvailable, entry.words >= 12 { deeper }
            timer
            if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ShareLink(item: ShareCard(prompt: prompt, text: entry.text), preview: SharePreview(prompt.title)) {
                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share")
            }
            if focused {
                Button("Done") { focused = false }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
            }
        }
        .font(.body)
        .tint(Theme.ink)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .glass(in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.snappy(duration: 0.25), value: focused)
    }

    @ViewBuilder
    private var status: some View {
        HStack(spacing: 10) {
            if let sprint {
                Text(timerInterval: sprint.start...sprint.end, countsDown: true)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("prompt.timer")
            }
            if entry.words > 0 {
                Text(entry.words == 1 ? String(localized: "1 word") : String(localized: "\(entry.words) words"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                    .contentTransition(.numericText(value: Double(entry.words)))
                    .animation(.snappy, value: entry.words)
                    .accessibilityIdentifier("prompt.words")
            }
        }
        .lineLimit(1)
    }

    /// Starts a timed stretch, or stops the one running.
    @ViewBuilder
    private var timer: some View {
        if sprint != nil {
            Button { sprint = nil } label: {
                Image(systemName: "stop.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Stop Timer")
        } else {
            Menu {
                ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                    Button(String(localized: "\(minutes) minutes")) {
                        sprint = Sprint(start: .now, minutes: minutes)
                        focused = true
                    }
                }
            } label: {
                Image(systemName: "timer").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Timer")
            .accessibilityIdentifier("prompt.timerMenu")
        }
    }

    /// Asks the phone's own model for one question about what is on the page.
    private var deeper: some View {
        Button {
            asking = true
            Task {
                let answer = await Muse.question(prompt: prompt.text, writing: entry.text)
                asking = false
                withAnimation(.easeOut(duration: 0.35)) { question = answer }
            }
        } label: {
            Group {
                if asking { ProgressView() } else { Image(systemName: "sparkle") }
            }
            .frame(width: 44, height: 44)
        }
        .disabled(asking)
        .accessibilityLabel("Go Deeper")
        .accessibilityIdentifier("prompt.deeper")
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
