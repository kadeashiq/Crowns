import UIKit
import SwiftUI
import SwiftData

/// Principal class of the share extension (see CrownsShare-Info.plist).
final class ShareViewController: UIViewController {
    private var container: ModelContainer?
    private var model: AddWatchModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.uiCanvas

        let container = SharedStore.extensionContainer()
        self.container = container
        let model = AddWatchModel(context: container.mainContext, isExtension: true) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        self.model = model

        let hosting = UIHostingController(rootView: AddWatchSheet(model: model))
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { @MainActor in
            let input = await ShareInputReader.read(items)
            model.start(.share(input))
        }
    }

    /// A swipe is the only way out, and the system won't end the request for us.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        model?.cancel()
    }
}
