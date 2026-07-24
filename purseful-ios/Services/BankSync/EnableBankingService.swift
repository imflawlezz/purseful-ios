import AuthenticationServices
import Foundation
import UIKit

final class EnableBankingService: NSObject, BankSyncService, ASWebAuthenticationPresentationContextProviding {
    static let shared = EnableBankingService()

    private let redirectURI = "purseful://bank-oauth"
    private let baseURL = "" // Set when bank sync access is granted

    var isEnabled: Bool {
        AppSettings.shared.bankSyncBetaEnabled && !baseURL.isEmpty
    }

    func connect(institutionId: String) async throws -> String {
        guard isEnabled, let authURL = URL(string: "\(baseURL)/auth?institution=\(institutionId)") else {
            throw BankSyncError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConstants.urlScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token = callbackURL?.absoluteString else {
                    continuation.resume(throwing: BankSyncError.authFailed)
                    return
                }
                continuation.resume(returning: token)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    func fetchTransactions(connectionId: String, since: Date?) async throws -> [RawBankTransaction] {
        guard isEnabled else { throw BankSyncError.notAvailable }
        return []
    }

    func disconnect(connectionId: String) async throws {
        guard isEnabled else { throw BankSyncError.notAvailable }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            fatalError("Can’t open bank login right now.")
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}

enum BankSyncError: LocalizedError {
    case notAvailable
    case authFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable: String(localized: "Bank sync isn’t ready yet.")
        case .authFailed: String(localized: "Couldn’t sign in to your bank.")
        }
    }
}
