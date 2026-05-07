import AppKit

enum FileManagerToolbarPreferences {
    enum Style: String {
        case expanded
        case unified

        var toolbarStyle: NSWindow.ToolbarStyle {
            switch self {
            case .expanded:
                .expanded
            case .unified:
                .unified
            }
        }
    }

    private static var defaults: UserDefaults {
        .standard
    }

    private static let archiveToolbarKey = "FileManager.ShowArchiveToolbar"
    private static let standardToolbarKey = "FileManager.ShowStandardToolbar"
    private static let showTextKey = "FileManager.ToolbarShowButtonText"
    private static let styleKey = "FileManager.ToolbarStyle"

    static var showsArchiveToolbar: Bool {
        bool(forKey: archiveToolbarKey, defaultValue: true)
    }

    static var showsStandardToolbar: Bool {
        bool(forKey: standardToolbarKey, defaultValue: true)
    }

    static var showsButtonText: Bool {
        bool(forKey: showTextKey, defaultValue: true)
    }

    static var style: Style {
        guard let rawValue = defaults.string(forKey: styleKey),
              let style = Style(rawValue: rawValue)
        else {
            return .expanded
        }
        return style
    }

    static func setShowsArchiveToolbar(_ value: Bool) {
        defaults.set(value, forKey: archiveToolbarKey)
    }

    static func setShowsStandardToolbar(_ value: Bool) {
        defaults.set(value, forKey: standardToolbarKey)
    }

    static func setShowsButtonText(_ value: Bool) {
        defaults.set(value, forKey: showTextKey)
    }

    static func setStyle(_ style: Style) {
        defaults.set(style.rawValue, forKey: styleKey)
    }

    private static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}

extension FileManagerWindowController: NSToolbarDelegate {
    static let addItem = NSToolbarItem.Identifier("fm_add")
    static let extractItem = NSToolbarItem.Identifier("fm_extract")
    static let testItem = NSToolbarItem.Identifier("fm_test")
    static let copyItem = NSToolbarItem.Identifier("fm_copy")
    static let moveItem = NSToolbarItem.Identifier("fm_move")
    static let deleteItem = NSToolbarItem.Identifier("fm_delete")
    static let infoItem = NSToolbarItem.Identifier("fm_info")

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem?
    {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        guard toolbarAllowedItemIdentifiers(toolbar).contains(itemIdentifier) else {
            return nil
        }

        configureToolbarItem(item)

        return item
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = []

        if FileManagerToolbarPreferences.showsArchiveToolbar {
            identifiers.append(contentsOf: [Self.addItem, Self.extractItem, Self.testItem])
        }

        if FileManagerToolbarPreferences.showsStandardToolbar {
            if !identifiers.isEmpty {
                identifiers.append(.space)
            }
            identifiers.append(contentsOf: [Self.copyItem, Self.moveItem, Self.deleteItem, Self.infoItem])
        }

        return identifiers
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.addItem, Self.extractItem, Self.testItem,
         Self.copyItem, Self.moveItem, Self.deleteItem, Self.infoItem,
         .space, .flexibleSpace]
    }

    func configureToolbarItem(_ item: NSToolbarItem) {
        item.target = self
        item.isBordered = true

        switch item.itemIdentifier {
        case Self.addItem:
            item.label = SZL10n.string("toolbar.add")
            item.toolTip = SZL10n.string("toolbar.add")
            item.image = toolbarImage(systemSymbolName: "plus.circle", accessibilityDescription: SZL10n.string("toolbar.add"))
            item.action = #selector(addToArchive(_:))

        case Self.extractItem:
            item.label = SZL10n.string("toolbar.extract")
            item.toolTip = SZL10n.string("toolbar.extract")
            item.image = toolbarImage(systemSymbolName: "tray.and.arrow.up", accessibilityDescription: SZL10n.string("toolbar.extract"))
            item.action = #selector(extractArchive(_:))

        case Self.testItem:
            item.label = SZL10n.string("toolbar.test")
            item.toolTip = SZL10n.string("toolbar.test")
            item.image = toolbarImage(systemSymbolName: "checkmark.seal", accessibilityDescription: SZL10n.string("toolbar.test"))
            item.action = #selector(testArchive(_:))

        case Self.copyItem:
            item.label = SZL10n.string("toolbar.copy")
            item.toolTip = SZL10n.string("toolbar.copy")
            item.image = toolbarImage(systemSymbolName: "doc.on.doc", accessibilityDescription: SZL10n.string("toolbar.copy"))
            item.action = #selector(copyFiles(_:))

        case Self.moveItem:
            item.label = SZL10n.string("toolbar.move")
            item.toolTip = SZL10n.string("toolbar.move")
            item.image = toolbarImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: SZL10n.string("toolbar.move"))
            item.action = #selector(moveFiles(_:))

        case Self.deleteItem:
            item.label = SZL10n.string("toolbar.delete")
            item.toolTip = SZL10n.string("toolbar.delete")
            item.image = toolbarImage(systemSymbolName: "trash", accessibilityDescription: SZL10n.string("toolbar.delete"))
            item.action = #selector(deleteFiles(_:))

        case Self.infoItem:
            item.label = SZL10n.string("toolbar.info")
            item.toolTip = SZL10n.string("toolbar.info")
            item.image = toolbarImage(systemSymbolName: "info.circle", accessibilityDescription: SZL10n.string("toolbar.info"))
            item.action = #selector(showProperties(_:))

        default:
            item.isBordered = false
        }
    }

    private func toolbarImage(systemSymbolName name: String,
                              accessibilityDescription: String) -> NSImage?
    {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
    }
}
