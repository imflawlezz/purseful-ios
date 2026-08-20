import SwiftUI

extension View {
    @ViewBuilder
    func pursefulGlass(
        in shape: some Shape,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(in: shape)
            }
        } else {
            self.background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.stroke(.white.opacity(0.18), lineWidth: 0.5)
                    }
            }
        }
    }
}
