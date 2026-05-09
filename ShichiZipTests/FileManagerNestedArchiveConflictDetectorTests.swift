import Foundation
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

final class FileManagerNestedArchiveConflictDetectorTests: XCTestCase {
    func testNestedArchiveIdentityStandardizesDisplayPath() {
        let identity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/../folder/inner.7z")

        XCTAssertEqual(identity,
                       FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z"))
    }

    func testIgnoresSingleOpenInstance() {
        let archive = NSObject()
        let identity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z")
        let snapshots = [
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(archive),
                                                 identity: identity,
                                                 isDirty: false),
        ]

        XCTAssertFalse(FileManagerNestedArchiveConflictDetector.hasConflictingOpenInstance(for: identity,
                                                                                           in: snapshots))
    }

    func testDetectsDistinctArchiveObjectsWithSameIdentity() {
        let firstArchive = NSObject()
        let secondArchive = NSObject()
        let identity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z")
        let snapshots = [
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(firstArchive),
                                                 identity: identity,
                                                 isDirty: false),
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(secondArchive),
                                                 identity: identity,
                                                 isDirty: false),
        ]

        XCTAssertTrue(FileManagerNestedArchiveConflictDetector.hasConflictingOpenInstance(for: identity,
                                                                                          in: snapshots))
    }

    func testIgnoresDifferentNestedIdentity() {
        let firstArchive = NSObject()
        let secondArchive = NSObject()
        let targetIdentity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z")
        let snapshots = [
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(firstArchive),
                                                 identity: targetIdentity,
                                                 isDirty: true),
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(secondArchive),
                                                 identity: FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/other.7z"),
                                                 isDirty: true),
        ]

        XCTAssertFalse(FileManagerNestedArchiveConflictDetector.hasConflictingOpenInstance(for: targetIdentity,
                                                                                           in: snapshots))
    }

    func testDetectsDirtyOpenInstanceWithSameIdentity() {
        let dirtyArchive = NSObject()
        let identity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z")
        let snapshots = [
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(dirtyArchive),
                                                 identity: identity,
                                                 isDirty: true),
        ]

        XCTAssertTrue(FileManagerNestedArchiveConflictDetector.hasDirtyOpenInstance(for: identity,
                                                                                    in: snapshots))
    }

    func testIgnoresCleanOpenInstanceForDirtyCheck() {
        let cleanArchive = NSObject()
        let identity = FileManagerNestedArchiveIdentity(displayPath: "/tmp/root.7z/folder/inner.7z")
        let snapshots = [
            FileManagerNestedArchiveOpenSnapshot(archiveIdentifier: ObjectIdentifier(cleanArchive),
                                                 identity: identity,
                                                 isDirty: false),
        ]

        XCTAssertFalse(FileManagerNestedArchiveConflictDetector.hasDirtyOpenInstance(for: identity,
                                                                                     in: snapshots))
    }
}
