import Foundation

func szStandardizedFileURL(fromUserPath path: String, relativeTo baseDirectory: URL? = nil) -> URL {
    let expandedPath = NSString(string: path).expandingTildeInPath
    let url = if let baseDirectory,
                 !NSString(string: expandedPath).isAbsolutePath
    {
        URL(fileURLWithPath: expandedPath, relativeTo: baseDirectory)
    } else {
        URL(fileURLWithPath: expandedPath)
    }

    return url.standardizedFileURL
}
