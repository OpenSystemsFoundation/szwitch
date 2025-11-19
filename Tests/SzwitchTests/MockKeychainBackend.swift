import Foundation
@testable import SzwitchLib

final class MockKeychainBackend: KeychainBackend, @unchecked Sendable {
    // Use a lock to make the mock thread-safe, as tests might run in parallel or async
    private let lock = NSLock()
    private var genericItems: [String: Data] = [:]
    private var internetItems: [String: String] = [:]
    
    func save(service: String, account: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(service)|\(account)"
        genericItems[key] = data
    }
    
    func read(service: String, account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(service)|\(account)"
        return genericItems[key]
    }
    
    func delete(service: String, account: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(service)|\(account)"
        genericItems.removeValue(forKey: key)
    }
    
    func saveInternetPassword(server: String, account: String, password: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(server)|\(account)"
        internetItems[key] = password
    }
    
    func readInternetPassword(server: String, account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(server)|\(account)"
        return internetItems[key]
    }
    
    func deleteInternetPassword(server: String, account: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(server)|\(account)"
        internetItems.removeValue(forKey: key)
    }
}
