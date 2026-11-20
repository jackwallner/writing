import Foundation
import Observation

/// Everything written, kept in one file on the device.
@MainActor
@Observable
final class Journal {
    static let shared = Journal(file: Journal.defaultFile)

    private(set) var entries: [JournalEntry] = []
    @ObservationIgnored private let file: URL?

    /// `file` nil keeps everything in memory (tests and UI tests).
    init(file: URL?) {
        self.file = file
        load()
    }

    static var defaultFile: URL? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITesting") { return nil }
        #endif
        guard let folder = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return folder.appendingPathComponent("journal.json")
    }

    /// Days with at least one entry that counts.
    var writtenDays: Set<String> { Set(entries.filter(\.counts).map(\.day)) }

    func entries(on day: String) -> [JournalEntry] {
        entries.filter { $0.day == day && $0.counts }.sorted { $0.created < $1.created }
    }

    func entry(day: String, promptID: String) -> JournalEntry? {
        entries.first { $0.day == day && $0.promptID == promptID }
    }

    func isWritten(_ day: Date) -> Bool { writtenDays.contains(Days.key(day)) }

    func currentStreak(today: Date = .now) -> Int { Streak.current(written: writtenDays, today: today) }

    var longestStreak: Int { Streak.longest(written: writtenDays) }

    /// Saves `entry`, replacing the one with its id. An entry with nothing in it is dropped.
    func save(_ entry: JournalEntry) {
        var entry = entry
        entry.updated = .now
        entries.removeAll { $0.id == entry.id }
        if entry.counts { entries.append(entry) }
        persist()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    /// Every entry as plain text, newest first, for sharing.
    func export(library: PromptLibrary) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return entries
            .filter(\.counts)
            .sorted { ($0.day, $0.created) > ($1.day, $1.created) }
            .map { entry in
                let date = Days.date(entry.day).map(formatter.string) ?? entry.day
                let prompt = library.prompt(id: entry.promptID)?.text ?? ""
                let body = entry.text.isEmpty ? String(localized: "Written elsewhere") : entry.text
                return "\(date)\n\(prompt)\n\n\(body)"
            }
            .joined(separator: "\n\n\n")
    }

    private func load() {
        guard let file, let data = try? Data(contentsOf: file) else { return }
        entries = (try? JSONDecoder().decode([JournalEntry].self, from: data)) ?? []
    }

    private func persist() {
        guard let file, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    #if DEBUG
    /// A month of writing for screenshots: most days checked, a few missed, today still open.
    func seedDemo(library: PromptLibrary, today: Date = .now) {
        entries = []
        let skipped: Set<Int> = [9, 10, 17, 24, 25, 26]
        for back in 1...34 where !skipped.contains(back) {
            let day = Days.adding(-back, to: today)
            guard let prompt = library.options(for: day).first else { continue }
            entries.append(JournalEntry(day: Days.key(day), promptID: prompt.id, text: Journal.demoText, created: day, updated: day))
        }
    }

    static let demoText = """
    The light came in sideways that morning, the way it does only in late autumn, and I stood at the sink longer than I meant to. \
    There is a version of me that would have hurried. This one stayed and watched the steam lift off the cup.
    """
    #endif
}
