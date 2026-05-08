import Foundation
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

final class FileManagerArchiveListingTests: XCTestCase {
    func testItemsMaterializesArchiveEntries() throws {
        let tempRoot = try makeTemporaryDirectory(named: "archive-listing")
        let payloadURL = tempRoot.appendingPathComponent("payload.txt")
        let archiveURL = tempRoot.appendingPathComponent("payload.7z")
        try "payload".write(to: payloadURL, atomically: true, encoding: .utf8)
        try createArchive(at: archiveURL, from: [payloadURL])

        let archive = SZArchive()
        try archive.open(atPath: archiveURL.path, session: SZOperationSession())
        defer { archive.close() }

        let items = try FileManagerArchiveListing.items(from: archive,
                                                        session: nil)

        XCTAssertTrue(items.contains { $0.name == "payload.txt" && !$0.isDirectory })
    }
}
