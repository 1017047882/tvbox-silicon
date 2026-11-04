#if os(iOS)
import SwiftUI
import UIKit

/// @brief Hosts SwiftUI carousel content before UIHostingConfiguration (iOS 16).
/// @note UIKit calls all lifecycle methods on the main actor; detach the child when off screen.
final class LegacyHostingCell: UICollectionViewCell {
    private var host: UIHostingController<AnyView>?
    func setContent<Content: View>(_ content: Content) {
        if let host { host.rootView = AnyView(content) }
        else {
            let controller = UIHostingController(rootView: AnyView(content))
            controller.view.backgroundColor = .clear
            controller.view.frame = contentView.bounds
            controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            contentView.addSubview(controller.view)
            host = controller
        }
        attach()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            host?.willMove(toParent: nil)
            host?.removeFromParent()
        } else { attach() }
    }
    private func attach() {
        guard window != nil, let host, host.parent == nil else { return }
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let parent = next as? UIViewController {
                parent.addChild(host)
                host.didMove(toParent: parent)
                return
            }
            responder = next
        }
    }
}
#endif
