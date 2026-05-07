import Cocoa
@preconcurrency import QuickLookUI

enum FileManagerQuickLookLimits {
    static let maxArchiveItemSize: UInt64 = 128 * 1024 * 1024
    static let maxArchiveCombinedSize: UInt64 = 256 * 1024 * 1024
    static let maxSolidArchiveSize: UInt64 = 512 * 1024 * 1024
}

struct FileManagerQuickLookGenerationCounter {
    private var value: UInt64 = 0

    mutating func next() -> UInt64 {
        value &+= 1
        return value
    }

    func isCurrent(_ generation: UInt64) -> Bool {
        generation == value
    }
}

@MainActor
final class FileManagerQuickLookPreviewState {
    private(set) var items: [FileManagerQuickLookItem] = []
    private(set) weak var sourcePane: FileManagerPaneController?
    private var temporaryDirectories: [URL] = []

    var isEmpty: Bool {
        items.isEmpty
    }

    var count: Int {
        items.count
    }

    func item(at index: Int) -> FileManagerQuickLookItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    func replace(with preview: FileManagerQuickLookPreparedPreview,
                 sourcePane: FileManagerPaneController)
    {
        let oldTemporaryDirectories = temporaryDirectories
        let oldSourcePane = self.sourcePane

        // Swap items before cleanup so QL never observes an empty data source.
        self.sourcePane = sourcePane
        temporaryDirectories = preview.temporaryDirectories
        items = preview.items.map(FileManagerQuickLookItem.init(preparedItem:))

        if !oldTemporaryDirectories.isEmpty {
            let cleanupPane = oldSourcePane ?? sourcePane
            cleanupPane.cleanupQuickLookTemporaryDirectories(oldTemporaryDirectories)
        }
    }

    func clear() {
        if let sourcePane {
            sourcePane.cleanupQuickLookTemporaryDirectories(temporaryDirectories)
        }
        temporaryDirectories.removeAll()
        items.removeAll()
        sourcePane = nil
    }
}

final class FileManagerQuickLookItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    let sourceFrameOnScreen: NSRect
    let transitionImage: NSImage?
    let transitionContentRect: NSRect

    init(url: URL,
         title: String?,
         sourceFrameOnScreen: NSRect,
         transitionImage: NSImage?,
         transitionContentRect: NSRect)
    {
        previewItemURL = url
        previewItemTitle = title
        self.sourceFrameOnScreen = sourceFrameOnScreen
        self.transitionImage = transitionImage
        self.transitionContentRect = transitionContentRect
    }

    convenience init(preparedItem item: FileManagerQuickLookPreparedItem) {
        self.init(url: item.url,
                  title: item.title,
                  sourceFrameOnScreen: item.sourceFrameOnScreen,
                  transitionImage: item.transitionImage,
                  transitionContentRect: item.transitionContentRect)
    }
}
