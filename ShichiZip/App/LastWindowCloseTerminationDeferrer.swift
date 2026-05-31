import AppKit

@MainActor
final class LastWindowCloseTerminationDeferrer: NSObject {
    private weak var mostRecentClosingWindow: NSWindow?
    private var isObservingWindowWillClose = false
    private var hasPendingTermination = false
    private var pendingAnimationWindow: NSWindow?

    private let notificationCenter: NotificationCenter
    private let shouldTerminate: @MainActor () -> Bool
    private let terminate: @MainActor () -> Void

    /// Undocumented AppKit notification posted after macOS 26's window-close animation orders the window off-screen.
    private static let windowDidOrderOffScreenAndFinishAnimatingNotification =
        Notification.Name("NSWindowDidOrderOffScreenAndFinishAnimatingNotification")

    init(notificationCenter: NotificationCenter = .default,
         shouldTerminate: @escaping @MainActor () -> Bool,
         terminate: @escaping @MainActor () -> Void)
    {
        self.notificationCenter = notificationCenter
        self.shouldTerminate = shouldTerminate
        self.terminate = terminate
    }

    func startObservingClosingWindows() {
        guard !isObservingWindowWillClose else { return }
        notificationCenter.addObserver(self,
                                       selector: #selector(windowWillClose(_:)),
                                       name: NSWindow.willCloseNotification,
                                       object: nil)
        isObservingWindowWillClose = true
    }

    func deferTerminationUntilCloseAnimationFinishes() {
        clearPendingAnimationObserver()

        hasPendingTermination = true
        pendingAnimationWindow = mostRecentClosingWindow
        mostRecentClosingWindow = nil

        // Retain and filter to the window that triggered AppKit's last-window-close decision
        // so unrelated order-off animations cannot complete the pending termination.
        notificationCenter.addObserver(self,
                                       selector: #selector(windowDidOrderOffScreenAndFinishAnimating(_:)),
                                       name: Self.windowDidOrderOffScreenAndFinishAnimatingNotification,
                                       object: pendingAnimationWindow)
    }

    func stop() {
        clearPendingAnimationObserver()
        if isObservingWindowWillClose {
            notificationCenter.removeObserver(self,
                                              name: NSWindow.willCloseNotification,
                                              object: nil)
            isObservingWindowWillClose = false
        }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        mostRecentClosingWindow = notification.object as? NSWindow
    }

    @objc private func windowDidOrderOffScreenAndFinishAnimating(_: Notification) {
        terminateIfStillNeeded()
    }

    private func terminateIfStillNeeded() {
        guard hasPendingTermination else { return }
        clearPendingAnimationObserver()
        guard shouldTerminate() else { return }
        terminate()
    }

    private func clearPendingAnimationObserver() {
        if hasPendingTermination {
            notificationCenter.removeObserver(self,
                                              name: Self.windowDidOrderOffScreenAndFinishAnimatingNotification,
                                              object: pendingAnimationWindow)
        }
        hasPendingTermination = false
        pendingAnimationWindow = nil
    }
}
