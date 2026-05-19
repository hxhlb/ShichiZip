import Foundation

extension FileManager {
    enum SZExistingItemKind: Equatable {
        case directory
        case nonDirectory
    }

    func szExistingItemKind(at url: URL) -> SZExistingItemKind? {
        guard fileExists(atPath: url.path) else {
            return nil
        }

        let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true ? .directory : .nonDirectory
    }

    func szDirectoryExists(at url: URL) -> Bool {
        szExistingItemKind(at: url) == .directory
    }
}
