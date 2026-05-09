import AppKit

@MainActor
struct FileManagerPaneExternalOpenService {
    typealias OpenCompletion = (NSRunningApplication?, Error?) -> Void
    typealias ApplicationOpener = (URL, URL, NSWorkspace.OpenConfiguration, @escaping OpenCompletion) -> Void

    private let defaultApplicationURL: (URL) -> URL?
    private let applicationOpener: ApplicationOpener
    private let scheduleCleanup: (URL, NSRunningApplication) -> Void
    private let cleanupTemporaryDirectory: (URL) -> Void
    private let showError: (Error) -> Void

    init(defaultApplicationURL: @escaping (URL) -> URL? = { FileManagerExternalOpenRouter.defaultExternalApplicationURL(for: $0) },
         applicationOpener: @escaping ApplicationOpener = { url, applicationURL, configuration, completion in
             NSWorkspace.shared.open([url],
                                     withApplicationAt: applicationURL,
                                     configuration: configuration)
             { app, error in
                 completion(app, error)
             }
         },
         scheduleCleanup: @escaping (URL, NSRunningApplication) -> Void,
         cleanupTemporaryDirectory: @escaping (URL) -> Void,
         showError: @escaping (Error) -> Void)
    {
        self.defaultApplicationURL = defaultApplicationURL
        self.applicationOpener = applicationOpener
        self.scheduleCleanup = scheduleCleanup
        self.cleanupTemporaryDirectory = cleanupTemporaryDirectory
        self.showError = showError
    }

    @discardableResult
    func openIfPossible(_ url: URL,
                        preservingTemporaryDirectory temporaryDirectory: URL? = nil) -> Bool
    {
        guard let applicationURL = defaultApplicationURL(url) else {
            return false
        }

        return open(url,
                    withApplicationAt: applicationURL,
                    preservingTemporaryDirectory: temporaryDirectory)
    }

    @discardableResult
    func open(_ url: URL,
              withApplicationAt applicationURL: URL,
              preservingTemporaryDirectory temporaryDirectory: URL? = nil) -> Bool
    {
        let configuration = NSWorkspace.OpenConfiguration()
        applicationOpener(url, applicationURL, configuration) { app, error in
            Task { @MainActor in
                handleOpenCompletion(app: app,
                                     error: error,
                                     temporaryDirectory: temporaryDirectory)
            }
        }
        return true
    }

    func unavailableExternalOpenError(for itemName: String) -> NSError {
        operationError(SZL10n.string("app.fileManager.error.noAppToOpen", itemName))
    }

    private func handleOpenCompletion(app: NSRunningApplication?,
                                      error: Error?,
                                      temporaryDirectory: URL?)
    {
        if let app {
            if let temporaryDirectory {
                scheduleCleanup(temporaryDirectory,
                                app)
            }
            return
        }

        if let temporaryDirectory {
            cleanupTemporaryDirectory(temporaryDirectory)
        }

        if let error,
           !FileManagerExternalOpenRouter.shouldSuppressExternalOpenError(error)
        {
            showError(error)
        }
    }

    private func operationError(_ description: String) -> NSError {
        NSError(domain: SZArchiveErrorDomain,
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: description])
    }
}
