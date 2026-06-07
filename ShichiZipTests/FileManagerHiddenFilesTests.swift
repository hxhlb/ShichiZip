#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import AppKit
import XCTest

final class FileManagerHiddenFilesTests: XCTestCase {
    func testDefaultShortcutMapsToggleHiddenFilesToCommandShiftPeriod() {
        let shortcut = FileManagerShortcuts.binding(for: .toggleHiddenFiles,
                                                    preset: .finder).shortcut

        XCTAssertEqual(shortcut?.keyEquivalent, ".")
        XCTAssertEqual(shortcut?.modifiers, [.command, .shift])
        XCTAssertNil(FileManagerShortcuts.binding(for: .toggleHiddenFiles,
                                                  preset: .commander).shortcut)
    }

    func testFileSystemItemMarksDotItemsHidden() {
        let visible = FileSystemItem(url: URL(fileURLWithPath: "/tmp/visible.txt"))
        let hidden = FileSystemItem(url: URL(fileURLWithPath: "/tmp/.hidden"))

        XCTAssertFalse(visible.isHidden)
        XCTAssertTrue(hidden.isHidden)
    }
}
