import Foundation

struct ShichiZipQuickActionLogger {
    let action: ShichiZipQuickAction

    func log(_ message: String) {
        SZLog.info("QuickAction:\(action.rawValue)", message)
    }
}

struct ShichiZipQuickActionRequestPolicy {
    let action: ShichiZipQuickAction
    private let exactSelectionCount: Int?
    private let exactSelectionMessage: (@Sendable () -> String)?

    func makeRequest(from fileURLs: [URL]) throws -> ShichiZipQuickActionRequest {
        guard !fileURLs.isEmpty else {
            throw ShichiZipQuickActionError.unsupportedSelection("Select one or more files or folders.")
        }

        if let exactSelectionCount,
           fileURLs.count != exactSelectionCount
        {
            throw ShichiZipQuickActionError.unsupportedSelection(exactSelectionMessage?() ?? "The selection is not supported.")
        }

        return ShichiZipQuickActionRequest(action: action, fileURLs: fileURLs)
    }
}

extension ShichiZipQuickActionRequestPolicy {
    static let showInFileManager = ShichiZipQuickActionRequestPolicy(action: .showInFileManager,
                                                                     exactSelectionCount: nil,
                                                                     exactSelectionMessage: nil)

    static var openInShichiZip: ShichiZipQuickActionRequestPolicy {
        ShichiZipQuickActionRequestPolicy(action: .openInShichiZip,
                                          exactSelectionCount: 1,
                                          exactSelectionMessage: {
                                              "Select a single file or folder to open in \(ShichiZipQuickActionAppInfo.hostAppDisplayName)."
                                          })
    }

    static var smartQuickExtract: ShichiZipQuickActionRequestPolicy {
        ShichiZipQuickActionRequestPolicy(action: .smartQuickExtract,
                                          exactSelectionCount: 1,
                                          exactSelectionMessage: {
                                              "Select a single archive to extract."
                                          })
    }
}
