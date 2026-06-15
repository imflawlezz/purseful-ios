import Foundation
import SwiftData

@Model
final class BankConnection {
    var id: UUID = UUID()
    var institutionId: String = ""
    var institutionName: String = ""
    var consentExpiry: Date?
    var lastSyncedAt: Date?
    var statusRaw: String = BankConnectionStatus.error.rawValue
    var keychainTokenKey: String = ""

    @Relationship(deleteRule: .nullify)
    var linkedAccounts: [Account]?

    var status: BankConnectionStatus {
        get { BankConnectionStatus(rawValue: statusRaw) ?? .error }
        set { statusRaw = newValue.rawValue }
    }

    init(
        institutionId: String,
        institutionName: String,
        keychainTokenKey: String,
        status: BankConnectionStatus = .error
    ) {
        self.id = UUID()
        self.institutionId = institutionId
        self.institutionName = institutionName
        self.keychainTokenKey = keychainTokenKey
        self.statusRaw = status.rawValue
    }
}
