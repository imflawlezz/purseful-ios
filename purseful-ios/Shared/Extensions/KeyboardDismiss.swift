import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissInstaller())
    }
}

/// Installs a non-cancelling tap gesture on the parent view so taps outside text fields
/// dismiss the keyboard without stealing touches from buttons, pickers, or fields.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(on: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(on: uiView)
        }
    }

    final class Coordinator: NSObject {
        private weak var hostView: UIView?
        private var gesture: UITapGestureRecognizer?

        func installIfNeeded(on view: UIView) {
            guard let parent = view.superview?.superview ?? view.superview else { return }
            guard hostView !== parent else { return }

            if let gesture, let hostView {
                hostView.removeGestureRecognizer(gesture)
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            parent.addGestureRecognizer(tap)

            hostView = parent
            gesture = tap
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
