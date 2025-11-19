import XCTest
@testable import SzwitchLib

@MainActor
final class OAuthManagerTests: XCTestCase {
    
    var oauthManager: OAuthManager!
    
    override func setUp() async throws {
        oauthManager = OAuthManager()
    }
    
    override func tearDown() async throws {
        oauthManager = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertEqual(oauthManager.state, .idle)
        XCTAssertNil(oauthManager.userCode)
        XCTAssertNil(oauthManager.verificationUri)
        XCTAssertTrue(oauthManager.clientId.isEmpty)
    }
    
    func testClientIdPersistence() {
        // Given
        let testClientId = "Iv1.test123456"
        
        // When
        oauthManager.clientId = testClientId
        
        // Create new instance
        let newManager = OAuthManager()
        
        // Then
        XCTAssertEqual(newManager.clientId, testClientId)
        
        // Cleanup
        oauthManager.clientId = ""
    }
    
    func testStateTransitions() {
        // Given - initial state is idle
        XCTAssertEqual(oauthManager.state, .idle)
        
        // When - manually set to waiting (simulating device flow start)
        oauthManager.state = .waitingForAuth
        
        // Then
        XCTAssertEqual(oauthManager.state, .waitingForAuth)
        
        // When - set to authenticated
        oauthManager.state = .authenticated("test_token")
        
        // Then
        if case .authenticated(let token) = oauthManager.state {
            XCTAssertEqual(token, "test_token")
        } else {
            XCTFail("State should be authenticated")
        }
    }
    
    func testErrorState() {
        // Given
        let errorMessage = "Test error message"
        
        // When
        oauthManager.state = .error(errorMessage)
        
        // Then
        if case .error(let message) = oauthManager.state {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("State should be error")
        }
    }
    
    func testDeviceFlowWithoutClientId() async {
        // Given - no client ID set
        oauthManager.clientId = ""
        
        // When
        await oauthManager.startDeviceFlow()
        
        // Then - should be in error state
        if case .error(let message) = oauthManager.state {
            XCTAssertTrue(message.contains("Client ID"))
        } else {
            XCTFail("Should be in error state when client ID is missing")
        }
    }
}
