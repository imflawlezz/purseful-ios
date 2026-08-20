import Foundation

extension String {
    var localizedDisplayName: String {
        String(localized: String.LocalizationValue(self))
    }
}
