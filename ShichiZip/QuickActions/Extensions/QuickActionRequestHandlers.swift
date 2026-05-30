import Foundation

public class ShichiZipQuickActionRequestHandler: NSObject, NSExtensionRequestHandling {
    class var requestPolicy: ShichiZipQuickActionRequestPolicy {
        fatalError("Override requestPolicy in subclasses.")
    }

    public func beginRequest(with context: NSExtensionContext) {
        performSelector(onMainThread: #selector(beginRequestOnMainThread(_:)),
                        with: context,
                        waitUntilDone: false)
    }

    @MainActor
    @objc private func beginRequestOnMainThread(_ context: NSExtensionContext) {
        let policy = Self.requestPolicy
        ShichiZipQuickActionLogger(action: policy.action)
            .log("beginRequest inputItems=\(context.inputItems.count)")

        Task {
            await ShichiZipQuickActionRequestPipeline(policy: policy).handle(context)
        }
    }
}

@objc(ShowInFileManagerQuickActionHandler)
public final class ShowInFileManagerQuickActionHandler: ShichiZipQuickActionRequestHandler {
    override class var requestPolicy: ShichiZipQuickActionRequestPolicy {
        .showInFileManager
    }
}

@objc(OpenInShichiZipQuickActionHandler)
public final class OpenInShichiZipQuickActionHandler: ShichiZipQuickActionRequestHandler {
    override class var requestPolicy: ShichiZipQuickActionRequestPolicy {
        .openInShichiZip
    }
}

@objc(SmartQuickExtractQuickActionHandler)
public final class SmartQuickExtractQuickActionHandler: ShichiZipQuickActionRequestHandler {
    override class var requestPolicy: ShichiZipQuickActionRequestPolicy {
        .smartQuickExtract
    }
}
