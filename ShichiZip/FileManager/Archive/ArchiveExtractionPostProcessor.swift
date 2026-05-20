import Foundation

struct ArchiveExtractionPostProcessResult {
    let movedSourceArchiveToTrash: Bool
}

enum ArchiveExtractionPostProcessor {
    static func finalizeExtraction(sourceArchiveURL: URL?,
                                   moveSourceArchiveToTrash: Bool) throws -> ArchiveExtractionPostProcessResult
    {
        let standardizedSourceArchiveURL = sourceArchiveURL?.standardizedFileURL

        guard moveSourceArchiveToTrash,
              let standardizedSourceArchiveURL,
              FileManager.default.fileExists(atPath: standardizedSourceArchiveURL.path)
        else {
            return ArchiveExtractionPostProcessResult(movedSourceArchiveToTrash: false)
        }

        try FileManager.default.trashItem(at: standardizedSourceArchiveURL, resultingItemURL: nil)
        return ArchiveExtractionPostProcessResult(movedSourceArchiveToTrash: true)
    }
}
