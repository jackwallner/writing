import XCTest
@testable import Inkling

final class StreakTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func day(_ key: String) -> Date { Days.date(key, calendar: calendar)! }

    func testCurrentStreakCountsBackFromToday() {
        let written: Set = ["2026-11-18", "2026-11-19", "2026-11-20"]
        XCTAssertEqual(Streak.current(written: written, today: day("2026-11-20"), calendar: calendar), 3)
    }

    func testOpenTodayKeepsYesterdaysStreak() {
        let written: Set = ["2026-11-18", "2026-11-19"]
        XCTAssertEqual(Streak.current(written: written, today: day("2026-11-20"), calendar: calendar), 2)
    }

    func testMissedYesterdayEndsStreak() {
        let written: Set = ["2026-11-17", "2026-11-18"]
        XCTAssertEqual(Streak.current(written: written, today: day("2026-11-20"), calendar: calendar), 0)
    }

    func testStreakCrossesMonthAndDST() {
        let written: Set = ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"]
        XCTAssertEqual(Streak.current(written: written, today: day("2026-11-02"), calendar: calendar), 4)
    }

    func testLongestStreak() {
        let written: Set = ["2026-01-01", "2026-01-02", "2026-01-05", "2026-01-06", "2026-01-07", "2026-01-09"]
        XCTAssertEqual(Streak.longest(written: written, calendar: calendar), 3)
        XCTAssertEqual(Streak.longest(written: [], calendar: calendar), 0)
    }

    func testDayKeyRoundTrips() {
        XCTAssertEqual(Days.key(day("2026-03-08"), calendar: calendar), "2026-03-08")
        XCTAssertNil(Days.date("not a day", calendar: calendar))
    }
}

@MainActor
final class JournalTests: XCTestCase {
    func testTypingChecksTheDay() {
        let journal = Journal(file: nil)
        var entry = JournalEntry(day: "2026-11-20", promptID: "p1")
        journal.save(entry)
        XCTAssertTrue(journal.writtenDays.isEmpty, "An empty entry is not kept")
        entry.text = "The lamp was still warm."
        journal.save(entry)
        XCTAssertEqual(journal.writtenDays, ["2026-11-20"])
        XCTAssertEqual(journal.entries.count, 1)
    }

    func testWrittenElsewhereChecksTheDay() {
        let journal = Journal(file: nil)
        journal.save(JournalEntry(day: "2026-11-20", promptID: "p1", elsewhere: true))
        XCTAssertEqual(journal.writtenDays, ["2026-11-20"])
    }

    func testClearingTextUnchecksTheDay() {
        let journal = Journal(file: nil)
        var entry = JournalEntry(day: "2026-11-20", promptID: "p1", text: "Hello")
        journal.save(entry)
        entry.text = "   \n"
        journal.save(entry)
        XCTAssertTrue(journal.writtenDays.isEmpty)
    }

    func testPersistsAcrossLaunches() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        Journal(file: file).save(JournalEntry(day: "2026-11-20", promptID: "p1", text: "Kept"))
        XCTAssertEqual(Journal(file: file).entries.first?.text, "Kept")
    }

    func testWordCount() {
        XCTAssertEqual(JournalEntry.wordCount("The rain, at last, came."), 5)
        XCTAssertEqual(JournalEntry.wordCount("  "), 0)
    }
}

final class LibraryTests: XCTestCase {
    private func library(_ count: Int) -> PromptLibrary {
        PromptLibrary(prompts: (0..<count).map { Prompt(id: "p\($0)", text: "Prompt \($0)", art: "a\($0)", title: "T", artist: "A", date: nil) })
    }

    func testThreeDistinctPromptsADayThatChangeDaily() {
        let library = library(30)
        let calendar = Calendar(identifier: .gregorian)
        let monday = Days.date("2026-11-16", calendar: calendar)!
        let today = library.options(for: monday, calendar: calendar)
        let tomorrow = library.options(for: Days.adding(1, to: monday, calendar: calendar), calendar: calendar)
        XCTAssertEqual(today.count, 3)
        XCTAssertEqual(Set(today.map(\.id)).count, 3)
        XCTAssertTrue(Set(today.map(\.id)).isDisjoint(with: tomorrow.map(\.id)))
    }

    func testLibraryWrapsAndHandlesDaysBeforeEpoch() {
        let library = library(9)
        XCTAssertEqual(PromptLibrary.index(of: Days.epoch, calendar: .current, days: library.days), 0)
        let before = Days.adding(-1, to: Days.epoch)
        XCTAssertEqual(PromptLibrary.index(of: before, calendar: .current, days: library.days), 2)
        let wrapped = Days.adding(3, to: Days.epoch)
        XCTAssertEqual(PromptLibrary.index(of: wrapped, calendar: .current, days: library.days), 0)
    }

