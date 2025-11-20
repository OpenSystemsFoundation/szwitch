import SwiftUI

/// A view that displays CLI command output in a terminal-like interface
public struct CLIOutputView: View {
    let output: String
    
    public init(output: String) {
        self.output = output
    }
    
    public var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("bottom")
                }
                .padding(8)
                .onChange(of: output) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Observable object to manage CLI command execution and output
@MainActor
public class CLICommandRunner: ObservableObject {
    @Published public var output: String = ""
    @Published public var isRunning: Bool = false
    @Published public var exitCode: Int32 = 0
    
    public init() {}
    
    public func run(command: String, args: [String]) async throws -> String {
        isRunning = true
        output = "$ \(command) \(args.joined(separator: " "))\n"
        exitCode = 0
        
        defer {
            isRunning = false
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: command)
                    process.arguments = args
                    
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    // Read all output at once
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let outputStr = String(data: outputData, encoding: .utf8) ?? ""
                    let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let combinedOutput = outputStr + errorStr
                    
                    Task { @MainActor in
                        continuation.resume(returning: combinedOutput)
                    }
                } catch {
                    Task { @MainActor in
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public func clear() {
        output = ""
        exitCode = 0
    }
}
