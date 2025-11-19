import XCTest
@testable import SzwitchLib

final class GitProfileTests: XCTestCase {
    
    func testGitProfileCreation() {
        // Given
        let name = "John Doe"
        let email = "john@example.com"
        let token = "ghp_test123"
        
        // When
        let profile = GitProfile(name: name, email: email, token: token)
        
        // Then
        XCTAssertEqual(profile.name, name)
        XCTAssertEqual(profile.email, email)
        XCTAssertEqual(profile.token, token)
        XCTAssertNotNil(profile.id)
    }
    
    func testGitProfileEncoding() throws {
        // Given
        let profile = GitProfile(
            name: "Jane Smith",
            email: "jane@example.com",
            token: "ghp_test456"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        // Then
        XCTAssertFalse(data.isEmpty)
        
        // Verify we can decode it back
        let decoder = JSONDecoder()
        let decodedProfile = try decoder.decode(GitProfile.self, from: data)
        
        XCTAssertEqual(decodedProfile.id, profile.id)
        XCTAssertEqual(decodedProfile.name, profile.name)
        XCTAssertEqual(decodedProfile.email, profile.email)
        XCTAssertEqual(decodedProfile.token, profile.token)
    }
    
    func testGitProfileDecoding() throws {
        // Given
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Test User",
            "email": "test@example.com",
            "token": "ghp_test789"
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let profile = try decoder.decode(GitProfile.self, from: data)
        
        // Then
        XCTAssertEqual(profile.name, "Test User")
        XCTAssertEqual(profile.email, "test@example.com")
        XCTAssertEqual(profile.token, "ghp_test789")
        XCTAssertEqual(profile.id.uuidString.uppercased(), "123E4567-E89B-12D3-A456-426614174000")
    }
    
    func testGitProfileIdentifiable() {
        // Given
        let profile1 = GitProfile(name: "User 1", email: "user1@example.com", token: "token1")
        let profile2 = GitProfile(name: "User 2", email: "user2@example.com", token: "token2")
        
        // Then
        XCTAssertNotEqual(profile1.id, profile2.id)
    }
}
