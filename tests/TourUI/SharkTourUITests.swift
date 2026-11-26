import XCTest

/// Walks every Shark Explorer screen and saves a screenshot of each, so layout can be reviewed at any iPad size.
/// Set `TEST_RUNNER_TOUR_DIR` to also write the PNGs to a folder on the Mac.
@MainActor
final class SharkTourUITests: XCTestCase {
    private let app = XCUIApplication()

    func testTourEveryScreen() {
        continueAfterFailure = false
        app.launch()
        if !app.buttons["shark-whale"].waitForExistence(timeout: 5) { tap("kid-back") }
        snap("01-map")

        app.buttons.matching(NSPredicate(format: "label == %@", "Hidden shark, locked")).firstMatch.tap()
        snap("02-map-locked-hint")

        tap("shark-whale")
        snap("03-encounter")

        tap("discover")
        snap("04-discover")
        tap("kid-back")

        tap("play-mission")
        snap("05-mission-intro")
        let start = app.buttons["Start!"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        tapWhenReady(start)
        snap("06-mission-play")

        tap("kid-back")
        snap("07-leave-confirm")
        app.buttons["Keep playing"].tap()

        let target = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Mission target")).firstMatch
        let questions = app.buttons["start-questions"]
        for _ in 0..<40 where !questions.exists {
            if target.waitForExistence(timeout: 3) { target.tap() }
        }
        XCTAssertTrue(questions.waitForExistence(timeout: 5), "mission never completed")
        snap("08-mission-complete")
        questions.tap()

        for question in 1...3 {
            let other = app.buttons["answer-other"].firstMatch
            XCTAssertTrue(other.waitForExistence(timeout: 8))
            if question == 1 {
                snap("09-question")
                other.tap()
                snap("10-question-wrong")
            }
            app.buttons["answer-correct"].tap()
            if question == 1 { snap("11-question-correct") }
            tap("next-question")
        }
        snap("12-reward")

        tap("open-shark-book")
        snap("13-passport")
        app.buttons["Ocean Words"].tap()
        snap("14-ocean-words")
        tap("kid-back")
        snap("15-map-after-mission")

        tap("weekly-home")
        snap("16-weekly-shelf")
        app.buttons.matching(NSPredicate(format: "value == %@ OR value == %@", "Ready", "Completed")).firstMatch.tap()
        snap("17-weekly-round")
        tap("kid-back")
        tap("kid-back")

        app.images["parent-gate"].firstMatch.press(forDuration: 2.6)
        XCTAssertTrue(app.staticTexts["Parent Settings"].waitForExistence(timeout: 5))
        snap("18-settings")

        let progress = app.descendants(matching: .any)["parent-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        // The simulator may report portrait while the app is landscape-only; match them so the swipe scrolls.
        XCUIDevice.shared.orientation = .landscapeLeft
        app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        XCTAssertTrue(app.staticTexts["Topics explored"].exists)
        snap("19-settings-progress")
    }

    /// Plays every shark's mission to the end, so a mission kind that cannot be finished is caught.
    func testEveryMissionCanBePlayedToTheEnd() {
        continueAfterFailure = true
        app.launchArguments += ["-unlockAllSharks"]
        app.launch()
        if !app.buttons["shark-whale"].waitForExistence(timeout: 5) { tap("kid-back") }
        let sharks = ["whale", "hammerhead", "nurse", "great-white", "wobbegong", "thresher", "tiger", "epaulette", "goblin", "greenland",
                      "mako", "basking", "zebra", "blacktip-reef", "lemon", "bull", "sawshark", "cookiecutter", "angel", "port-jackson",
                      "blue", "leopard", "sand-tiger", "frilled", "megamouth", "swell", "dwarf-lantern", "spinner", "oceanic-whitetip", "pyjama"]
        let target = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Mission target")).firstMatch
        let questions = app.buttons["start-questions"]

        for shark in sharks {
            tap("shark-\(shark)")
            tap("play-mission")
            let start = app.buttons["Start!"]
            XCTAssertTrue(start.waitForExistence(timeout: 15), "\(shark): mission intro never offered Start")
            tapWhenReady(start)
            snap("mission-\(shark)")
            for attempt in 0..<40 where !questions.exists {
                if target.waitForExistence(timeout: 3) { target.tap() }
                // The second round is a word to read.
                if attempt == 0 { sleep(1); snap("mission-\(shark)-words") }
            }
            XCTAssertTrue(questions.waitForExistence(timeout: 5), "\(shark): mission never completed")
            questions.tap()
            XCTAssertTrue(app.buttons["answer-correct"].waitForExistence(timeout: 8), "\(shark): questions never appeared")
            // Leave without finishing, back to the map for the next shark.
            tap("kid-back")
            tap("confirm-stop")
            tap("kid-back")
            XCTAssertTrue(app.buttons["shark-whale"].waitForExistence(timeout: 8), "\(shark): did not return to the map")
        }
    }

    private func tap(_ identifier: String) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), identifier)
        button.tap()
    }

    /// Some controls stay inactive until narration finishes; keep trying until the tap takes effect.
    private func tapWhenReady(_ button: XCUIElement) {
        for _ in 0..<60 where button.exists {
            button.tap()
            sleep(1)
        }
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
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("shark-\(name).png"))
        }
    }
}
