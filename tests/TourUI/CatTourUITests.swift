import XCTest

/// Walks every Cat Math screen and saves a screenshot of each, so layout can be reviewed at any iPad size.
/// Set `TEST_RUNNER_TOUR_DIR` to also write the PNGs to a folder on the Mac.
@MainActor
final class CatTourUITests: XCTestCase {
    private let app = XCUIApplication()

    func testTourEveryScreen() {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.buttons["cat-mittens"].waitForExistence(timeout: 8))
        snap("01-home-house")

        app.buttons["Garden"].tap()
        snap("02-home-garden")
        let locked = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "locked")).firstMatch
        if locked.exists {
            locked.tap()
            snap("03-locked-hint")
        }
        app.buttons["House"].tap()

        tap("cat-mittens")
        snap("04-puzzle")

        // Six puzzles in a row covers all six skills, each with its own picture.
        for round in 1...6 {
            let other = app.buttons["answer-other"].firstMatch
            XCTAssertTrue(other.waitForExistence(timeout: 8))
            if round > 1 { snap("05-puzzle-skill-\(round)") }
            if round == 1 {
                other.tap()
                snap("06-puzzle-wrong")
            }
            app.buttons["answer-correct"].tap()
            let reward = app.buttons[["reward-treat", "reward-meal", "reward-trick"][round % 3]]
            XCTAssertTrue(reward.waitForExistence(timeout: 8))
            if round == 1 { snap("07-reward-choose") }
            reward.tap()
            if round == 1 { snap("08-reward-story") }
            tap("next-puzzle")
        }
        tap("kid-back")
        snap("09-home-after-puzzles")

        tap("cat-journal")
        snap("10-journal")
        tap("kid-back")

        tap("weekly-home")
        snap("11-weekly-shelf")
        app.buttons.matching(NSPredicate(format: "value == %@ OR value == %@", "Ready", "Completed")).firstMatch.tap()
        snap("12-weekly-round")
        tap("kid-back")
        tap("kid-back")

        app.images["parent-gate"].firstMatch.press(forDuration: 2.6)
        XCTAssertTrue(app.staticTexts["Parent Settings"].waitForExistence(timeout: 5))
        snap("13-settings")
    }

    private func tap(_ identifier: String) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), identifier)
        button.tap()
    }

    private func snap(_ name: String) {
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["TOUR_DIR"] {
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("cat-\(name).png"))
        }
    }
}
