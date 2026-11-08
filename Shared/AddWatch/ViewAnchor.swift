import SwiftUI
import UIKit

/// Hands SwiftUI's underlying UIView to code that needs one, such as the
/// hidden web view that reads pasted links.
struct ViewAnchor: UIViewRepresentable {
    let onView: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        DispatchQueue.main.async { onView(view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
