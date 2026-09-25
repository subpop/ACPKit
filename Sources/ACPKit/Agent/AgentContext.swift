import Foundation

/// Errors surfaced by ``AgentContext`` operations that are local to the agent-side
/// (as opposed to errors returned by the client over JSON-RPC).
public enum AgentContextError: Error, Sendable, Equatable, LocalizedError {
    /// The client has not advertised support for the requested capability.
    case capabilityNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case .capabilityNotSupported(let capability):
            return "Client does not support capability: \(capability)"
        }
    }
}

/// The set of client-facing operations available to an ``Agent`` while handling a
/// `session/new`, `session/load`, or `session/prompt` request. Implementations forward
/// these calls to the connected client over JSON-RPC.
public protocol AgentContext: Sendable {
    /// The session this context is bound to.
    var sessionId: SessionId { get }
    /// The capabilities the connected client advertised at `initialize` time.
    var clientCapabilities: ClientCapabilities { get }

    /// Sends `session/request_permission` to the client and returns the outcome.
    func requestPermission(
        toolCall: ToolCallUpdate,
        options: [PermissionOption],
        meta: [String: JSONValue]?
    ) async throws -> RequestPermissionOutcome

    /// Sends a `session/update` notification to the client.
    func sendUpdate(_ update: SessionUpdate, meta: [String: JSONValue]?) async throws

    /// Reads a text file via the client's `fs/read_text_file`, if supported.
    func readTextFile(path: String, line: UInt32?, limit: UInt32?) async throws -> String

    /// Writes a text file via the client's `fs/write_text_file`, if supported.
    func writeTextFile(path: String, content: String) async throws

    /// Creates a terminal via the client's `terminal/create`, if supported.
    func createTerminal(
        command: String,
        args: [String]?,
        env: [EnvVariable]?,
        cwd: String?,
        outputByteLimit: UInt64?
    ) async throws -> TerminalId

    /// Reads the current output of a terminal via `terminal/output`.
    func terminalOutput(terminalId: TerminalId) async throws -> TerminalOutputResponse

    /// Waits for a terminal to exit via `terminal/wait_for_exit`.
    func waitForTerminalExit(terminalId: TerminalId) async throws -> WaitForTerminalExitResponse

    /// Kills a terminal via `terminal/kill`.
    func killTerminal(terminalId: TerminalId) async throws

    /// Releases a terminal via `terminal/release`.
    func releaseTerminal(terminalId: TerminalId) async throws
}

extension AgentContext {
    public func requestPermission(
        toolCall: ToolCallUpdate,
        options: [PermissionOption]
    ) async throws -> RequestPermissionOutcome {
        try await requestPermission(toolCall: toolCall, options: options, meta: nil)
    }

    public func sendUpdate(_ update: SessionUpdate) async throws {
        try await sendUpdate(update, meta: nil)
    }

    /// Sends an `agent_message_chunk` update containing plain text.
    public func sendTextMessage(_ text: String, messageId: MessageId? = nil) async throws {
        try await sendUpdate(
            .agentMessageChunk(
                ContentChunk(content: .text(TextContent(text: text)), messageId: messageId))
        )
    }

    /// Sends an `agent_thought_chunk` update containing plain text.
    public func sendThought(_ text: String, messageId: MessageId? = nil) async throws {
        try await sendUpdate(
            .agentThoughtChunk(
                ContentChunk(content: .text(TextContent(text: text)), messageId: messageId))
        )
    }

    public func readTextFile(path: String) async throws -> String {
        try await readTextFile(path: path, line: nil, limit: nil)
    }

    public func createTerminal(command: String, args: [String]? = nil) async throws -> TerminalId {
        try await createTerminal(
            command: command, args: args, env: nil, cwd: nil, outputByteLimit: nil)
    }
}
