import Cocoa
import UniformTypeIdentifiers

struct IntegrationFileAssociation {
    let displayName: String
    let handlerRank: String
    let contentTypeIdentifiers: [String]

    var primaryTypeIdentifier: String {
        contentTypeIdentifiers[0]
    }

    var contentTypes: [UTType] {
        contentTypeIdentifiers.map { UTType(importedAs: $0) }
    }

    var isDefaultRanked: Bool {
        handlerRank == "Default"
    }

    private static let excludedTypeIdentifiers: Set<String> = [
        "public.data",
        "com.aone.keka-extraction",
    ]

    static func supportedDocumentTypes(bundle: Bundle = .main) -> [IntegrationFileAssociation] {
        guard let documentTypes = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] else {
            return []
        }

        return documentTypes.compactMap { documentType in
            guard let displayName = documentType["CFBundleTypeName"] as? String,
                  let declaredContentTypes = documentType["LSItemContentTypes"] as? [String]
            else {
                return nil
            }

            let contentTypeIdentifiers = declaredContentTypes.filter { !excludedTypeIdentifiers.contains($0) }
            guard !contentTypeIdentifiers.isEmpty else {
                return nil
            }

            return IntegrationFileAssociation(displayName: displayName,
                                              handlerRank: documentType["LSHandlerRank"] as? String ?? "Alternate",
                                              contentTypeIdentifiers: contentTypeIdentifiers)
        }
    }

    static func integrationDocumentTypes(bundle: Bundle = .main) -> [IntegrationFileAssociation] {
        supportedDocumentTypes(bundle: bundle).filter(\.isDefaultRanked)
    }
}

enum IntegrationFileAssociationDisplayStatus {
    case noDefaultApp
    case defaultApp(String)
    case multipleDefaultApps
}

struct IntegrationFileAssociationState {
    let displayStatus: IntegrationFileAssociationDisplayStatus
    let isCurrentDefault: Bool
    let isPendingUpdate: Bool
}

actor IntegrationFileAssociationUpdateState {
    var remainingUpdates: Int
    var failureCount: Int = 0

    init(remainingUpdates: Int) {
        self.remainingUpdates = remainingUpdates
    }

    func recordCompletion(error: Error?) -> (isFinished: Bool, failureCount: Int) {
        if let error {
            let nsError = error as NSError
            if nsError.code != NSUserCancelledError {
                failureCount += 1
            }
        }

        remainingUpdates -= 1
        return (remainingUpdates == 0, failureCount)
    }
}

final class IntegrationStatusView: NSView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(displayStatus: IntegrationFileAssociationDisplayStatus) {
        switch displayStatus {
        case .noDefaultApp:
            label.stringValue = SZL10n.string("app.settings.noDefaultApp")
            label.textColor = .placeholderTextColor

        case let .defaultApp(displayName):
            label.stringValue = displayName
            label.textColor = .labelColor

        case .multipleDefaultApps:
            label.stringValue = SZL10n.string("app.settings.multipleDefaultApps")
            label.textColor = .secondaryLabelColor
        }
    }
}

final class IntegrationRowTableCellView: NSTableCellView {
    private let rowStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusView = IntegrationStatusView()
    let actionButton = NSButton(title: "", target: nil, action: nil)
    private var titleWidthConstraint: NSLayoutConstraint?
    private var statusWidthConstraint: NSLayoutConstraint?
    private var actionWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 12
        addSubview(rowStack)

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        rowStack.addArrangedSubview(titleLabel)

        statusView.setContentCompressionResistancePriority(.required, for: .horizontal)
        rowStack.addArrangedSubview(statusView)

        actionButton.bezelStyle = .rounded
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        rowStack.addArrangedSubview(actionButton)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureLayout(titleWidth: CGFloat,
                         statusWidth: CGFloat,
                         actionWidth: CGFloat)
    {
        if let titleWidthConstraint {
            titleWidthConstraint.constant = titleWidth
        } else {
            let constraint = titleLabel.widthAnchor.constraint(equalToConstant: titleWidth)
            constraint.isActive = true
            titleWidthConstraint = constraint
        }

        if let statusWidthConstraint {
            statusWidthConstraint.constant = statusWidth
        } else {
            let constraint = statusView.widthAnchor.constraint(equalToConstant: statusWidth)
            constraint.isActive = true
            statusWidthConstraint = constraint
        }

        if let actionWidthConstraint {
            actionWidthConstraint.constant = actionWidth
        } else {
            let constraint = actionButton.widthAnchor.constraint(equalToConstant: actionWidth)
            constraint.isActive = true
            actionWidthConstraint = constraint
        }
    }

    func apply(association: IntegrationFileAssociation,
               state: IntegrationFileAssociationState,
               target: AnyObject?,
               action: Selector)
    {
        titleLabel.stringValue = association.displayName
        statusView.apply(displayStatus: state.displayStatus)
        actionButton.title = state.isCurrentDefault
            ? SZL10n.string("app.settings.currentDefault")
            : SZL10n.string("app.settings.makeDefault")
        actionButton.isEnabled = !state.isCurrentDefault && !state.isPendingUpdate
        actionButton.identifier = NSUserInterfaceItemIdentifier(association.primaryTypeIdentifier)
        actionButton.setAccessibilityIdentifier("settings.makeDefault.\(association.primaryTypeIdentifier)")
        actionButton.target = target
        actionButton.action = action
    }
}
