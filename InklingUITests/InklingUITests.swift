import XCTest

final class InklingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"] + extra
        app.launch()
        return app
    }

    private func openFirstPrompt(_ app: XCUIApplication) {
        let card = app.buttons["today.prompt"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
    }

    /// The week strip reads as one element: its days, then the streak.
    private func waitForStreak(_ app: XCUIApplication, _ text: String) -> Bool {
        let week = app.buttons["today.week"]
        guard week.waitForExistence(timeout: 5) else { return false }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if week.label.contains(text) { return true }
            usleep(200_000)
        }
        return false
    }

    func testTodayOffersThreePrompts() {
        let app = launch()
        XCTAssertTrue(app.buttons["today.prompt"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "today.prompt").count, 3)
    }

    func testWritingChecksToday() {
        let app = launch()
        XCTAssertTrue(waitForStreak(app, "0 day streak"))
        openFirstPrompt(app)
        let editor = app.textViews["prompt.editor"].exists ? app.textViews["prompt.editor"] : app.textFields["prompt.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("The boat was older than the dock.")
        XCTAssertTrue(app.staticTexts["prompt.words"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForStreak(app, "1 day streak"))
    }

    func testWroteItElsewhereChecksToday() {
        let app = launch()
        openFirstPrompt(app)
        let mark = app.buttons["prompt.mark"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForStreak(app, "1 day streak"))
    }

    func testCalendarShowsStreakNumbers() {
        let app = launch(["-SeedDemo"])
        let week = app.buttons["today.week"]
        XCTAssertTrue(week.waitForExistence(timeout: 5))
        week.tap()
        let current = app.descendants(matching: .any)["journal.current"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertTrue(current.label.hasPrefix("8"), current.label)
    }

    func testEarlierDayPromptsOpenThePaywall() {
        let app = launch(["-SeedDemo", "-MockProducts"])
        app.buttons["today.week"].tap()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let label = yesterday.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let day = app.buttons[label]
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        let prompt = app.buttons["day.prompt"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.tap()
        XCTAssertTrue(app.buttons["paywall.buy"].waitForExistence(timeout: 5))
    }

    func testPaintingOpensFullScreen() {
        let app = launch()
        openFirstPrompt(app)
        let art = app.descendants(matching: .any)["prompt.art"].firstMatch
        XCTAssertTrue(art.waitForExistence(timeout: 5))
        art.tap()
        let close = app.buttons["viewer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["prompt.mark"].waitForExistence(timeout: 5))
    }

    func testTimerCountsDown() {
        let app = launch()
        openFirstPrompt(app)
        let menu = app.buttons["prompt.timerMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let five = app.buttons["5 minutes"]
        XCTAssertTrue(five.waitForExistence(timeout: 5))
        five.tap()
        XCTAssertTrue(app.staticTexts["prompt.timer"].waitForExistence(timeout: 5))
    }

    func testSettingsOpensPaywall() {
        let app = launch(["-MockProducts"])
        app.buttons["today.settings"].tap()
        let pro = app.buttons["settings.pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 5))
        pro.tap()
        XCTAssertTrue(app.buttons["paywall.yearly"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.buy"].exists)
    }
}

/// Screens for review and the App Store, saved as test attachments.
final class ScreenCaptureUITests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-SeedDemo", "-MockProducts"]
        app.launch()
        XCTAssertTrue(app.buttons["today.prompt"].firstMatch.waitForExistence(timeout: 5))
        sleep(2)
        shot(app, "1-today")
        app.swipeLeft()
        sleep(2)
        shot(app, "2-today-second")
        app.swipeRight()
        sleep(1)

        app.buttons["today.prompt"].firstMatch.tap()
        let editor = app.textViews["prompt.editor"].exists ? app.textViews["prompt.editor"] : app.textFields["prompt.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        sleep(1)
        shot(app, "3-prompt")
        app.descendants(matching: .any)["prompt.art"].firstMatch.tap()
        XCTAssertTrue(app.buttons["viewer.close"].waitForExistence(timeout: 5))
        sleep(1)
        shot(app, "4-viewer")
        app.buttons["viewer.close"].tap()
        sleep(1)
        editor.tap()
        editor.typeText("The light came in sideways that morning, and I stood at the sink longer than I meant to.")
        sleep(1)
        shot(app, "5-writing")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        shot(app, "6-today-written")

        app.buttons["today.week"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["journal.current"].waitForExistence(timeout: 5))
        sleep(2)
        shot(app, "7-calendar")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        app.buttons[yesterday.formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        XCTAssertTrue(app.buttons["day.prompt"].firstMatch.waitForExistence(timeout: 5))
        sleep(2)
        shot(app, "8-day")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)

        app.buttons["today.settings"].tap()
        XCTAssertTrue(app.buttons["settings.pro"].waitForExistence(timeout: 5))
        shot(app, "9-settings")
        app.buttons["settings.pro"].tap()
        XCTAssertTrue(app.buttons["paywall.buy"].waitForExistence(timeout: 5))
        sleep(2)
        shot(app, "10-paywall")
    }
}
