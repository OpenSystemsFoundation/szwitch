import XCTest
@testable import SzwitchLib

final class GitHubServiceTests: XCTestCase {
    
    func testIsInstalled() {
        // This test depends on the environment, so it might be flaky if run on a machine without gh.
        // However, for the user's machine, we expect it to be either installed or not.
        // A better approach for unit testing is to mock the file system check if possible,
        // but RealGitHubService uses FileManager.default directly.
        // For now, we just check that it doesn't crash.
        let service = RealGitHubService()
        _ = service.isInstalled()
    }
    
    // We cannot easily test install() or login() with RealGitHubService without side effects.
    // We should rely on manual verification for those, or refactor RealGitHubService to be more testable (injecting Process runner).
    
    func testServiceProtocol() {
        // Verify that we can create a mock conforming to the protocol
        struct MockGitHubService: GitHubServiceProtocol {
            func isInstalled() -> Bool { return true }
            func install() async throws {}
            func login(token: String) async throws {}
            func setupGit() async throws {}
        }
        
        let mock = MockGitHubService()
        XCTAssertTrue(mock.isInstalled())
    }
}
