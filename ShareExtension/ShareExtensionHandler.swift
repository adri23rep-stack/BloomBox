import SwiftUI
import UIKit

final class ShareExtensionHandler: UIViewController {
    private var jitStarted = false
    private func handleJIT(_ context: NSExtensionContext) -> Bool {
        if jitStarted { return true }
        jitStarted = StrataJITWorker.handle(context)
        return jitStarted
    }
    private let viewModel = ShareExtensionViewModel()
    private var host: UIHostingController<ShareExtensionRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let context = extensionContext, handleJIT(context) { return }
        let root = ShareExtensionRootView(viewModel: viewModel, extensionContext: extensionContext)
        let host = UIHostingController(rootView: root)
        self.host = host
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        viewModel.loadPayload(from: extensionContext)
    }

    override func beginRequest(with context: NSExtensionContext) {
        if handleJIT(context) { return }
        viewModel.loadPayload(from: context)
    }
}
