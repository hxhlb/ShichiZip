import Foundation

extension FileManager {
    private static let szUniqueDestinationSuffixLimit = 9999

    func szUniqueDestinationURL(for desiredURL: URL,
                                isDirectory: Bool,
                                failureDescription: String = "A unique destination could not be created.") throws -> URL
    {
        let standardizedDesiredURL = desiredURL.standardizedFileURL
        guard fileExists(atPath: standardizedDesiredURL.path) else {
            return standardizedDesiredURL
        }

        let parentURL = standardizedDesiredURL.deletingLastPathComponent()
        let leafName = standardizedDesiredURL.lastPathComponent
        let pathExtension = (leafName as NSString).pathExtension
        let baseName = pathExtension.isEmpty ? leafName : (leafName as NSString).deletingPathExtension

        for suffix in 1 ... Self.szUniqueDestinationSuffixLimit {
            let candidateName = pathExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(pathExtension)"
            let candidateURL = parentURL.appendingPathComponent(candidateName,
                                                                isDirectory: isDirectory)
                .standardizedFileURL
            if !fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        throw NSError(domain: NSCocoaErrorDomain,
                      code: NSFileWriteFileExistsError,
                      userInfo: [
                          NSFilePathErrorKey: standardizedDesiredURL.path,
                          NSLocalizedDescriptionKey: failureDescription,
                      ])
    }
}
