import Foundation
import Security
import os

/// Geheimnisse (API-Tokens, Schlüssel) im Schlüsselbund — die geteilte Basis für alle
/// Scoreware-Apps, die ein Secret sicher ablegen müssen.
///
/// Herkunft: Moneypennys `KeychainSecretStore` (Befund `SEC-NEU-01`: ein API-Token stand
/// als Klartext-Feld in `UserDefaults` — eine Datei, die jedes Time-Machine-Backup
/// mitnimmt und jeder Prozess mit Container-Zugriff lesen kann).
///
/// Ein `actor`: Der Schlüsselbund ist zwar selbst threadsicher, aber die Abfolge
/// «lesen, entscheiden, schreiben» in ``setSecret(_:for:)`` ist es nicht — zwei
/// gleichzeitige Aufrufe könnten sich sonst überholen.
///
/// Zugriffsklasse `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: **nicht** in ein
/// iCloud-Schlüsselbund-Backup und nicht auf ein anderes Gerät — ein Secret gehört zu
/// dieser Installation.
public actor KeychainSecretStore {
    private let service: String
    private let logger: Logger

    /// Fehler des Schlüsselbund-Zugriffs. Der `OSStatus` ist auswertbar; das Geheimnis
    /// selbst taucht nie in einer Meldung auf. Konsumenten bilden den Fehler an ihrer
    /// Grenze auf ihren `DomainError` ab (z.B. `.storage(message: "keychain.read.\(status)")`).
    public enum KeychainError: Error, Sendable, Equatable {
        case read(OSStatus)
        case update(OSStatus)
        case add(OSStatus)
        case delete(OSStatus)
    }

    /// - Parameters:
    ///   - service: `kSecAttrService` — üblicherweise die Bundle-ID der App.
    ///   - useDataProtectionKeychain: Vorgabe `true`. **Der entscheidende Schalter auf
    ///     macOS:** Ohne ihn landet der Eintrag im dateibasierten Schlüsselbund, dessen
    ///     ACL an der Code-Signatur hängt — die bei jedem Entwicklungs-Build wechselt;
    ///     der nächste Build liest dann `errSecAuthFailed` (-25293). Der
    ///     Data-Protection-Schlüsselbund bindet den Zugriff an die App-Identität
    ///     (`keychain-access-groups`) und kennt keine Freigabedialoge. `false` nur für
    ///     unsignierte Prozesse ohne Application Identifier (z.B. `swift test`).
    public init(service: String, useDataProtectionKeychain: Bool = true) {
        self.service = service
        self.useDataProtectionKeychain = useDataProtectionKeychain
        self.logger = Logger(subsystem: service, category: "ScoreKeychain")
    }

    private let useDataProtectionKeychain: Bool

    public func secret(for key: String) async throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            return text
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Schlüsselbund-Lesefehler: \(status, privacy: .public)")
            throw KeychainError.read(status)
        }
    }

    /// `nil` oder ein leerer Wert löscht den Eintrag.
    public func setSecret(_ value: String?, for key: String) async throws {
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                logger.error("Schlüsselbund-Löschfehler: \(status, privacy: .public)")
                throw KeychainError.delete(status)
            }
            return
        }

        let data = Data(value.utf8)
        let query = baseQuery(for: key)

        // Erst aktualisieren, dann anlegen: `SecItemAdd` auf einen bestehenden
        // Eintrag scheitert mit `errSecDuplicateItem`.
        let update = [kSecValueData as String: data] as CFDictionary
        let updateStatus = SecItemUpdate(query as CFDictionary, update)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            logger.error("Schlüsselbund-Schreibfehler: \(updateStatus, privacy: .public)")
            throw KeychainError.update(updateStatus)
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Schlüsselbund-Anlegefehler: \(addStatus, privacy: .public)")
            throw KeychainError.add(addStatus)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}
