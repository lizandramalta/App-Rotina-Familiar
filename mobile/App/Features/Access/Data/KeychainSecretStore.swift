import Foundation
import Security

enum KeychainSecretStoreError: Error {
    case unexpectedStatus(OSStatus)
    case invalidValue
}

protocol SecretStoring: Sendable {
    func read(key: String) throws -> String?
    func save(_ value: String, key: String) throws
    func remove(key: String) throws
}

final class KeychainSecretStore: SecretStoring, @unchecked Sendable {
    private let service = "com.lizandramalta.familyroutine.access"

    func read(key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
        return value
    }

    func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainSecretStoreError.unexpectedStatus(addStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
    }

    func remove(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
    }
}

struct KeychainSessionCredentialStore: SessionCredentialStoring {
    private let secrets: any SecretStoring
    private let refreshTokenKey = "refresh-token"

    init(secrets: any SecretStoring) {
        self.secrets = secrets
    }

    func refreshToken() throws -> String? {
        try secrets.read(key: refreshTokenKey)
    }

    func save(refreshToken: String) throws {
        try secrets.save(refreshToken, key: refreshTokenKey)
    }

    func clear() throws {
        try secrets.remove(key: refreshTokenKey)
    }
}

struct KeychainInstallationProofStore: InstallationProofProviding {
    private let secrets: any SecretStoring
    private let installationProofKey = "installation-proof"

    init(secrets: any SecretStoring) {
        self.secrets = secrets
    }

    func installationProof() throws -> String {
        if let proof = try secrets.read(key: installationProofKey) {
            return proof
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw KeychainSecretStoreError.invalidValue
        }
        let proof = Data(bytes).base64EncodedString()
        try secrets.save(proof, key: installationProofKey)
        return proof
    }
}

struct KeychainInviteJoinAttemptStore: InviteJoinAttemptStoring {
    private let secrets: any SecretStoring
    private let attemptKey = "pending-invite-join"

    init(secrets: any SecretStoring) {
        self.secrets = secrets
    }

    func pendingAttempt() throws -> InviteJoinAttempt? {
        guard let value = try secrets.read(key: attemptKey),
              let data = value.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(InviteJoinAttempt.self, from: data)
    }

    func save(_ attempt: InviteJoinAttempt) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(attempt)
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainSecretStoreError.invalidValue
        }
        try secrets.save(value, key: attemptKey)
    }

    func clear() throws {
        try secrets.remove(key: attemptKey)
    }
}
