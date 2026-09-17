import Foundation
@testable import MiseCore

/// Records every invocation; canned replies are keyed by the joined argument list.
/// Lock-based (not an actor) so tests can read calls without awaiting.
final class FakeRunner: CommandRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[String]] = []
    private var replies: [String: [CommandResult]]
    private var pauses: [String: (started: AsyncStream<Void>.Continuation, resume: AsyncStream<Void>)] = [:]

    init(_ replies: [String: CommandResult] = [:]) { self.replies = replies.mapValues { [$0] } }

    static func ok(_ stdout: String) -> CommandResult { CommandResult(stdout: stdout, stderr: "", exitCode: 0) }
    static func failure(_ message: String) -> CommandResult { CommandResult(stdout: "", stderr: message, exitCode: 1) }

    var calls: [[String]] { lock.withLock { _calls } }
    func count(_ key: String) -> Int { calls.filter { $0.joined(separator: " ") == key }.count }
    func index(_ key: String) -> Int? { calls.firstIndex { $0.joined(separator: " ") == key } }
    func called(prefix: String) -> Bool { calls.contains { $0.joined(separator: " ").hasPrefix(prefix) } }
    func mark(_ label: String) { lock.withLock { _calls.append([label]) } }

    func reply(_ key: String, _ stdout: String) { lock.withLock { replies[key] = [Self.ok(stdout)] } }
    func fail(_ key: String, _ message: String) { lock.withLock { replies[key] = [Self.failure(message)] } }
    /// Each result is used once; the last one repeats.
    func queue(_ key: String, _ results: [CommandResult]) { lock.withLock { replies[key] = results } }

    /// `ls --installed --json` and `ls --global --json` as mise would print them for these tools.
    func installed(_ tools: [(name: String, global: String?, versions: [String])]) {
        func json(_ entries: [(String, [String])]) -> String {
            "{" + entries.map { name, versions in
                "\"\(name)\":[" + versions.map { "{\"version\":\"\($0)\"}" }.joined(separator: ",") + "]"
            }.joined(separator: ",") + "}"
        }
        reply("ls --installed --json", json(tools.map { ($0.name, $0.versions) }))
        reply("ls --global --json", json(tools.compactMap { tool in tool.global.map { (tool.name, [$0]) } }))
    }

    /// Hold a command in flight until the test releases it, without timing-dependent sleeps.
    func pause(_ key: String) -> (started: AsyncStream<Void>, resume: AsyncStream<Void>.Continuation) {
        let started = AsyncStream<Void>.makeStream()
        let resume = AsyncStream<Void>.makeStream()
        lock.withLock { pauses[key] = (started.continuation, resume.stream) }
        return (started.stream, resume.continuation)
    }

    func runMise(_ args: [String]) async throws -> CommandResult {
        let result = take(args)
        if let pause = lock.withLock({ pauses.removeValue(forKey: args.joined(separator: " ")) }) {
            pause.started.yield(())
            pause.started.finish()
            for await _ in pause.resume {}
            try Task.checkCancellation()
        }
        return result
    }
    func runShell(_ program: String, _ args: [String]) async throws -> CommandResult { take([program] + args) }

    private func take(_ args: [String]) -> CommandResult {
        lock.withLock {
            _calls.append(args)
            let key = args.joined(separator: " ")
            guard var list = replies[key], let first = list.first else { return Self.ok("") }
            if list.count > 1 { list.removeFirst(); replies[key] = list }
            return first
        }
    }
}

/// App state wired to a fake runner, a throwaway UserDefaults suite and a temp config.toml.
@MainActor
func makeState(_ runner: FakeRunner, latest: @escaping @Sendable () async throws -> String? = { "v0.0.0" }) -> AppState {
    let id = UUID().uuidString
    let defaults = UserDefaults(suiteName: "mise-manager.tests.\(id)")!
    let config = NSTemporaryDirectory() + "mise-manager-tests-\(id)/config.toml"
    return AppState(mise: Mise(runner: runner, configPath: config), settings: Settings(defaults: defaults), latestRelease: latest)
}
