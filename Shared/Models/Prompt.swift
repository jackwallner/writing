import Foundation

/// One writing prompt and the artwork it was written for.
struct Prompt: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    /// File name, without extension, of the artwork in the bundle's Art folder.
    let art: String
    let title: String
    let artist: String
    let date: String?

    /// "Artist, Date" for the plaque, leaving out a date nobody knows.
    var maker: String {
        [artist, date].compactMap { $0 }.filter { !$0.isEmpty && $0 != "n.d." }.joined(separator: ", ")
    }

    /// "Title, Artist, Date" for the credit under the image.
    var credit: String {
        [title, artist, date].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Every prompt the app ships with. Each day gets the next three, in order, so
/// the library runs for `days` days before it starts again.
struct PromptLibrary: Sendable {
    static let perDay = 3

    let prompts: [Prompt]
    private let byID: [String: Prompt]

    init(prompts: [Prompt]) {
        self.prompts = prompts
        byID = Dictionary(prompts.map { ($0.id, $0) }) { first, _ in first }
    }

    static let bundled: PromptLibrary = {
        guard let url = Bundle.app.url(forResource: "prompts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let prompts = try? JSONDecoder().decode([Prompt].self, from: data) else {
            return PromptLibrary(prompts: [])
        }
        return PromptLibrary(prompts: prompts)
    }()

    /// How many distinct days the library covers.
    var days: Int { prompts.count / Self.perDay }

    func prompt(id: String) -> Prompt? { byID[id] }

    /// The three prompts offered on `day`.
    func options(for day: Date, calendar: Calendar = Days.calendar) -> [Prompt] {
        guard days > 0 else { return [] }
        let index = Self.index(of: day, calendar: calendar, days: days)
        let start = index * Self.perDay
        return Array(prompts[start..<start + Self.perDay])
    }

    /// Days since the library's first day, wrapped to its length.
    static func index(of day: Date, calendar: Calendar, days: Int) -> Int {
        let start = calendar.startOfDay(for: Days.epoch)
        let elapsed = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: day)).day ?? 0
        let wrapped = elapsed % days
        return wrapped < 0 ? wrapped + days : wrapped
    }
}
