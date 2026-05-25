import Foundation
#if SHICHIZIP_ZS_VARIANT
    @testable import ShichiZip_ZS
#else
    @testable import ShichiZip
#endif
import XCTest

final class SharedUserDefaultsTests: XCTestCase {
    func testSharedDefaultsUsesConfiguredAppGroupWhenAvailable() throws {
        guard SZSharedUserDefaults.appGroupIdentifier != nil else {
            throw XCTSkip("App group identifier is not configured for this test host.")
        }

        XCTAssertNotNil(SZSharedUserDefaults.sharedDefaults)
    }

    func testMigrationCopiesAppDomainWithoutOverwritingSharedValuesAndRemovesSource() throws {
        let source = try makeIsolatedDefaults()
        let destination = try makeIsolatedDefaults()
        let preservedSharedValue = false

        source.defaults.set(true, forKey: "ShowHiddenFiles")
        source.defaults.set(true, forKey: "SZShowPasswordInPrompts")
        source.defaults.set(["/tmp/archive.zip"], forKey: "FileManager.CompressArchivePathHistory")
        source.defaults.set("domain-owned", forKey: "UnrelatedPreference")
        destination.defaults.set(preservedSharedValue, forKey: "ShowHiddenFiles")

        let migratedCount = SZSharedUserDefaults.migrateDefaultsDomain(named: source.suiteName,
                                                                       from: source.defaults,
                                                                       to: destination.defaults,
                                                                       destinationDomainName: destination.suiteName,
                                                                       removesSourceDomain: true)

        XCTAssertEqual(migratedCount, 3)
        XCTAssertEqual(destination.defaults.bool(forKey: "ShowHiddenFiles"),
                       preservedSharedValue)
        XCTAssertTrue(destination.defaults.bool(forKey: "SZShowPasswordInPrompts"))
        XCTAssertEqual(destination.defaults.stringArray(forKey: "FileManager.CompressArchivePathHistory"),
                       ["/tmp/archive.zip"])
        XCTAssertEqual(destination.defaults.string(forKey: "UnrelatedPreference"), "domain-owned")
        XCTAssertNil(source.defaults.persistentDomain(forName: source.suiteName))
    }

    private func makeIsolatedDefaults() throws -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "SharedUserDefaultsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return (suiteName, defaults)
    }
}
