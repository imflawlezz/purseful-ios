import SwiftUI
import UIKit

@MainActor
enum AccentTheme {
    static let backgroundOpacity = 0.12
    static let surfaceOpacity: CGFloat = 0.10

    nonisolated(unsafe) static var currentSurfaceUIColor: UIColor = .secondarySystemGroupedBackground

    static let headerClearTag = 0xA11C11

    static func backgroundWash(_ accent: Color) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
            accent.opacity(backgroundOpacity)
        }
    }

    static func surfaceWash(_ accent: Color) -> some View {
        Color(uiColor: blendedSurfaceUIColor(accent: accent))
    }

    static func blendedSurfaceUIColor(accent: Color) -> UIColor {
        let accentUIColor = UIColor(accent)
        return UIColor { traits in
            let base = UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits)
            let tint = accentUIColor.resolvedColor(with: traits)
            return blend(base: base, accent: tint, amount: surfaceOpacity)
        }
    }

    static func prepareListChrome(accent: Color) {
        currentSurfaceUIColor = blendedSurfaceUIColor(accent: accent)

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        var cellConfig = UIBackgroundConfiguration.listCell()
        cellConfig.backgroundColor = currentSurfaceUIColor
        UICollectionViewListCell.appearance().backgroundConfiguration = cellConfig
        UITableViewCell.appearance().backgroundColor = currentSurfaceUIColor
        UITableViewCell.appearance().backgroundConfiguration?.backgroundColor = currentSurfaceUIColor

        var clearHeader = UIBackgroundConfiguration.clear()
        clearHeader.backgroundColor = .clear
        UITableViewHeaderFooterView.appearance().backgroundConfiguration = clearHeader
        UITableViewHeaderFooterView.appearance().backgroundColor = .clear
        UITableViewHeaderFooterView.appearance().tintColor = .clear
    }

    static func retintAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                retintVisibleSurfaces(from: window)
            }
        }
    }

    static func retintVisibleSurfaces(from root: UIView) {
        let surface = currentSurfaceUIColor
        func walk(_ view: UIView) {
            if view is UITableViewHeaderFooterView {
                return
            }
            if let cell = view as? UICollectionViewListCell {
                if cell.tag == headerClearTag {
                    cell.backgroundConfiguration = .clear()
                    return
                }
                var config = UIBackgroundConfiguration.listCell()
                config.backgroundColor = surface
                cell.backgroundConfiguration = config
            } else if let cell = view as? UITableViewCell {
                if cell.tag == headerClearTag {
                    cell.backgroundColor = .clear
                    cell.backgroundConfiguration = .clear()
                    return
                }
                cell.backgroundColor = surface
                if var config = cell.backgroundConfiguration {
                    config.backgroundColor = surface
                    cell.backgroundConfiguration = config
                }
            }
            view.subviews.forEach(walk)
        }
        walk(root)
    }

    private static func blend(base: UIColor, accent: UIColor, amount: CGFloat) -> UIColor {
        let baseRGB = rgba(base)
        let accentRGB = rgba(accent)
        return UIColor(
            red: baseRGB.r + (accentRGB.r - baseRGB.r) * amount,
            green: baseRGB.g + (accentRGB.g - baseRGB.g) * amount,
            blue: baseRGB.b + (accentRGB.b - baseRGB.b) * amount,
            alpha: 1
        )
    }

    private static func rgba(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &a) {
            return (white, white, white, a)
        }
        let converted = color.cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        let comps = converted?.components ?? [0, 0, 0, 1]
        if comps.count >= 3 {
            return (comps[0], comps[1], comps[2], comps.count > 3 ? comps[3] : 1)
        }
        return (0, 0, 0, 1)
    }
}

struct AccentScreenBackground: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        AccentTheme.backgroundWash(settings.accentColor)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear { AccentTheme.prepareListChrome(accent: settings.accentColor) }
            .onChange(of: settings.accentColorHex) { _, _ in
                AccentTheme.prepareListChrome(accent: settings.accentColor)
                AccentTheme.retintAllWindows()
            }
    }
}

