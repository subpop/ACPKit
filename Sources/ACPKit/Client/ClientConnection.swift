import Foundation
import Logging

/// Wraps a ``JSONRPCPeer`` and a ``Client`` implementation, registering the client-side
/// JSON-RPC methods (permission requests, file/terminal operations, `session/update`
/// notifications) and exposing outgoing agent-facing calls (`initialize`, `session/new`,
/// `session/prompt`, `session/cancel`, etc.) for driving a connected agent.
public actor ClientConnection {
    private let peer: JSONRPCPeer
    private let client: any Client
    private let logger: Logger

    public init(
        transport: any Transport, client: any Client,
        logger: Logger = Logger(label: "ACPKit.ClientConnection")
    ) {
        self.peer = JSONRPCPeer(transport: transport, logger: logger)
        self.client = client
        self.logger = logger
    }

    /// Registers handlers and starts the underlying transport/peer, without performing
    /// the `initialize` handshake.
    public func start() async throws {
        await registerHandlers()
        try await peer.start()
    }

    /// Starts the connection and performs the `initialize` handshake using this
    /// client's advertised capabilities/info.
    @discardableResult
    public func connect() async throws -> InitializeResponse {
        try await start()
        let request = InitializeRequest(
            protocolVersion: acpProtocolVersion,
            clientCapabilities: client.capabilities,
            clientInfo: client.info
        )
        return try await peer.sendRequest(
            method: "initialize", params: request, as: InitializeResponse.self)
    }

    public func close() async {
        await peer.close()
    }

    private func registerHandlers() async {
        await peer.onRequest(method: "session/request_permission") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleRequestPermission(params)
        }
        await peer.onRequest(method: "fs/read_text_file") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleReadTextFile(params)
        }
        await peer.onRequest(method: "fs/write_text_file") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleWriteTextFile(params)
        }
        await peer.onRequest(method: "terminal/create") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleCreateTerminal(params)
        }
        await peer.onRequest(method: "terminal/output") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleTerminalOutput(params)
        }
        await peer.onRequest(method: "terminal/kill") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleKillTerminal(params)
        }
        await peer.onRequest(method: "terminal/release") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleReleaseTerminal(params)
        }
        await peer.onRequest(method: "terminal/wait_for_exit") { [weak self] params in
            guard let self else { throw ClientError.internalError("ClientConnection deallocated") }
            return try await self.handleWaitForTerminalExit(params)
        }
        await peer.onNotification(method: "session/update") { [weak self] params in
            await self?.handleSessionUpdate(params)
        }
    }

    private func handleRequestPermission(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("session/request_permission requires params")
        }
        let request = try paramsValue.decode(as: RequestPermissionRequest.self)
        let response = try await client.requestPermission(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleReadTextFile(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("fs/read_text_file requires params")
        }
        let request = try paramsValue.decode(as: ReadTextFileRequest.self)
        let response = try await client.readTextFile(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleWriteTextFile(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("fs/write_text_file requires params")
        }
        let request = try paramsValue.decode(as: WriteTextFileRequest.self)
        let response = try await client.writeTextFile(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleCreateTerminal(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("terminal/create requires params")
        }
        let request = try paramsValue.decode(as: CreateTerminalRequest.self)
        let response = try await client.createTerminal(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleTerminalOutput(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("terminal/output requires params")
        }
        let request = try paramsValue.decode(as: TerminalOutputRequest.self)
        let response = try await client.terminalOutput(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleKillTerminal(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("terminal/kill requires params")
        }
        let request = try paramsValue.decode(as: KillTerminalRequest.self)
        let response = try await client.killTerminal(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleReleaseTerminal(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("terminal/release requires params")
        }
        let request = try paramsValue.decode(as: ReleaseTerminalRequest.self)
        let response = try await client.releaseTerminal(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleWaitForTerminalExit(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw ClientError.invalidParams("terminal/wait_for_exit requires params")
        }
        let request = try paramsValue.decode(as: WaitForTerminalExitRequest.self)
        let response = try await client.waitForTerminalExit(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleSessionUpdate(_ paramsValue: JSONValue?) async {
        guard let paramsValue,
            let notification = try? paramsValue.decode(as: SessionNotification.self)
        else {
            logger.warning("Received malformed session/update notification")
            return
        }
        await client.sessionUpdate(notification)
    }

    // MARK: - Outgoing agent-facing calls

    public func newSession(_ request: NewSessionRequest) async throws -> NewSessionResponse {
        try await peer.sendRequest(
            method: "session/new", params: request, as: NewSessionResponse.self)
    }

    public func loadSession(_ request: LoadSessionRequest) async throws -> LoadSessionResponse {
        try await peer.sendRequest(
            method: "session/load", params: request, as: LoadSessionResponse.self)
    }

    public func resumeSession(_ request: ResumeSessionRequest) async throws -> ResumeSessionResponse
    {
        try await peer.sendRequest(
            method: "session/resume", params: request, as: ResumeSessionResponse.self)
    }

    public func prompt(_ request: PromptRequest) async throws -> PromptResponse {
        try await peer.sendRequest(
            method: "session/prompt", params: request, as: PromptResponse.self)
    }

    public func cancel(sessionId: SessionId) async throws {
        try await peer.sendNotification(
            method: "session/cancel", params: CancelNotification(sessionId: sessionId))
    }

    public func listSessions(_ request: ListSessionsRequest) async throws -> ListSessionsResponse {
        try await peer.sendRequest(
            method: "session/list", params: request, as: ListSessionsResponse.self)
    }

    public func closeSession(_ request: CloseSessionRequest) async throws -> CloseSessionResponse {
        try await peer.sendRequest(
            method: "session/close", params: request, as: CloseSessionResponse.self)
    }

    public func deleteSession(_ request: DeleteSessionRequest) async throws -> DeleteSessionResponse
    {
        try await peer.sendRequest(
            method: "session/delete", params: request, as: DeleteSessionResponse.self)
    }

    public func setSessionMode(_ request: SetSessionModeRequest) async throws
        -> SetSessionModeResponse
    {
        try await peer.sendRequest(
            method: "session/set_mode", params: request, as: SetSessionModeResponse.self)
    }

    public func setSessionConfigOption(
        _ request: SetSessionConfigOptionRequest
    ) async throws -> SetSessionConfigOptionResponse {
        try await peer.sendRequest(
            method: "session/set_config_option", params: request,
            as: SetSessionConfigOptionResponse.self
        )
    }

    public func authenticate(_ request: AuthenticateRequest) async throws -> AuthenticateResponse {
        try await peer.sendRequest(
            method: "authenticate", params: request, as: AuthenticateResponse.self)
    }

    public func logout(_ request: LogoutRequest) async throws -> LogoutResponse {
        try await peer.sendRequest(method: "logout", params: request, as: LogoutResponse.self)
    }
}
