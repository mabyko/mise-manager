/// One line of subprocess output, streamed live to the UI (was the `mise-output` Tauri event).
public struct OutputLine: Equatable, Sendable {
    public enum Stream: String, Sendable { case stdout, stderr }
    public let stream: Stream
    public let line: String
    public let command: String?

    public init(stream: Stream, line: String, command: String? = nil) {
        self.stream = stream
        self.line = line
        self.command = command
    }
}

public struct CommandResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// Runs processes. `MiseCLI` is the real one; tests substitute a fake.
public protocol CommandRunner: Sendable {
    /// Runs the mise executable with the augmented PATH.
    func runMise(_ args: [String]) async throws -> CommandResult
    /// Runs an arbitrary program (`sh`, `brew`) for the "mise isn't installed yet" paths.
    func runShell(_ program: String, _ args: [String]) async throws -> CommandResult
}
