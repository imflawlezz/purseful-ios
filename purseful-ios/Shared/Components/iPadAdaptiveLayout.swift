import SwiftUI

struct iPadSplitContainer<Sidebar: View, Detail: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                sidebar()
            } detail: {
                detail()
            }
        } else {
            detail()
        }
    }
}

struct KeyboardShortcutsModifier: ViewModifier {
    let onNewTransaction: () -> Void

    func body(content: Content) -> some View {
        content
            .keyboardShortcut("n", modifiers: .command)
            .onKeyPress(keys: [.init("n")], phases: .down) { press in
                if press.modifiers.contains(.command) {
                    onNewTransaction()
                    return .handled
                }
                return .ignored
            }
    }
}

extension View {
    func pursefulKeyboardShortcuts(onNewTransaction: @escaping () -> Void) -> some View {
        modifier(KeyboardShortcutsModifier(onNewTransaction: onNewTransaction))
    }
}
