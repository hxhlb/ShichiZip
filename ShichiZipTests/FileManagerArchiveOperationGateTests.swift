import Foundation
import os
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

final class FileManagerArchiveOperationGateTests: XCTestCase {
    func testReportsActiveLeases() throws {
        let gate = FileManagerArchiveOperationGate()
        XCTAssertFalse(gate.hasActiveLeases)

        var firstLease: FileManagerArchiveOperationGate.Lease? = try XCTUnwrap(gate.acquireLease())
        XCTAssertNotNil(firstLease)
        XCTAssertTrue(gate.hasActiveLeases)

        var secondLease: FileManagerArchiveOperationGate.Lease? = try XCTUnwrap(gate.acquireLease())
        XCTAssertNotNil(secondLease)
        XCTAssertTrue(gate.hasActiveLeases)

        firstLease = nil
        XCTAssertTrue(gate.hasActiveLeases)

        secondLease = nil
        XCTAssertFalse(gate.hasActiveLeases)
    }

    func testRejectsNewLeaseAfterClosingBegins() throws {
        let gate = FileManagerArchiveOperationGate()
        let lease = try XCTUnwrap(gate.acquireLease())

        gate.beginClosing()

        XCTAssertNil(gate.acquireLease())

        gate.cancelClosing()
        XCTAssertNotNil(gate.acquireLease())
        withExtendedLifetime(lease) {}
    }

    func testWaitsForActiveLeaseBeforeClosing() throws {
        let gate = FileManagerArchiveOperationGate()
        var lease: FileManagerArchiveOperationGate.Lease? = try XCTUnwrap(gate.acquireLease())
        XCTAssertNotNil(lease)
        let didFinish = OSAllocatedUnfairLock(initialState: false)
        let closeFinished = expectation(description: "archive operation gate close finished")

        gate.beginClosing()
        DispatchQueue.global(qos: .userInitiated).async {
            gate.waitForLeasesToDrain()
            didFinish.withLock { $0 = true }
            closeFinished.fulfill()
        }

        let deadline = Date().addingTimeInterval(0.05)
        while Date() < deadline {
            if didFinish.withLock({ $0 }) {
                break
            }
            RunLoop.current.run(mode: .default,
                                before: Date().addingTimeInterval(0.005))
        }
        XCTAssertFalse(didFinish.withLock { $0 })

        lease = nil
        wait(for: [closeFinished], timeout: 1)
    }
}