    func testBundledLibraryCoversAYearWithArt() throws {
        let library = PromptLibrary.bundled
        XCTAssertGreaterThanOrEqual(library.days, 365, "At least a year of prompts")
        XCTAssertEqual(Set(library.prompts.map(\.id)).count, library.prompts.count, "Prompt ids are unique")
        for prompt in library.prompts {
            XCTAssertFalse(prompt.text.isEmpty)
            XCTAssertFalse(prompt.text.contains("\u{2014}"), "No em dashes: \(prompt.id)")
            let url = Bundle.main.url(forResource: prompt.art, withExtension: "heic", subdirectory: "Art")
            XCTAssertNotNil(url, "Missing art for \(prompt.id)")
        }
    }

    func testEveryDayOfTheNextYearHasThreeDifferentPaintings() {
        let library = PromptLibrary.bundled
        for offset in 0..<366 {
            let options = library.options(for: Days.adding(offset, to: .now))
            XCTAssertEqual(Set(options.map(\.art)).count, 3)
        }
    }
}

final class ReviewPromptTests: XCTestCase {
    private func prompt() -> ReviewPrompt {
        let name = UUID().uuidString
        return ReviewPrompt(defaults: UserDefaults(suiteName: name)!)
    }

    func testAsksFromSecondLaunchAfterAPositiveMoment() {
        let review = prompt()
        review.recordLaunch()
        review.recordPositiveMoment()
        XCTAssertFalse(review.shouldAsk())
        review.recordLaunch()
        XCTAssertTrue(review.shouldAsk())
    }

    func testCooldownAndStoreVisit() {
        let review = prompt()
        review.recordLaunch(); review.recordLaunch()
        review.recordPositiveMoment()
        review.markAsked(now: .now)
        review.recordPositiveMoment()
        XCTAssertFalse(review.shouldAsk(now: .now.addingTimeInterval(86_400 * 10)))
        XCTAssertTrue(review.shouldAsk(now: .now.addingTimeInterval(86_400 * 31)))
        review.markOpenedStore()
        XCTAssertFalse(review.shouldAsk(now: .now.addingTimeInterval(86_400 * 31)))
    }
}

final class PaletteTests: XCTestCase {
    func testRoomIsDeepAtNightAndPaleByDay() {
        let vivid = Palette(cells: Array(repeating: SIMD3(0.9, 0.2, 0.1), count: 9))
        for color in vivid.room(dark: true) { XCTAssertLessThan(color.max(), 0.36, "white text must read on the night room") }
        for color in vivid.room(dark: false) { XCTAssertGreaterThan(color.min(), 0.55, "ink must read on the day room") }
    }

    func testColorRoundTrips() {
        let color = SIMD3(0.31, 0.62, 0.48)
        let (hue, saturation, brightness) = Palette.hsb(color)
        let back = Palette.rgb(hue, saturation, brightness)
        XCTAssertEqual(back.x, color.x, accuracy: 0.001)
        XCTAssertEqual(back.y, color.y, accuracy: 0.001)
        XCTAssertEqual(back.z, color.z, accuracy: 0.001)
    }

    func testGreyWorkHasNoAccent() {
        XCTAssertNil(Palette(cells: Array(repeating: SIMD3(0.5, 0.5, 0.5), count: 9)).accent(dark: true))
    }

    func testMuseTidiesAnAnswer() {
        XCTAssertEqual(Muse.tidy("\"What did the room smell like?\"\nMore."), "What did the room smell like?")
        XCTAssertNil(Muse.tidy("  \n"))
    }
}

@MainActor
final class BookTests: XCTestCase {
    func testBookHasACoverAndAPageForEachPiece() throws {
        let library = PromptLibrary.bundled
        let journal = Journal(file: nil)
        let long = Array(repeating: "The lamp was still warm when I came back to it, and the room had kept my place.", count: 90).joined(separator: " ")
        journal.save(JournalEntry(day: "2026-11-18", promptID: library.prompts[0].id, text: "One line."))
        journal.save(JournalEntry(day: "2026-11-19", promptID: library.prompts[1].id, text: long))
        journal.save(JournalEntry(day: "2026-11-20", promptID: library.prompts[2].id, elsewhere: true))
        let url = try Book.write(journal: journal, library: library)
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertGreaterThanOrEqual(document.numberOfPages, 5, "cover, three pieces, and the long one runs on")
    }

    func testShareCardRenders() throws {
        let prompt = PromptLibrary.bundled.prompts[0]
        let data = try ShareCard(prompt: prompt, text: "The boat was older than the dock.").png()
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(image.size.width, 1080)
        XCTAssertEqual(image.size.height, 1350)
    }
}
