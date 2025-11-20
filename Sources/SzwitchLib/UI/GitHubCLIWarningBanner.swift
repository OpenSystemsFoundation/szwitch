import SwiftUI

struct GitHubCLIWarningBanner: View {
    @StateObject private var cliManager = GitHubCLIManager()
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed && cliManager.installStatus != .installed {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub CLI Required")
                        .font(.headline)
                    Text("Install GitHub CLI to enable account switching for push/pull operations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if cliManager.canInstall {
                    Button {
                        Task {
                            await cliManager.installGitHubCLI()
                        }
                    } label: {
                        if cliManager.isInstalling {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("Install")
                        }
                    }
                    .disabled(cliManager.isInstalling)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button {
                    isDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
