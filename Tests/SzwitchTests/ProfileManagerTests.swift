import XCTest

@testable import SzwitchLib

@MainActor
final class ProfileManagerTests: XCTestCase {

    var profileManager: ProfileManager!
    var mockGitService: MockGitService!
    var mockUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use mock keychain to avoid hitting real keychain and ensure isolation
        KeychainHelper.shared.backend = MockKeychainBackend()

        // Use mock git service
        mockGitService = MockGitService()

        // Use isolated UserDefaults
        mockUserDefaults = UserDefaults(suiteName: "TestDefaults")!
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")

        profileManager = ProfileManager(gitService: mockGitService, userDefaults: mockUserDefaults)
    }

    override func tearDown() {
        // Clean up
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        profileManager = nil
        mockGitService = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Profile CRUD Tests

    func testAddProfile() {
        // Given
        let profile = GitProfile(
            name: "Test User",
            email: "test@example.com",
            token: "ghp_test123"
        )

        // When
        profileManager.addProfile(profile)

        // Then
        XCTAssertEqual(profileManager.profiles.count, 1)
        XCTAssertEqual(profileManager.profiles.first?.name, "Test User")
        XCTAssertEqual(profileManager.profiles.first?.email, "test@example.com")
    }

    func testRemoveProfile() {
        // Given
        let profile = GitProfile(
            name: "Test User",
            email: "test@example.com",
            token: "ghp_test123"
        )
        profileManager.addProfile(profile)

        // When
        profileManager.removeProfile(id: profile.id)

        // Then
        XCTAssertEqual(profileManager.profiles.count, 0)
    }

    func testRemoveActiveProfile() {
        // Given
        let profile = GitProfile(
            name: "Test User",
            email: "test@example.com",
            token: "ghp_test123"
        )
        profileManager.addProfile(profile)
        profileManager.activeProfileId = profile.id

        // When
        profileManager.removeProfile(id: profile.id)

        // Then
        XCTAssertNil(profileManager.activeProfileId)
        XCTAssertEqual(profileManager.profiles.count, 0)
    }

    func testUpdateProfile() {
        // Given
        let profile = GitProfile(
            name: "Original Name",
            email: "original@example.com",
            token: "ghp_test123"
        )
        profileManager.addProfile(profile)

        var updatedProfile = profile
        updatedProfile.name = "Updated Name"
        updatedProfile.email = "updated@example.com"

        // When
        profileManager.updateProfile(updatedProfile)

        // Then
        XCTAssertEqual(profileManager.profiles.count, 1)
        XCTAssertEqual(profileManager.profiles.first?.name, "Updated Name")
        XCTAssertEqual(profileManager.profiles.first?.email, "updated@example.com")
    }

    // MARK: - Profile Switching Tests

    func testSwitchProfile() async {
        // Given
        let profile = GitProfile(
            name: "Test User",
            email: "test@example.com",
            token: "ghp_test123"
        )
        profileManager.addProfile(profile)

        // When
        profileManager.switchProfile(to: profile)

        // Then
        XCTAssertEqual(profileManager.activeProfileId, profile.id)

        // Wait for async operations to complete (just to ensure no crash)
        try? await Task.sleep(for: .seconds(0.1))
    }

    // MARK: - Persistence Tests

    func testProfilePersistence() {
        // Given
        let profile = GitProfile(
            name: "Persistent User",
            email: "persistent@example.com",
            token: "ghp_persist123"
        )

        // When
        profileManager.addProfile(profile)

        // Create a new ProfileManager instance with SAME user defaults
        let newProfileManager = ProfileManager(
            gitService: mockGitService, userDefaults: mockUserDefaults)

        // Then - profile should be loaded
        XCTAssertEqual(newProfileManager.profiles.count, 1)
        XCTAssertEqual(newProfileManager.profiles.first?.name, "Persistent User")
    }

    func testActiveProfilePersistence() {
        // Given
        let profile = GitProfile(
            name: "Active User",
            email: "active@example.com",
            token: "ghp_active123"
        )
        profileManager.addProfile(profile)
        profileManager.switchProfile(to: profile)

        // When - create new instance
        let newProfileManager = ProfileManager(
            gitService: mockGitService, userDefaults: mockUserDefaults)

        // Then - active profile should be restored
        XCTAssertEqual(newProfileManager.activeProfileId, profile.id)
    }

    // MARK: - Multiple Profiles Tests

    func testMultipleProfiles() {
        // Given
        let profiles = [
            GitProfile(name: "User 1", email: "user1@example.com", token: "token1"),
            GitProfile(name: "User 2", email: "user2@example.com", token: "token2"),
            GitProfile(name: "User 3", email: "user3@example.com", token: "token3"),
        ]

        // When
        profiles.forEach { profileManager.addProfile($0) }

        // Then
        XCTAssertEqual(profileManager.profiles.count, 3)
        XCTAssertEqual(
            Set(profileManager.profiles.map { $0.email }),
            Set(["user1@example.com", "user2@example.com", "user3@example.com"]))
    }
}
