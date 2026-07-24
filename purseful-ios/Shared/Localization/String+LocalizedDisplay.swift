import Foundation

extension String {
    /// Localizes catalog keys; unknown strings pass through.
    var localizedDisplayName: String {
        String(localized: String.LocalizationValue(self))
    }
}
