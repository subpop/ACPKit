import Foundation

/// Concrete ``AgentContext`` implementation backed by a ``JSONRPCPeer`` connected to a
/// client. A plain struct (not an actor) since it holds only immutable value/reference
/// state and its methods just forward to the actor-isolated `peer`.
struct AgentSessionContext: AgentContext {
    let sessionId: SessionId
    let clientCapabilities: ClientCapabilities
    let peer: JSONRPCPeer

    func requestPermission(
        toolCall: ToolCallUpdate,
        options: [PermissionOption],
        meta: [String: JSONValue]?
    ) async throws -> RequestPermissionOutcome {
        let request = RequestPermissionRequest(
            sessionId: sessionId, toolCall: toolCall, options: options, meta: meta)
        let response = try await peer.sendRequest(
            method: "session/request_permission", params: request,
            as: RequestPermissionResponse.self
        )
        return response.outcome
    }

    func sendUpdate(_ update: SessionUpdate, meta: [String: JSONValue]?) async throws {
        let notification = SessionNotification(sessionId: sessionId, update: update, meta: meta)
        try await peer.sendNotification(method: "session/update", params: notification)
    }

    func readTextFile(path: String, line: UInt32?, limit: UInt32?) async throws -> String {
        guard clientCapabilities.fs.readTextFile else {
            throw AgentContextError.capabilityNotSupported("fs.readTextFile")
        }
        let request = ReadTextFileRequest(
            sessionId: sessionId, path: path, line: line, limit: limit)
        let response = try await peer.sendRequest(
            method: "fs/read_text_file", params: request, as: ReadTextFileResponse.self
        )
        return response.content
    }

    func writeTextFile(path: String, content: String) async throws {
        guard clientCapabilities.fs.writeTextFile else {
            throw AgentContextError.capabilityNotSupported("fs.writeTextFile")
        }
        let request = WriteTextFileRequest(sessionId: sessionId, path: path, content: content)
        _ = try await peer.sendRequest(
            method: "fs/write_text_file", params: request, as: WriteTextFileResponse.self)
    }

    func createTerminal(
        command: String,
        args: [String]?,
        env: [EnvVariable]?,
        cwd: String?,
        outputByteLimit: UInt64?
    ) async throws -> TerminalId {
        guard clientCapabilities.terminal else {
            throw AgentContextError.capabilityNotSupported("terminal")
        }
        let request = CreateTerminalRequest(
            sessionId: sessionId, command: command, args: args, env: env, cwd: cwd,
            outputByteLimit: outputByteLimit
        )
        let response = try await peer.sendRequest(
            method: "terminal/create", params: request, as: CreateTerminalResponse.self
        )
        return response.terminalId
    }

    func terminalOutput(terminalId: TerminalId) async throws -> TerminalOutputResponse {
        guard clientCapabilities.terminal else {
            throw AgentContextError.capabilityNotSupported("terminal")
        }
        let request = TerminalOutputRequest(sessionId: sessionId, terminalId: terminalId)
        return try await peer.sendRequest(
            method: "terminal/output", params: request, as: TerminalOutputResponse.self)
    }

    func waitForTerminalExit(terminalId: TerminalId) async throws -> WaitForTerminalExitResponse {
        guard clientCapabilities.terminal else {
            throw AgentContextError.capabilityNotSupported("terminal")
        }
        let request = WaitForTerminalExitRequest(sessionId: sessionId, terminalId: terminalId)
        return try await peer.sendRequest(
            method: "terminal/wait_for_exit", params: request, as: WaitForTerminalExitResponse.self
        )
    }

    func killTerminal(terminalId: TerminalId) async throws {
        guard clientCapabilities.terminal else {
            throw AgentContextError.capabilityNotSupported("terminal")
        }
        let request = KillTerminalRequest(sessionId: sessionId, terminalId: terminalId)
        _ = try await peer.sendRequest(
            method: "terminal/kill", params: request, as: KillTerminalResponse.self)
    }

    func releaseTerminal(terminalId: TerminalId) async throws {
        guard clientCapabilities.terminal else {
            throw AgentContextError.capabilityNotSupported("terminal")
        }
        let request = ReleaseTerminalRequest(sessionId: sessionId, terminalId: terminalId)
        _ = try await peer.sendRequest(
            method: "terminal/release", params: request, as: ReleaseTerminalResponse.self)
    }
}
