import SwiftUI
import UIKit

extension View {
    func onTabScrollToTop(_ tab: Int) -> some View {
        modifier(OnTabScrollToTopModifier(tab: tab))
    }
}

private struct OnTabScrollToTopModifier: ViewModifier {
    let tab: Int
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content.background(
            TabScrollToTopBridge(token: appState.tabScrollToken(for: tab))
        )
    }
}

/// Scrolls the tab’s primary list when `token` increases. First attach only stores the token so switching tabs does not jump.
private struct TabScrollToTopBridge: UIViewRepresentable {
    let token: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.didSync else {
            context.coordinator.lastToken = token
            context.coordinator.didSync = true
            return
        }

        guard token > context.coordinator.lastToken else { return }
        context.coordinator.lastToken = token

        DispatchQueue.main.async {
            uiView.purseful_scrollPrimaryContentToTop()
        }
    }

    final class Coordinator {
        var lastToken = 0
        var didSync = false
    }
}

/// Same-tab reselect. Capture selection at touch-begin; UIKit may already have changed it by touch-end.
struct TabBarReselectObserver: UIViewRepresentable {
    var onReselect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselect: onReselect)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        context.coordinator.scheduleAttach(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onReselect = onReselect
        context.coordinator.scheduleAttach(from: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onReselect: (Int) -> Void
        private weak var tabBar: UITabBar?
        private var gesture: UITapGestureRecognizer?
        private var selectedIndexAtTouchBegin: Int?
        private var attachScheduled = false

        init(onReselect: @escaping (Int) -> Void) {
            self.onReselect = onReselect
        }

        func scheduleAttach(from view: UIView) {
            if tabBar != nil { return }
            guard !attachScheduled else { return }
            attachScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.attachScheduled = false
                self?.attach(from: view)
            }
        }

        func attach(from view: UIView) {
            guard tabBar == nil, let tabBar = findTabBar(from: view) else { return }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            tabBar.addGestureRecognizer(tap)

            self.tabBar = tabBar
            self.gesture = tap
        }

        private func findTabBar(from view: UIView) -> UITabBar? {
            var responder: UIResponder? = view
            while let current = responder {
                if let tab = current as? UITabBarController {
                    return tab.tabBar
                }
                if let vc = current as? UIViewController, let tab = vc.tabBarController {
                    return tab.tabBar
                }
                responder = current.next
            }
            return view.window?.rootViewController?.purseful_findTabBarController()?.tabBar
        }

        private func itemIndex(at location: CGPoint, in tabBar: UITabBar) -> Int? {
            guard let items = tabBar.items, !items.isEmpty else { return nil }
            let width = tabBar.bounds.width / CGFloat(items.count)
            guard width > 0 else { return nil }
            return min(max(Int(location.x / width), 0), items.count - 1)
        }

        private func currentSelectedIndex(in tabBar: UITabBar) -> Int? {
            guard let items = tabBar.items, let selected = tabBar.selectedItem else { return nil }
            return items.firstIndex(of: selected)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let tabBar else { return false }
            selectedIndexAtTouchBegin = currentSelectedIndex(in: tabBar)
            return true
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let tabBar,
                  let tappedIndex = itemIndex(at: gesture.location(in: tabBar), in: tabBar),
                  let beganIndex = selectedIndexAtTouchBegin,
                  tappedIndex == beganIndex
            else { return }

            onReselect(tappedIndex)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIView {
    func purseful_scrollPrimaryContentToTop() {
        guard let scrollView = purseful_primaryContentScrollView() else { return }

        // `scrollToItem` / `scrollToRow` pin the first cell and skip headers / search chrome.
        let top = CGPoint(
            x: -scrollView.adjustedContentInset.left,
            y: -scrollView.adjustedContentInset.top
        )
        scrollView.setContentOffset(top, animated: true)
    }

    func purseful_primaryContentScrollView() -> UIScrollView? {
        let root = purseful_hostingViewController()?.view ?? {
            var current: UIView? = self
            while let superview = current?.superview { current = superview }
            return current
        }()

        guard let root else { return nil }
        return root.purseful_largestVerticalScrollView()
    }

    func purseful_hostingViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController {
                return vc
            }
            responder = current.next
        }
        return nil
    }

    func purseful_largestVerticalScrollView() -> UIScrollView? {
        var best: UIScrollView?
        var bestArea: CGFloat = 0

        func visit(_ view: UIView) {
            if let scrollView = view as? UIScrollView, scrollView.purseful_isPrimaryContentScrollView {
                let area = scrollView.bounds.width * scrollView.bounds.height
                if area > bestArea {
                    best = scrollView
                    bestArea = area
                }
            }
            for subview in view.subviews {
                visit(subview)
            }
        }

        visit(self)
        return best
    }
}

private extension UIScrollView {
    var purseful_isPrimaryContentScrollView: Bool {
        guard !(self is UITextView) else { return false }
        guard bounds.height > 120 else { return false }
        // Exclude nested horizontal strips (account cards, goal chips).
        let vertical = contentSize.height > contentSize.width * 0.6 || contentSize.height > bounds.height
        let notClearlyHorizontal = contentSize.width <= bounds.width * 1.25 || contentSize.height > bounds.height
        return vertical && notClearlyHorizontal
    }
}

private extension UIViewController {
    func purseful_findTabBarController() -> UITabBarController? {
        if let tab = self as? UITabBarController { return tab }
        for child in children {
            if let tab = child.purseful_findTabBarController() { return tab }
        }
        return presentedViewController?.purseful_findTabBarController()
    }
}