struct AccentSurfaceBackground: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        AccentTheme.surfaceWash(settings.accentColor)
    }
}

private struct AccentSurfaceInstaller: UIViewRepresentable {
    @Bindable private var settings = AppSettings.shared

    func makeUIView(context: Context) -> AccentSurfaceLayoutView {
        let view = AccentSurfaceLayoutView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AccentSurfaceLayoutView, context: Context) {
        AccentTheme.prepareListChrome(accent: settings.accentColor)
        uiView.retintIfNeeded()
    }
}

private final class AccentSurfaceLayoutView: UIView {
    private var scheduled = false
    private var lastRetint: CFTimeInterval = 0

    override func didMoveToWindow() {
        super.didMoveToWindow()
        retintIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        retintIfNeeded()
    }

    func retintIfNeeded() {
        guard window != nil, !scheduled else { return }
        let now = CACurrentMediaTime()
        // Setting backgroundConfiguration retriggers layout; throttle avoids a feedback loop.
        guard now - lastRetint > 0.08 else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                self?.scheduled = false
                return
            }
            self.lastRetint = CACurrentMediaTime()
            self.scheduled = false
            AccentTheme.retintVisibleSurfaces(from: window)
        }
    }
}

struct AccentListSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.localizedDisplayName)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clearListSupplementaryBackground()
    }
}

struct AccentListSectionFooter: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clearListSupplementaryBackground()
    }
}

private struct ClearListSupplementaryBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.clearHeaderChrome(startingAt: uiView)
            DispatchQueue.main.async {
                Self.clearHeaderChrome(startingAt: uiView)
            }
        }
    }

    private static func clearHeaderChrome(startingAt view: UIView) {
        var node: UIView? = view
        for _ in 0..<10 {
            guard let current = node else { return }
            current.backgroundColor = .clear

            if let cell = current as? UICollectionViewListCell {
                cell.tag = AccentTheme.headerClearTag
                cell.backgroundConfiguration = .clear()
                for subview in cell.subviews where String(describing: type(of: subview)).contains("Background") {
                    subview.isHidden = true
                    subview.backgroundColor = .clear
                    subview.alpha = 0
                }
                return
            }

            if let header = current as? UITableViewHeaderFooterView {
                header.tag = AccentTheme.headerClearTag
                header.backgroundConfiguration = .clear()
                header.backgroundColor = .clear
                header.tintColor = .clear
                header.backgroundView = UIView()
                header.backgroundView?.backgroundColor = .clear
                return
            }

            node = current.superview
        }
    }
}

private struct AccentTintedBackgroundModifier: ViewModifier {
    @Bindable private var settings = AppSettings.shared

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = content
            .scrollContentBackground(.hidden)
            .background { AccentScreenBackground() }
            .background { AccentSurfaceInstaller() }
            .presentationBackground {
                AccentScreenBackground()
            }
            .onAppear {
                AccentTheme.prepareListChrome(accent: settings.accentColor)
                DispatchQueue.main.async {
                    AccentTheme.retintAllWindows()
                    DispatchQueue.main.async {
                        AccentTheme.retintAllWindows()
                    }
                }
            }

        if #available(iOS 26.0, *) {
            base.containerBackground(for: .navigation) {
                AccentScreenBackground()
            }
        } else {
            base
        }
    }
}

extension View {
    func accentTintedBackground() -> some View {
        modifier(AccentTintedBackgroundModifier())
    }

    func accentListRows() -> some View {
        listRowBackground(AccentSurfaceBackground())
    }

    func clearListSectionHeaderBackground() -> some View {
        clearListSupplementaryBackground()
    }

    func clearListSupplementaryBackground() -> some View {
        background(ClearListSupplementaryBackground())
    }

    func accentSheet(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .accentTintedBackground()
        }
    }

    func accentSheet<Item: Identifiable>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { value in
            content(value)
                .accentTintedBackground()
        }
    }
}
