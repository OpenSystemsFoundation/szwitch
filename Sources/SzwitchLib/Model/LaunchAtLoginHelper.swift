import Foundation
import ServiceManagement

@MainActor
public class LaunchAtLoginHelper {
    public static let shared = LaunchAtLoginHelper()
    
    private init() {}
    
    /// Check if app is set to launch at login
    public var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                // Fallback for older macOS versions
                return false
            }
        }
    }
    
    /// Enable or disable launch at login
    public func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    // Already enabled
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    // Already disabled
                    return
                }
                try SMAppService.mainApp.unregister()
            }
        } else {
            throw LaunchAtLoginError.unsupportedOS
        }
    }
}

public enum LaunchAtLoginError: Error, LocalizedError {
    case unsupportedOS
    case registrationFailed
    case unregistrationFailed
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "Launch at login requires macOS 13.0 or later"
        case .registrationFailed:
            return "Failed to enable launch at login"
        case .unregistrationFailed:
            return "Failed to disable launch at login"
        }
    }
}
