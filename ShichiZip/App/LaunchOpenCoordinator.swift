import Foundation

/// Tracks launch-time and external-open state shared by `AppDelegate`.
@MainActor
final class LaunchOpenCoordinator {
    private var initialFileManagerSuppressed = false
    private var inFlightOpenCount = 0

    /// `true` when the auto-presented initial file manager should be skipped.
    var shouldSuppressInitialFileManager: Bool {
        initialFileManagerSuppressed || inFlightOpenCount > 0
    }

    /// Suppress the initial file manager without recording an in-flight open.
    func suppressInitialFileManager() {
        initialFileManagerSuppressed = true
    }

    /// Begin an external-open operation. Pair with `endExternalOpen()`.
    func beginExternalOpen() {
        initialFileManagerSuppressed = true
        inFlightOpenCount += 1
    }

    func endExternalOpen() {
        inFlightOpenCount = max(0, inFlightOpenCount - 1)
    }
}
