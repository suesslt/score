import XCTest
@testable import ScoreKeychain

/// Roundtrip-Tests gegen den echten Schlüsselbund. `swift test` läuft als unsignierter
/// Prozess ohne Application Identifier — der Data-Protection-Schlüsselbund verweigert
/// dort mit `errSecMissingEntitlement` (-34018). Die Tests nutzen deshalb den
/// dateibasierten Schlüsselbund (`useDataProtectionKeychain: false`); ist auch der
/// nicht erreichbar (Sandbox/CI), werden sie übersprungen statt zu scheitern.
final class KeychainSecretStoreTests: XCTestCase {

    private let service = "ch.scoreware.ScoreKeychainTests"
    private let key = "test-secret"

    private func makeStore() -> KeychainSecretStore {
        KeychainSecretStore(service: service, useDataProtectionKeychain: false)
    }

    /// Prüft die Erreichbarkeit des Schlüsselbunds; wirft `XCTSkip`, wenn die
    /// Umgebung keinen Zugriff erlaubt.
    private func requireKeychain(_ store: KeychainSecretStore) async throws {
        do {
            try await store.setSecret("probe", for: key)
        } catch {
            throw XCTSkip("Schlüsselbund in dieser Umgebung nicht erreichbar: \(error)")
        }
    }

    override func tearDown() async throws {
        try? await makeStore().setSecret(nil, for: key)
    }

    func testRoundTrip() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret("s3cret-🍫", for: key)
        let read = try await store.secret(for: key)
        XCTAssertEqual(read, "s3cret-🍫")
    }

    func testOverwriteUpdatesExistingEntry() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret("first", for: key)
        try await store.setSecret("second", for: key)
        let read = try await store.secret(for: key)
        XCTAssertEqual(read, "second")
    }

    func testNilDeletesEntry() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret("to-be-deleted", for: key)
        try await store.setSecret(nil, for: key)
        let read = try await store.secret(for: key)
        XCTAssertNil(read)
    }

    func testEmptyStringDeletesEntry() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret("to-be-deleted", for: key)
        try await store.setSecret("", for: key)
        let read = try await store.secret(for: key)
        XCTAssertNil(read)
    }

    func testMissingEntryReadsAsNil() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret(nil, for: key)
        let read = try await store.secret(for: key)
        XCTAssertNil(read)
    }

    func testDeleteMissingEntryDoesNotThrow() async throws {
        let store = makeStore()
        try await requireKeychain(store)

        try await store.setSecret(nil, for: key)
        try await store.setSecret(nil, for: key)   // zweites Löschen: errSecItemNotFound ist kein Fehler
    }
}
