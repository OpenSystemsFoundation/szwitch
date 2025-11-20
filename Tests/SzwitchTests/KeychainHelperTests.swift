import XCTest
@testable import SzwitchLib



final class KeychainHelperTests: XCTestCase {
    
    let keychainHelper = KeychainHelper.shared
    let testService = "com.test.szwitch"
    let testAccount = "test-account"
    
    override func setUp() {
        super.setUp()
        // Inject mock backend
        keychainHelper.backend = MockKeychainBackend()
    }
    
    override func tearDown() {
        // Clean up any test data (though mock is recreated each time effectively if we wanted, but here we just clear)
        // Actually, since backend is replaced in setUp, we don't strictly need to clear, 
        // but it's good practice if we were reusing the mock.
        // Reset to real backend or just leave it? 
        // Ideally we should reset it to avoid side effects if other tests ran in same process,
        // but for unit tests usually it's fine.
        // Let's just leave it for now as we replace it in setUp.
        super.tearDown()
    }
    
    func testSaveAndReadData() throws {
        // Given
        let testData = "test-token-12345".data(using: .utf8)!
        
        // When
        try keychainHelper.save(service: testService, account: testAccount, data: testData)
        let retrievedData = keychainHelper.read(service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData, testData)
        
        let retrievedString = String(data: retrievedData!, encoding: .utf8)
        XCTAssertEqual(retrievedString, "test-token-12345")
    }
    
    func testUpdateExistingData() throws {
        // Given
        let originalData = "original-token".data(using: .utf8)!
        let updatedData = "updated-token".data(using: .utf8)!
        
        // When
        try keychainHelper.save(service: testService, account: testAccount, data: originalData)
        try keychainHelper.save(service: testService, account: testAccount, data: updatedData)
        let retrievedData = keychainHelper.read(service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(retrievedData)
        let retrievedString = String(data: retrievedData!, encoding: .utf8)
        XCTAssertEqual(retrievedString, "updated-token")
    }
    
    func testDeleteData() throws {
        // Given
        let testData = "delete-me".data(using: .utf8)!
        try keychainHelper.save(service: testService, account: testAccount, data: testData)
        
        // When
        keychainHelper.delete(service: testService, account: testAccount)
        let retrievedData = keychainHelper.read(service: testService, account: testAccount)
        
        // Then
        XCTAssertNil(retrievedData)
    }
    
    func testReadNonExistentData() {
        // When
        let retrievedData = keychainHelper.read(service: "non-existent-service", account: "non-existent-account")
        
        // Then
        XCTAssertNil(retrievedData)
    }
    
    func testDeleteNonExistentData() {
        // When/Then - should not throw
        keychainHelper.delete(service: "non-existent-service", account: "non-existent-account")
    }
    
    func testMultipleAccounts() throws {
        // Given
        let account1 = "account1"
        let account2 = "account2"
        let data1 = "token1".data(using: .utf8)!
        let data2 = "token2".data(using: .utf8)!
        
        // When
        try keychainHelper.save(service: testService, account: account1, data: data1)
        try keychainHelper.save(service: testService, account: account2, data: data2)
        
        let retrieved1 = keychainHelper.read(service: testService, account: account1)
        let retrieved2 = keychainHelper.read(service: testService, account: account2)
        
        // Then
        XCTAssertEqual(String(data: retrieved1!, encoding: .utf8), "token1")
        XCTAssertEqual(String(data: retrieved2!, encoding: .utf8), "token2")
        
        // Cleanup
        keychainHelper.delete(service: testService, account: account1)
        keychainHelper.delete(service: testService, account: account2)
    }
    
    // MARK: - Internet Password Tests
    
    func testSaveAndReadInternetPassword() throws {
        // Given
        let server = "github.com"
        let account = "testuser"
        let password = "ghp_testtoken123"
        
        // When
        try keychainHelper.saveInternetPassword(server: server, account: account, password: password)
        let retrieved = keychainHelper.readInternetPassword(server: server, account: account)
        
        // Then
        XCTAssertEqual(retrieved, password)
        
        // Cleanup
        keychainHelper.deleteInternetPassword(server: server, account: account)
    }
    
    func testReadNonexistentInternetPassword() {
        // Given
        let server = "github.com"
        let account = "nonexistent"
        
        // When
        let retrieved = keychainHelper.readInternetPassword(server: server, account: account)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testUpdateInternetPassword() throws {
        // Given
        let server = "github.com"
        let account = "testuser"
        let oldPassword = "ghp_oldtoken"
        let newPassword = "ghp_newtoken"
        
        // When
        try keychainHelper.saveInternetPassword(server: server, account: account, password: oldPassword)
        try keychainHelper.saveInternetPassword(server: server, account: account, password: newPassword)
        let retrieved = keychainHelper.readInternetPassword(server: server, account: account)
        
        // Then
        XCTAssertEqual(retrieved, newPassword)
        
        // Cleanup
        keychainHelper.deleteInternetPassword(server: server, account: account)
    }
    
    func testDeleteInternetPassword() throws {
        // Given
        let server = "github.com"
        let account = "testuser"
        let password = "ghp_testtoken"
        
        try keychainHelper.saveInternetPassword(server: server, account: account, password: password)
        
        // When
        keychainHelper.deleteInternetPassword(server: server, account: account)
        let retrieved = keychainHelper.readInternetPassword(server: server, account: account)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testInternetPasswordIsolation() throws {
        // Given - two different accounts
        let server = "github.com"
        let account1 = "user1"
        let account2 = "user2"
        let password1 = "ghp_token1"
        let password2 = "ghp_token2"
        
        // When
        try keychainHelper.saveInternetPassword(server: server, account: account1, password: password1)
        try keychainHelper.saveInternetPassword(server: server, account: account2, password: password2)
        
        // Then - each account should have its own password
        XCTAssertEqual(keychainHelper.readInternetPassword(server: server, account: account1), password1)
        XCTAssertEqual(keychainHelper.readInternetPassword(server: server, account: account2), password2)
        
        // Cleanup
        keychainHelper.deleteInternetPassword(server: server, account: account1)
        keychainHelper.deleteInternetPassword(server: server, account: account2)
    }
}
