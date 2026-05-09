import Foundation

struct FileManagerNestedArchiveIdentity: Hashable {
    let displayPath: String

    init(displayPath: String) {
        self.displayPath = NSString(string: displayPath).standardizingPath
    }
}

struct FileManagerNestedArchiveOpenSnapshot: Equatable {
    let archiveIdentifier: ObjectIdentifier
    let identity: FileManagerNestedArchiveIdentity?
    let isDirty: Bool
}

enum FileManagerNestedArchiveConflictDetector {
    static func hasConflictingOpenInstance(for identity: FileManagerNestedArchiveIdentity,
                                           in snapshots: [FileManagerNestedArchiveOpenSnapshot]) -> Bool
    {
        var matchingArchiveIdentifiers = Set<ObjectIdentifier>()

        for snapshot in snapshots where snapshot.identity == identity {
            matchingArchiveIdentifiers.insert(snapshot.archiveIdentifier)
            if matchingArchiveIdentifiers.count > 1 {
                return true
            }
        }

        return false
    }

    static func hasDirtyOpenInstance(for identity: FileManagerNestedArchiveIdentity,
                                     in snapshots: [FileManagerNestedArchiveOpenSnapshot]) -> Bool
    {
        for snapshot in snapshots where snapshot.identity == identity {
            if snapshot.isDirty {
                return true
            }
        }

        return false
    }
}
