import XCTest

final class LaunchOpenHUDUITests: ShichiZipUITestCase {
    func testExtractNowButtonExtractsArchive() throws {
        let fixture = try makeTestArchive(named: "launch-open-extract-now",
                                          payloads: ["payload.txt": "extract now"])
        relaunchForLaunchOpenHUD(archiveURL: fixture.archive,
                                 delaySeconds: 10.0)

        let extractButton = launchOpenHUDButton("launchOpenHUD.extractNow")
        XCTAssertTrue(extractButton.waitForExistence(timeout: 10), "Extract Now should be visible")
        extractButton.click()

        XCTAssertTrue(waitForFile(at: fixture.directory.appendingPathComponent("payload.txt")),
                      "Extract Now should smart-extract the archive payload")
    }

    func testBrowseButtonOpensArchiveContentsInsteadOfExtracting() throws {
        let fixture = try makeTestArchive(named: "launch-open-browse",
                                          payloads: ["browse.txt": "browse instead"])
        relaunchForLaunchOpenHUD(archiveURL: fixture.archive,
                                 delaySeconds: 10.0)

        let browseButton = launchOpenHUDButton("launchOpenHUD.browse")
        XCTAssertTrue(browseButton.waitForExistence(timeout: 10), "Browse should be visible")
        browseButton.click()

        let pathPredicate = NSPredicate(format: "value CONTAINS %@", fixture.archive.lastPathComponent)
        let pathExpectation = XCTNSPredicateExpectation(predicate: pathPredicate, object: leftPanePathField)
        wait(for: [pathExpectation], timeout: 10)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("browse.txt").path),
                       "Browse should open the archive in the file manager without extracting it")
    }

    func testCountdownExtractsEvenWhenQuitAfterLastWindowCloseIsEnabled() throws {
        let fixture = try makeTestArchive(named: "launch-open-countdown",
                                          payloads: ["countdown.txt": "countdown"])
        relaunchForLaunchOpenHUD(archiveURL: fixture.archive,
                                 delaySeconds: 0.5,
                                 quitAfterLastWindowClosed: true)

        XCTAssertTrue(waitForFile(at: fixture.directory.appendingPathComponent("countdown.txt"), timeout: 20),
                      "Countdown expiry should extract before the app is allowed to quit")
    }

    private func relaunchForLaunchOpenHUD(archiveURL: URL,
                                          delaySeconds: TimeInterval,
                                          quitAfterLastWindowClosed: Bool = false)
    {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)

        app = XCUIApplication()
        app.launchArguments = [
            "-LaunchOpenDefaultAction", "extract",
            "-LaunchOpenRevealAfterExtract", "NO",
            "-LaunchOpenBrowseModifier", "control",
            "-SZLaunchOpenDelaySeconds", "\(delaySeconds)",
            "-MoveArchiveToTrashAfterExtraction", "NO",
            "-QuitAfterLastWindowClosed", quitAfterLastWindowClosed ? "YES" : "NO",
        ]
        app.launchEnvironment = [
            "SHICHIZIP_FORCE_DEFAULT_LAUNCH": "1",
            "SHICHIZIP_DISABLE_LIST_VIEW_INFO_PERSISTENCE": "1",
            "SHICHIZIP_DISABLE_SMART_QUICK_EXTRACT_REVEAL": "1",
            "SHICHIZIP_UI_TEST_LAUNCH_OPEN_ARCHIVES": archiveURL.path,
        ]
        app.launch()
    }

    private func launchOpenHUDButton(_ identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }
}
