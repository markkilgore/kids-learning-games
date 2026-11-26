import XCTest

/// Walks every Cat Math screen and saves a screenshot of each, so layout can be reviewed at any iPad size.
/// Set `TEST_RUNNER_TOUR_DIR` to also write the PNGs to a folder on the Mac.
@MainActor
final class CatTourUITests: XCTestCase {
    private let app = XCUIApplication()

    /// Starts where Kate is (25 hearts with every cat): the meadow animals, and a cat's second chapter with its harder math.
    func testMeadowFriendsAndChapterTwo() {
        continueAfterFailure = false
        app.launchArguments += ["-heartsWithEveryCat", "25"]
        app.launch()
        XCTAssertTrue(app.buttons["cat-mittens"].waitForExistence(timeout: 8))
        snap("20-home-25-hearts")
        app.buttons["Meadow"].tap()
        snap("21-home-meadow")
        tap("cat-scout")
        snap("22-scout-story")
        startRound()
        snap("23-scout-puzzle")
        tap("kid-back")

        // Two more puzzles take Mittens from 25 to 27 hearts, which opens chapter two.
        app.buttons["House"].tap()
        tap("cat-mittens")
        let start = app.buttons["start-round"].firstMatch
        if start.waitForExistence(timeout: 3) { startRound() }
        for _ in 1...2 {
            let answer = app.buttons["answer-correct"].firstMatch
            XCTAssertTrue(answer.waitForExistence(timeout: 8))
            answer.tap()
            sleep(7)
        }
        let reward = app.buttons["reward-trick"]
        XCTAssertTrue(reward.waitForExistence(timeout: 8))
        reward.tap()
        snap("24-chapter-two-opens")
        tap("next-puzzle")
        XCTAssertTrue(start.waitForExistence(timeout: 8), "the new page should be read before its puzzles")
        snap("25-chapter-two-story")
        startRound(snapAs: "25b-chapter-two-reading")
        for puzzle in 1...3 {
            let answer = app.buttons["answer-correct"].firstMatch
            XCTAssertTrue(answer.waitForExistence(timeout: 8))
            snap("26-chapter-two-puzzle-\(puzzle)")
            answer.tap()
            sleep(7)
        }
        XCTAssertTrue(app.buttons["reward-treat"].waitForExistence(timeout: 8))
        app.buttons["reward-treat"].tap()
        tap("next-puzzle")
        tap("kid-back")
        tap("cat-journal")
        snap("27-journal")
    }

    /// Chapter-two subtraction is drawn on two ten-frames; with 31 hearts it is Mittens's next puzzle.
    func testMakeTenSubtraction() {
        continueAfterFailure = false
        app.launchArguments += ["-heartsWithEveryCat", "31"]
        app.launch()
        tap("cat-mittens")
        startRound()
        XCTAssertTrue(app.staticTexts["Subtraction"].waitForExistence(timeout: 5))
        snap("30-make-ten")
        // Counters are taken away from the end, whichever one is tapped.
        let frames = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Picture hint")).firstMatch
        XCTAssertTrue(frames.waitForExistence(timeout: 5))
        for tapNumber in 1...9 {
            frames.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)).tap()
            if tapNumber == 2 { snap("31-make-ten-partway") }
            sleep(1)
        }
        snap("32-make-ten-done")
        tap("answer-correct")
    }

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
        snap("04-story-page")
        startRound(snapAs: "04b-reading-question")
        snap("05-puzzle")

        // Two rounds of three puzzles cover all six skills, each with its own picture.
        for puzzle in 1...6 {
            let other = app.buttons["answer-other"].firstMatch
            XCTAssertTrue(other.waitForExistence(timeout: 8))
            if puzzle > 1 { snap("06-puzzle-skill-\(puzzle)") }
            if puzzle == 1 {
                other.tap()
                snap("07-puzzle-wrong")
            }
            // The right answer of the next puzzle only becomes tappable once this one has moved on.
            let answer = app.buttons["answer-correct"].firstMatch
            XCTAssertTrue(answer.waitForExistence(timeout: 8))
            answer.tap()
            guard puzzle % 3 == 0 else {
                if puzzle == 1 { snap("08-puzzle-praise") }
                sleep(4)
                continue
            }
            let reward = app.buttons[["reward-treat", "reward-meal", "reward-trick"][puzzle / 3 % 3]]
            XCTAssertTrue(reward.waitForExistence(timeout: 8))
            if puzzle == 3 { snap("09-round-celebration") }
            reward.tap()
            if puzzle == 3 { snap("10-round-reward") }
            tap("next-puzzle")
            // A round that opens a new story page shows it next; once the story is finished, puzzles continue.
            let start = app.buttons["start-round"].firstMatch
            if start.waitForExistence(timeout: 3) {
                if puzzle == 3 { snap("11-next-story-page") }
                startRound()
            }
        }
        tap("kid-back")
        snap("12-home-after-puzzles")

        tap("cat-journal")
        snap("13-journal")
        tap("kid-back")

        tap("weekly-home")
        snap("14-weekly-shelf")
        app.buttons.matching(NSPredicate(format: "value == %@ OR value == %@", "Ready", "Completed")).firstMatch.tap()
        snap("15-weekly-round")
        tap("kid-back")
        tap("kid-back")

        app.images["parent-gate"].firstMatch.press(forDuration: 2.6)
        XCTAssertTrue(app.staticTexts["Parent Settings"].waitForExistence(timeout: 5))
        snap("16-settings")

        let progress = app.descendants(matching: .any)["parent-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        // The simulator may report portrait while the app is landscape-only; match them so the swipe scrolls.
        XCUIDevice.shared.orientation = .landscapeLeft
        app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        XCTAssertTrue(app.staticTexts["Right first try"].exists)
        snap("17-settings-progress")
    }

    /// Leaves a story page and answers its reading question, which comes before the puzzles.
    private func startRound(snapAs name: String? = nil) {
        tap("start-round")
        let sentence = app.buttons["reading-correct"].firstMatch
        XCTAssertTrue(sentence.waitForExistence(timeout: 8), "no reading question after the story page")
        if let name {
            snap(name)
            app.buttons["reading-other"].firstMatch.tap()
            snap(name + "-wrong")
        }
        sentence.tap()
        XCTAssertTrue(app.buttons["answer-correct"].firstMatch.waitForExistence(timeout: 12), "puzzles did not follow the reading question")
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
