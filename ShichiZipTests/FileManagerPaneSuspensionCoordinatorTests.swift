import AppKit
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

@MainActor
final class FileManagerPaneSuspensionCoordinatorTests: XCTestCase {
    func testPrepareForCloseKeepsPaneActiveWhenArchiveCloseFails() {
        var closeShowError: Bool?
        let harness = makeCoordinator(isInsideArchive: { true },
                                      closeAllArchives: { showError in
                                          closeShowError = showError
                                          return false
                                      },
                                      prepareDirectoryForSuspension: {
                                          XCTFail("Failed archive close must not suspend the pane")
                                      })

        XCTAssertFalse(harness.coordinator.prepareForClose(showError: true))

        XCTAssertEqual(closeShowError, true)
        XCTAssertFalse(harness.coordinator.isSuspended)
        XCTAssertNil(suspendedOverlay(in: harness))
    }

    func testPrepareForCloseSuspendsAfterArchiveCloseSucceeds() {
        var isInsideArchive = true
        var closeShowError: Bool?
        var prepareCount = 0
        var cancelRefreshCount = 0
        var clearArchiveDisplayCount = 0
        let harness = makeCoordinator(isInsideArchive: { isInsideArchive },
                                      closeAllArchives: { showError in
                                          closeShowError = showError
                                          isInsideArchive = false
                                          return true
                                      },
                                      prepareDirectoryForSuspension: { prepareCount += 1 },
                                      cancelPendingArchiveRefresh: { cancelRefreshCount += 1 },
                                      clearArchiveDisplayItems: { clearArchiveDisplayCount += 1 })

        XCTAssertTrue(harness.coordinator.prepareForClose(showError: false))

        XCTAssertEqual(closeShowError, false)
        XCTAssertTrue(harness.coordinator.isSuspended)
        XCTAssertEqual(prepareCount, 1)
        XCTAssertEqual(cancelRefreshCount, 1)
        XCTAssertEqual(clearArchiveDisplayCount, 1)
        XCTAssertEqual(harness.statusLabel.stringValue, "")
        XCTAssertNotNil(suspendedOverlay(in: harness))
    }

    func testPrepareForDeactivationSuspendsLoadedFilesystemPaneWithoutClosingArchive() {
        var closeCount = 0
        var prepareCount = 0
        let harness = makeCoordinator(isInsideArchive: { false },
                                      closeAllArchives: { _ in
                                          closeCount += 1
                                          return true
                                      },
                                      prepareDirectoryForSuspension: { prepareCount += 1 })

        XCTAssertTrue(harness.coordinator.prepareForDeactivation(showError: true))

        XCTAssertEqual(closeCount, 0)
        XCTAssertEqual(prepareCount, 1)
        XCTAssertTrue(harness.coordinator.isSuspended)
        XCTAssertNotNil(suspendedOverlay(in: harness))
    }

    func testCloseDirectoryDoesNotRepeatSuspensionWhenAlreadySuspended() {
        var prepareCount = 0
        let harness = makeCoordinator(isInsideArchive: { false },
                                      prepareDirectoryForSuspension: { prepareCount += 1 })

        harness.coordinator.closeDirectory()
        harness.coordinator.closeDirectory()

        XCTAssertTrue(harness.coordinator.isSuspended)
        XCTAssertEqual(prepareCount, 1)
        XCTAssertNotNil(suspendedOverlay(in: harness))
    }

    func testCloseDirectorySuspendsOnlyAfterArchiveActuallyCloses() {
        var isInsideArchive = true
        var prepareCount = 0
        let harness = makeCoordinator(isInsideArchive: { isInsideArchive },
                                      closeAllArchives: { _ in
                                          isInsideArchive = false
                                          return true
                                      },
                                      prepareDirectoryForSuspension: { prepareCount += 1 })

        harness.coordinator.closeDirectory()

        XCTAssertFalse(isInsideArchive)
        XCTAssertTrue(harness.coordinator.isSuspended)
        XCTAssertEqual(prepareCount, 1)
    }

    func testReactivateIfSuspendedLoadsCurrentDirectoryAndClearsStateOnSuccess() {
        let directoryURL = URL(fileURLWithPath: "/tmp/reactivate-success", isDirectory: true)
        var loadRequest: (url: URL, showError: Bool)?
        let harness = makeCoordinator(currentDirectory: { directoryURL },
                                      loadDirectory: { url, showError in
                                          loadRequest = (url, showError)
                                          return true
                                      })
        harness.coordinator.closeDirectory()

        harness.coordinator.reactivateIfSuspended()

        XCTAssertEqual(loadRequest?.url, directoryURL)
        XCTAssertEqual(loadRequest?.showError, true)
        XCTAssertFalse(harness.coordinator.isSuspended)
        XCTAssertNil(suspendedOverlay(in: harness))
    }

    func testReactivateKeepsPaneSuspendedWhenDirectoryLoadFails() {
        let harness = makeCoordinator(loadDirectory: { _, _ in false })
        harness.coordinator.closeDirectory()

        harness.coordinator.reactivateIfSuspended()

        XCTAssertTrue(harness.coordinator.isSuspended)
        XCTAssertNotNil(suspendedOverlay(in: harness))
    }

    private func makeCoordinator(isViewLoaded: @escaping () -> Bool = { true },
                                 isInsideArchive: @escaping () -> Bool = { false },
                                 closeAllArchives: @escaping (Bool) -> Bool = { _ in true },
                                 prepareDirectoryForSuspension: @escaping () -> Void = {},
                                 cancelPendingArchiveRefresh: @escaping () -> Void = {},
                                 clearArchiveDisplayItems: @escaping () -> Void = {},
                                 currentDirectory: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser },
                                 loadDirectory: @escaping (URL, Bool) -> Bool = { _, _ in true }) -> SuspensionHarness
    {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        let statusLabel = NSTextField(labelWithString: "ready")
        let coordinator = FileManagerPaneSuspensionCoordinator(isViewLoaded: isViewLoaded,
                                                               isInsideArchive: isInsideArchive,
                                                               closeAllArchives: closeAllArchives,
                                                               prepareDirectoryForSuspension: prepareDirectoryForSuspension,
                                                               cancelPendingArchiveRefresh: cancelPendingArchiveRefresh,
                                                               clearArchiveDisplayItems: clearArchiveDisplayItems,
                                                               clearStatusText: { statusLabel.stringValue = "" },
                                                               containerView: { containerView },
                                                               scrollView: { scrollView },
                                                               currentDirectory: currentDirectory,
                                                               loadDirectory: loadDirectory)

        return SuspensionHarness(coordinator: coordinator,
                                 containerView: containerView,
                                 scrollView: scrollView,
                                 statusLabel: statusLabel)
    }

    private func suspendedOverlay(in harness: SuspensionHarness) -> NSView? {
        harness.containerView.subviews.first { $0 !== harness.scrollView }
    }
}

@MainActor
private struct SuspensionHarness {
    let coordinator: FileManagerPaneSuspensionCoordinator
    let containerView: NSView
    let scrollView: NSScrollView
    let statusLabel: NSTextField
}
