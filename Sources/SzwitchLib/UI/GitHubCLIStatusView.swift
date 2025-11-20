import SwiftUI

public struct GitHubCLIStatusView: View {
    @StateObject private var cliManager = GitHubCLIManager()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(cliManager.statusMessage)
                    .font(.body)
                
                Spacer()
                
                if cliManager.installStatus == .installed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            if cliManager.canInstall {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub CLI is required for account switching to work properly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        Task {
                            await cliManager.installGitHubCLI()
                        }
                    } label: {
                        if cliManager.isInstalling {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                                Text("Installing...")
                            }
                        } else {
                            Text("Install GitHub CLI")
                        }
                    }
                    .disabled(cliManager.isInstalling)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if cliManager.installStatus == .brewNotFound {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Homebrew is required to install GitHub CLI automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Link("Install Homebrew", destination: URL(string: "https://brew.sh")!)
                        .font(.caption)
                    
                    Text("After installing Homebrew, restart Szwitch.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let error = cliManager.installError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if cliManager.installStatus == .installed {
                Text("All GitHub operations (push, pull, etc.) will use the active profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch cliManager.installStatus {
        case .installed:
            return "checkmark.circle.fill"
        case .notInstalled:
            return "exclamationmark.triangle.fill"
        case .brewNotFound:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch cliManager.installStatus {
        case .installed:
            return .green
        case .notInstalled:
            return .orange
        case .brewNotFound:
            return .red
        }
    }
}
