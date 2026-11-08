import UIKit
import SwiftUI

/// Principal class of the share extension (see CrownsShare-Info.plist).
final class ShareViewController: UIViewController {
    private var model: ShareModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel(
            finish: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            cancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        )
        self.model = model

        let hosting = UIHostingController(rootView: ShareSheetView(model: model))
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let hostView: UIView = view
        Task { @MainActor in
            let input = await ShareInputReader.read(items)
            await model.start(input: input, host: hostView)
        }
    }
}
