import Cocoa

enum FileManagerArchiveOpenMode {
    case defaultBehavior
    case wildcard
    case parser

    var openType: String? {
        switch self {
        case .defaultBehavior:
            nil
        case .wildcard:
            "*"
        case .parser:
            "#"
        }
    }
}

enum FileManagerArchiveOpenResult {
    case opened
    case unsupportedArchive(Error)
    case cancelled
    case failed(Error)
}

struct FileManagerArchiveMutationTarget {
    let archive: SZArchive
    let subdir: String
    let topLevelArchiveURL: URL?
}

struct FileManagerArchiveFileFingerprint: Equatable {
    let fileSize: UInt64
    let modificationDate: Date

    static func captureIfPossible(for url: URL,
                                  fileManager: FileManager = .default) -> FileManagerArchiveFileFingerprint?
    {
        let standardizedURL = url.standardizedFileURL
        guard let attributes = try? fileManager.attributesOfItem(atPath: standardizedURL.path),
              let modificationDate = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        return FileManagerArchiveFileFingerprint(fileSize: fileSize,
                                                 modificationDate: modificationDate)
    }
}

struct FileManagerNestedArchiveWriteBackInfo {
    let identity: FileManagerNestedArchiveIdentity
    let parentTarget: FileManagerArchiveMutationTarget
    let parentItemPath: String
    let initialFingerprint: FileManagerArchiveFileFingerprint
}

struct FileManagerPreparedArchiveOpen {
    let hostDirectory: URL
    let archivePath: String
    let displayPathPrefix: String
    let archive: SZArchive
    let entries: [ArchiveItem]
    let temporaryDirectory: URL?
    let nestedWriteBackInfo: FileManagerNestedArchiveWriteBackInfo?
}

enum FileManagerPreparedArchiveOpenResult {
    case opened(FileManagerPreparedArchiveOpen)
    case unsupportedArchive(Error)
    case cancelled
    case failed(Error)
}

enum FileManagerArchiveOpenService {
    @MainActor
    static func openSynchronously(url: URL,
                                  hostDirectory: URL,
                                  temporaryDirectory: URL?,
                                  displayPathPrefix: String,
                                  parentWindow: NSWindow? = nil,
                                  nestedWriteBackInfo: FileManagerNestedArchiveWriteBackInfo? = nil,
                                  openMode: FileManagerArchiveOpenMode = .defaultBehavior) -> FileManagerPreparedArchiveOpenResult
    {
        do {
            return try ArchiveOperationRunner.runSynchronously(operationTitle: SZL10n.string("progress.opening"),
                                                               initialFileName: displayPathPrefix,
                                                               parentWindow: parentWindow,
                                                               deferredDisplay: true)
            { session in
                prepareArchiveOpen(url: url,
                                   hostDirectory: hostDirectory,
                                   temporaryDirectory: temporaryDirectory,
                                   displayPathPrefix: displayPathPrefix,
                                   nestedWriteBackInfo: nestedWriteBackInfo,
                                   openMode: openMode,
                                   session: session)
            }
        } catch {
            return .failed(error)
        }
    }

    static func prepareArchiveOpen(url: URL,
                                   hostDirectory: URL,
                                   temporaryDirectory: URL?,
                                   displayPathPrefix: String,
                                   nestedWriteBackInfo: FileManagerNestedArchiveWriteBackInfo?,
                                   openMode: FileManagerArchiveOpenMode,
                                   session: SZOperationSession) -> FileManagerPreparedArchiveOpenResult
    {
        let archive = SZArchive()
        do {
            try coordinatedRead(at: url) { coordinatedURL in
                try archive.open(atPath: coordinatedURL.path,
                                 openType: openMode.openType,
                                 session: session)
            }
            let entries = try FileManagerArchiveListing.items(from: archive,
                                                              session: session)
            return .opened(FileManagerPreparedArchiveOpen(hostDirectory: hostDirectory,
                                                          archivePath: url.path,
                                                          displayPathPrefix: displayPathPrefix,
                                                          archive: archive,
                                                          entries: entries,
                                                          temporaryDirectory: temporaryDirectory,
                                                          nestedWriteBackInfo: nestedWriteBackInfo))
        } catch {
            archive.close()
            if szIsUnsupportedArchive(error) {
                return .unsupportedArchive(error)
            }
            if szIsUserCancellation(error) {
                return .cancelled
            }
            return .failed(error)
        }
    }

    /// Read the file through an `NSFileCoordinator` so cloud / file-provider
    /// placeholders are materialized before 7-Zip's POSIX `open(2)` runs, and
    /// hold a security-scoped access grant for the duration of the read so
    /// sandboxed entry points (Launch Services hand-off, bookmarks) work.
    private static func coordinatedRead(at url: URL,
                                        accessor: (URL) throws -> Void) throws
    {
        let needsScopeRelease = url.startAccessingSecurityScopedResource()
        defer { if needsScopeRelease { url.stopAccessingSecurityScopedResource() } }

        var coordinatorError: NSError?
        var accessorError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                try accessor(coordinatedURL)
            } catch {
                accessorError = error
            }
        }
        if let accessorError { throw accessorError }
        if let coordinatorError { throw coordinatorError }
    }
}
