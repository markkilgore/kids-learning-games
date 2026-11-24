import XCTest

@MainActor
final class WeeklyLessonUITests: XCTestCase {
    func testWeeklyPracticeAndArchive() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        func tap(_ id: String) {
            let button = app.buttons[id].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 8), id)
            button.tap()
        }
        func openRecap(_ start: String) {
            tap("weekly-home")
            let row = app.buttons["week-" + start]
            if row.exists {
                if !row.isHittable { app.swipeUp() }
                row.tap()
            }
        }
        openRecap("2026-11-09")
        let cat = app.buttons["2026-11-09-treats"].exists
        let counting = cat ? "2026-11-09-treats" : "2026-11-09-race"
        tap(counting)
        tap("Listen again")
        let rounds = cat ? [(2,"3"), (2,"4"), (4,"3")] : [(3,"3"), (6,"6"), (10,"10")]
        for (index, round) in rounds.enumerated() {
            for _ in 0..<round.0 { tap(cat ? "Give one treat" : "Swim one space") }
            if index == 0 {
                tap("2")
                XCTAssertTrue(app.staticTexts[cat ? "Count the treats still on the screen." : "Look at the number under your shark."].exists)
            }
            tap(round.1)
        }
        tap("Back to the week")
        tap(cat ? "2026-11-09-ice" : "2026-11-09-letters")
        for answer in (cat ? ["It becomes ice","🧊","Liquid water"] : ["h","r","h","r"]) { tap(answer) }
        tap("Back to the week")
        app.terminate()
        app.launch()
        openRecap("2026-11-09")
        XCTAssertEqual(app.buttons[counting].value as? String, "Completed")
        app.terminate()
        app.launch()
        openRecap("2026-11-02")
        tap(cat ? "2026-11-02-turkey-cycle" : "2026-11-02-fish")
        tap("Listen again")
    }
}
