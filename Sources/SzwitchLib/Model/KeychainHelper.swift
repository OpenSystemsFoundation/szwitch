import Foundation
import Security

public protocol KeychainBackend: Sendable {
    func save(service: String, account: String, data: Data) throws
    func read(service: String, account: String) -> Data?
    func delete(service: String, account: String)
    func saveInternetPassword(server: String, account: String, password: String) throws
    func readInternetPassword(server: String, account: String) -> String?
    func deleteInternetPassword(server: String, account: String)
}

public final class RealKeychainBackend: KeychainBackend {
    public init() {}
    
    public func save(service: String, account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
    
    public func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    public func saveInternetPassword(server: String, account: String, password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecAttrPort as String: 443,
            kSecValueData as String: passwordData
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func readInternetPassword(server: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    public func deleteInternetPassword(server: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

public final class KeychainHelper: Sendable {
    public static let shared = KeychainHelper()
    
    // Allow swapping backend for testing
    // Using a lock or actor would be better for thread safety if this changes at runtime often,
    // but for testing injection it's usually acceptable.
    // Since this is a singleton used from MainActor often, but defined as Sendable,
    // we should make this thread-safe or just UnsafeMutable for tests.
    // For simplicity in this context, we'll use a property that can be set.
    // To be strictly Sendable, we wrap it.
    
    private let backendContainer = BackendContainer()
    
    private final class BackendContainer: @unchecked Sendable {
        var backend: any KeychainBackend = RealKeychainBackend()
    }
    
    public var backend: any KeychainBackend {
        get { backendContainer.backend }
        set { backendContainer.backend = newValue }
    }
    
    private init() {}
    
    public func save(service: String, account: String, data: Data) throws {
        try backend.save(service: service, account: account, data: data)
    }
    
    public func read(service: String, account: String) -> Data? {
        return backend.read(service: service, account: account)
    }
    
    public func delete(service: String, account: String) {
        backend.delete(service: service, account: account)
    }
    
    public func saveInternetPassword(server: String, account: String, password: String) throws {
        try backend.saveInternetPassword(server: server, account: account, password: password)
    }
    
    public func readInternetPassword(server: String, account: String) -> String? {
        return backend.readInternetPassword(server: server, account: account)
    }
    
    public func deleteInternetPassword(server: String, account: String) {
        backend.deleteInternetPassword(server: server, account: account)
    }
}

public enum KeychainError: Error {
    case unhandledError(status: OSStatus)
    case invalidData
}
