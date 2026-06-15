import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var baseCurrency: String {
        didSet { UserDefaults.standard.set(baseCurrency, forKey: AppConstants.baseCurrencyKey) }
    }

    var weeklySummaryEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklySummaryEnabled, forKey: AppConstants.weeklySummaryEnabledKey) }
    }

    var bankSyncBetaEnabled: Bool {
        didSet { UserDefaults.standard.set(bankSyncBetaEnabled, forKey: AppConstants.bankSyncBetaEnabledKey) }
    }

    var defaultAccountID: UUID? {
        didSet {
            if let defaultAccountID {
                UserDefaults.standard.set(defaultAccountID.uuidString, forKey: AppConstants.defaultAccountIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AppConstants.defaultAccountIDKey)
            }
        }
    }

    var dailySpendCategoryIDs: Set<UUID> {
        didSet {
            UserDefaults.standard.set(
                dailySpendCategoryIDs.map(\.uuidString),
                forKey: AppConstants.dailySpendCategoryIDsKey
            )
        }
    }

    var dailySpendLookbackDays: Int {
        didSet {
            UserDefaults.standard.set(dailySpendLookbackDays, forKey: AppConstants.dailySpendLookbackDaysKey)
        }
    }

    var accentColorHex: String {
        didSet { UserDefaults.standard.set(accentColorHex, forKey: AppConstants.accentColorHexKey) }
    }

    var accentColor: Color {
        Color(hex: accentColorHex)
    }

    func defaultAccount(from accounts: [Account]) -> Account? {
        guard let defaultAccountID else { return nil }
        return accounts.first { $0.id == defaultAccountID && !$0.isHidden }
    }

    private init() {
        baseCurrency = UserDefaults.standard.string(forKey: AppConstants.baseCurrencyKey) ?? AppConstants.defaultBaseCurrency
        weeklySummaryEnabled = UserDefaults.standard.bool(forKey: AppConstants.weeklySummaryEnabledKey)
        bankSyncBetaEnabled = UserDefaults.standard.bool(forKey: AppConstants.bankSyncBetaEnabledKey)
        if let idString = UserDefaults.standard.string(forKey: AppConstants.defaultAccountIDKey),
           let id = UUID(uuidString: idString) {
            defaultAccountID = id
        } else {
            defaultAccountID = nil
        }

        if let storedIDs = UserDefaults.standard.stringArray(forKey: AppConstants.dailySpendCategoryIDsKey) {
            dailySpendCategoryIDs = Set(storedIDs.compactMap(UUID.init(uuidString:)))
        } else {
            dailySpendCategoryIDs = []
        }

        let storedLookback = UserDefaults.standard.integer(forKey: AppConstants.dailySpendLookbackDaysKey)
        dailySpendLookbackDays = storedLookback > 0 ? storedLookback : DailySpendLookback.thirtyDays.rawValue
        accentColorHex = UserDefaults.standard.string(forKey: AppConstants.accentColorHexKey)
            ?? AppConstants.defaultAccentColorHex
    }
}
