import Foundation
import os
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

@MainActor
final class FileManagerPaneDirectoryCoordinatorTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try skipIfAffectedByIsolatedDeinitTaskLocalRuntimeBug()
    }

    func testLoadDirectoryAppliesSnapshotAndPresentationCallbacks() throws {
        let directoryURL = try makeTemporaryDirectory(named: "load-directory",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        try "alpha".write(to: directoryURL.appendingPathComponent("alpha.txt"),
                          atomically: true,
                          encoding: .utf8)
        try "beta".write(to: directoryURL.appendingPathComponent("beta.txt"),
                         atomically: true,
                         encoding: .utf8)
        var didUpdatePathField = false
        var didUpdateStatusBar = false
        var didUpdateTableColumns = false
        var didReloadTableData = false
        let coordinator = makeCoordinator(updatePathField: { didUpdatePathField = true },
                                          updateStatusBar: { didUpdateStatusBar = true },
                                          updateTableColumns: { didUpdateTableColumns = true },
                                          reloadTableData: { didReloadTableData = true })
        defer { coordinator.tearDown() }

        XCTAssertTrue(coordinator.loadDirectory(directoryURL))

        XCTAssertEqual(coordinator.currentDirectory.standardizedFileURL,
                       directoryURL.standardizedFileURL)
        XCTAssertEqual(Set(coordinator.items.map(\.name)), ["alpha.txt", "beta.txt"])
        XCTAssertEqual(coordinator.recentDirectoryHistory().first,
                       directoryURL.standardizedFileURL)
        XCTAssertTrue(didUpdatePathField)
        XCTAssertTrue(didUpdateStatusBar)
        XCTAssertTrue(didUpdateTableColumns)
        XCTAssertTrue(didReloadTableData)
    }

    func testPrepareForSuspensionClearsPresentedItemsAndReloadsTable() throws {
        let directoryURL = try makeTemporaryDirectory(named: "suspend-directory",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        try "payload".write(to: directoryURL.appendingPathComponent("payload.txt"),
                            atomically: true,
                            encoding: .utf8)
        var reloadCount = 0
        let coordinator = makeCoordinator(reloadTableData: { reloadCount += 1 })
        defer { coordinator.tearDown() }

        XCTAssertTrue(coordinator.loadDirectory(directoryURL))
        XCTAssertFalse(coordinator.items.isEmpty)

        coordinator.prepareForSuspension()

        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertGreaterThanOrEqual(reloadCount, 2)
    }

    func testPrepareForArchivePresentationUpdatesCurrentDirectoryAndHistory() throws {
        let hostDirectory = try makeTemporaryDirectory(named: "archive-host",
                                                       prefix: "ShichiZipDirectoryCoordinatorTests")
        let coordinator = makeCoordinator()
        defer { coordinator.tearDown() }

        coordinator.prepareForArchivePresentation(hostDirectory: hostDirectory)

        XCTAssertEqual(coordinator.currentDirectory.standardizedFileURL,
                       hostDirectory.standardizedFileURL)
        XCTAssertEqual(coordinator.recentDirectoryHistory().first,
                       hostDirectory.standardizedFileURL)
    }

    func testRevealSelectionRequestsCenteredScrollPlacement() throws {
        let directoryURL = try makeTemporaryDirectory(named: "reveal-centered-selection",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        let firstURL = directoryURL.appendingPathComponent("alpha.txt")
        let secondURL = directoryURL.appendingPathComponent("beta.txt")
        try "alpha".write(to: firstURL,
                          atomically: true,
                          encoding: .utf8)
        try "beta".write(to: secondURL,
                         atomically: true,
                         encoding: .utf8)

        var selectedRows = IndexSet()
        var scrolledRows: [(Int, FileManagerFileSystemSelectionScrollPlacement)] = []
        let coordinator = makeCoordinator(selectRows: { selectedRows = $0 },
                                          scrollRow: { row, placement in
                                              scrolledRows.append((row, placement))
                                          })
        defer { coordinator.tearDown() }

        XCTAssertTrue(coordinator.navigateToDirectory(directoryURL,
                                                      showError: true,
                                                      selectionState: FileManagerFileSystemSelectionState(selectedPaths: [secondURL.standardizedFileURL.path],
                                                                                                          focusedPath: secondURL.standardizedFileURL.path,
                                                                                                          scrollPlacement: .centered)))

        XCTAssertEqual(selectedRows.count, 1)
        XCTAssertEqual(scrolledRows.count, 1)
        XCTAssertEqual(scrolledRows.first?.1, .centered)
    }

    func testBudgetedNavigationAppliesSnapshotInlineWithoutLoadingWhenFast() throws {
        let directoryURL = try makeTemporaryDirectory(named: "budget-fast",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        var loadingEvents: [Bool] = []
        let provider: @Sendable (URL) throws -> FileManagerDirectorySnapshot = { url in
            FileManagerDirectorySnapshot(url: url,
                                         items: [FileSystemItem(url: url.appendingPathComponent("alpha.txt"),
                                                                resourceValues: nil)])
        }
        let coordinator = makeCoordinator(setDirectoryLoadingVisible: { loadingEvents.append($0) },
                                          makeSnapshot: provider)
        defer { coordinator.tearDown() }

        let applied = coordinator.navigateToDirectory(directoryURL,
                                                      showError: true,
                                                      budget: .milliseconds(500))

        XCTAssertTrue(applied)
        XCTAssertFalse(loadingEvents.contains(true))
        XCTAssertEqual(coordinator.items.map(\.name), ["alpha.txt"])
        XCTAssertEqual(coordinator.currentDirectory.standardizedFileURL,
                       directoryURL.standardizedFileURL)
    }

    func testBudgetedNavigationShowsLoadingThenAppliesWhenSlow() throws {
        let directoryURL = try makeTemporaryDirectory(named: "budget-slow",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        let gate = DispatchSemaphore(value: 0)
        var loadingEvents: [Bool] = []
        let applyExpectation = expectation(description: "async snapshot applied")
        applyExpectation.assertForOverFulfill = false
        let provider: @Sendable (URL) throws -> FileManagerDirectorySnapshot = { url in
            gate.wait()
            return FileManagerDirectorySnapshot(url: url,
                                                items: [FileSystemItem(url: url.appendingPathComponent("beta.txt"),
                                                                       resourceValues: nil)])
        }
        let coordinator = makeCoordinator(reloadTableData: { applyExpectation.fulfill() },
                                          setDirectoryLoadingVisible: { loadingEvents.append($0) },
                                          makeSnapshot: provider)
        defer { coordinator.tearDown() }

        let applied = coordinator.navigateToDirectory(directoryURL,
                                                      showError: true,
                                                      budget: .milliseconds(20))

        XCTAssertTrue(applied)
        XCTAssertTrue(loadingEvents.contains(true))
        XCTAssertTrue(coordinator.items.isEmpty)

        gate.signal()
        wait(for: [applyExpectation], timeout: 2)

        XCTAssertEqual(loadingEvents.last, false)
        XCTAssertEqual(coordinator.items.map(\.name), ["beta.txt"])
        XCTAssertEqual(coordinator.currentDirectory.standardizedFileURL,
                       directoryURL.standardizedFileURL)
    }

    func testReapplyHiddenFileVisibilityFiltersWithoutReenumerating() throws {
        let directoryURL = try makeTemporaryDirectory(named: "render-filter",
                                                      prefix: "ShichiZipDirectoryCoordinatorTests")
        let enumerationCount = OSAllocatedUnfairLock(initialState: 0)
        let provider: @Sendable (URL) throws -> FileManagerDirectorySnapshot = { url in
            enumerationCount.withLock { $0 += 1 }
            return FileManagerDirectorySnapshot(url: url,
                                                items: [FileSystemItem(url: url.appendingPathComponent("alpha.txt"),
                                                                       resourceValues: nil),
                                                        FileSystemItem(url: url.appendingPathComponent(".secret"),
                                                                       resourceValues: nil)])
        }
        var showHidden = false
        var reloadCount = 0
        let coordinator = makeCoordinator(reloadTableData: { reloadCount += 1 },
                                          makeSnapshot: provider,
                                          showsHiddenFiles: { showHidden })
        defer { coordinator.tearDown() }

        XCTAssertTrue(coordinator.loadDirectory(directoryURL))
        XCTAssertEqual(coordinator.items.map(\.name), ["alpha.txt"])

        showHidden = true
        coordinator.reapplyHiddenFileVisibility()
        XCTAssertEqual(Set(coordinator.items.map(\.name)), ["alpha.txt", ".secret"])

        showHidden = false
        coordinator.reapplyHiddenFileVisibility()
        XCTAssertEqual(coordinator.items.map(\.name), ["alpha.txt"])

        XCTAssertGreaterThan(reloadCount, 1)
        XCTAssertEqual(enumerationCount.withLock { $0 }, 1)
    }

    func testPaneDeinitWithoutLoadedViewDoesNotInitializeCoordinators() {
        weak var weakPane: FileManagerPaneController?

        autoreleasepool {
            let pane = FileManagerPaneController()
            weakPane = pane
        }

        XCTAssertNil(weakPane)
    }

    func testPaneDeinitAfterLoadingFileSystemViewDoesNotInitializeArchiveCoordinator() {
        weak var weakPane: FileManagerPaneController?

        autoreleasepool {
            let pane = FileManagerPaneController()
            _ = pane.view
            weakPane = pane
        }

        XCTAssertNil(weakPane)
    }

    private func makeCoordinator(isViewLoaded: @escaping () -> Bool = { true },
                                 isInsideArchive: @escaping () -> Bool = { false },
                                 showsParentRow: @escaping () -> Bool = { false },
                                 selectedFileSystemItems: @escaping () -> [FileSystemItem] = { [] },
                                 focusedFileSystemItemPath: @escaping () -> String? = { nil },
                                 clearSuspendedState: @escaping () -> Void = {},
                                 updatePathField: @escaping () -> Void = {},
                                 updateStatusBar: @escaping () -> Void = {},
                                 updateTableColumns: @escaping () -> Void = {},
                                 sortCurrentItems: @escaping () -> Void = {},
                                 reloadTableData: @escaping () -> Void = {},
                                 focusFileList: @escaping () -> Void = {},
                                 selectRows: @escaping (IndexSet) -> Void = { _ in },
                                 deselectRows: @escaping () -> Void = {},
                                 scrollRow: @escaping (Int, FileManagerFileSystemSelectionScrollPlacement) -> Void = { _, _ in },
                                 showError: @escaping (Error) -> Void = { error in XCTFail("Unexpected directory coordinator error: \(error)") },
                                 directoryDidChange: @escaping () -> Void = {},
                                 setDirectoryLoadingVisible: @escaping (Bool) -> Void = { _ in },
                                 makeSnapshot: @escaping @Sendable (URL) throws -> FileManagerDirectorySnapshot = { try FileManagerDirectorySnapshot.make(for: $0) },
                                 showsHiddenFiles: @escaping () -> Bool = { false }) -> FileManagerPaneDirectoryCoordinator
    {
        FileManagerPaneDirectoryCoordinator(isViewLoaded: isViewLoaded,
                                            isInsideArchive: isInsideArchive,
                                            showsParentRow: showsParentRow,
                                            selectedFileSystemItems: selectedFileSystemItems,
                                            focusedFileSystemItemPath: focusedFileSystemItemPath,
                                            clearSuspendedState: clearSuspendedState,
                                            updatePathField: updatePathField,
                                            updateStatusBar: updateStatusBar,
                                            updateTableColumns: updateTableColumns,
                                            sortCurrentItems: sortCurrentItems,
                                            reloadTableData: reloadTableData,
                                            focusFileList: focusFileList,
                                            selectRows: selectRows,
                                            deselectRows: deselectRows,
                                            scrollRow: scrollRow,
                                            showError: showError,
                                            directoryDidChange: directoryDidChange,
                                            setDirectoryLoadingVisible: setDirectoryLoadingVisible,
                                            makeSnapshot: makeSnapshot,
                                            showsHiddenFiles: showsHiddenFiles)
    }
}
