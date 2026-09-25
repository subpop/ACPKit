import Foundation
import Logging

/// Wraps a ``JSONRPCPeer`` and an ``Agent`` implementation, registering the agent-side
/// JSON-RPC methods and dispatching incoming requests/notifications to the agent.
///
/// `AgentConnection` also owns `session/cancel` bookkeeping: each in-flight
/// `session/prompt` call is tracked by `sessionId` in a `Task` registry, so that when a
/// `session/cancel` notification arrives for that session, the corresponding task is
/// cancelled cooperatively.
public actor AgentConnection {
    private let peer: JSONRPCPeer
    private let agent: any Agent
    private let logger: Logger
    private var clientCapabilities: ClientCapabilities = ClientCapabilities()
    private var promptTasks: [SessionId: Task<PromptResponse, Error>] = [:]

    public init(
        transport: any Transport, agent: any Agent,
        logger: Logger = Logger(label: "ACPKit.AgentConnection")
    ) {
        self.peer = JSONRPCPeer(transport: transport, logger: logger)
        self.agent = agent
        self.logger = logger
    }

    /// Registers all handlers and starts the underlying transport/peer.
    public func start() async throws {
        await registerHandlers()
        try await peer.start()
    }

    /// Cancels all in-flight prompts and closes the underlying peer/transport.
    public func close() async {
        for task in promptTasks.values {
            task.cancel()
        }
        promptTasks.removeAll()
        await peer.close()
    }

    private func registerHandlers() async {
        await peer.onRequest(method: "initialize") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleInitialize(params)
        }
        await peer.onRequest(method: "session/new") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleNewSession(params)
        }
        await peer.onRequest(method: "session/load") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleLoadSession(params)
        }
        await peer.onRequest(method: "session/resume") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleResumeSession(params)
        }
        await peer.onRequest(method: "session/prompt") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handlePromptRequest(params)
        }
        await peer.onRequest(method: "session/list") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleListSessions(params)
        }
        await peer.onRequest(method: "session/close") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleCloseSession(params)
        }
        await peer.onRequest(method: "session/delete") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleDeleteSession(params)
        }
        await peer.onRequest(method: "session/set_mode") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleSetSessionMode(params)
        }
        await peer.onRequest(method: "session/set_config_option") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleSetSessionConfigOption(params)
        }
        await peer.onRequest(method: "authenticate") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleAuthenticate(params)
        }
        await peer.onRequest(method: "logout") { [weak self] params in
            guard let self else { throw AgentError.internalError("AgentConnection deallocated") }
            return try await self.handleLogout(params)
        }
        await peer.onNotification(method: "session/cancel") { [weak self] params in
            await self?.handleCancel(params)
        }
    }

    private func makeContext(sessionId: SessionId) -> AgentContext {
        AgentSessionContext(
            sessionId: sessionId, clientCapabilities: clientCapabilities, peer: peer)
    }

    private func handleInitialize(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else { throw AgentError.invalidParams("initialize requires params") }
        let request = try paramsValue.decode(as: InitializeRequest.self)
        self.clientCapabilities = request.clientCapabilities
        let negotiatedVersion =
            request.protocolVersion == acpProtocolVersion
            ? request.protocolVersion : acpProtocolVersion
        let response = InitializeResponse(
            protocolVersion: negotiatedVersion,
            agentCapabilities: agent.capabilities,
            authMethods: agent.authMethods,
            agentInfo: agent.info
        )
        return try JSONValue(encoding: response)
    }

    private func handleNewSession(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else { throw AgentError.invalidParams("session/new requires params") }
        let request = try paramsValue.decode(as: NewSessionRequest.self)
        let response = try await agent.createSession(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleLoadSession(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/load requires params")
        }
        let request = try paramsValue.decode(as: LoadSessionRequest.self)
        let context = makeContext(sessionId: request.sessionId)
        let response = try await agent.loadSession(request: request, context: context)
        return try JSONValue(encoding: response)
    }

    private func handleResumeSession(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/resume requires params")
        }
        let request = try paramsValue.decode(as: ResumeSessionRequest.self)
        let response = try await agent.resumeSession(request: request)
        return try JSONValue(encoding: response)
    }

    private func handlePromptRequest(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/prompt requires params")
        }
        let request = try paramsValue.decode(as: PromptRequest.self)
        let context = makeContext(sessionId: request.sessionId)
        let agent = self.agent
        let task = Task<PromptResponse, Error> {
            try await agent.handlePrompt(request: request, context: context)
        }
        promptTasks[request.sessionId] = task
        defer { promptTasks.removeValue(forKey: request.sessionId) }
        do {
            let response = try await task.value
            return try JSONValue(encoding: response)
        } catch is CancellationError {
            return try JSONValue(encoding: PromptResponse(stopReason: .cancelled))
        }
    }

    private func handleListSessions(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/list requires params")
        }
        let request = try paramsValue.decode(as: ListSessionsRequest.self)
        let response = try await agent.listSessions(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleCloseSession(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/close requires params")
        }
        let request = try paramsValue.decode(as: CloseSessionRequest.self)
        let response = try await agent.closeSession(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleDeleteSession(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/delete requires params")
        }
        let request = try paramsValue.decode(as: DeleteSessionRequest.self)
        let response = try await agent.deleteSession(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleSetSessionMode(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/set_mode requires params")
        }
        let request = try paramsValue.decode(as: SetSessionModeRequest.self)
        let response = try await agent.setSessionMode(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleSetSessionConfigOption(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("session/set_config_option requires params")
        }
        let request = try paramsValue.decode(as: SetSessionConfigOptionRequest.self)
        let response = try await agent.setSessionConfigOption(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleAuthenticate(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else {
            throw AgentError.invalidParams("authenticate requires params")
        }
        let request = try paramsValue.decode(as: AuthenticateRequest.self)
        let response = try await agent.authenticate(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleLogout(_ paramsValue: JSONValue?) async throws -> JSONValue {
        guard let paramsValue else { throw AgentError.invalidParams("logout requires params") }
        let request = try paramsValue.decode(as: LogoutRequest.self)
        let response = try await agent.logout(request: request)
        return try JSONValue(encoding: response)
    }

    private func handleCancel(_ paramsValue: JSONValue?) async {
        guard let paramsValue,
            let notification = try? paramsValue.decode(as: CancelNotification.self)
        else {
            logger.warning("Received malformed session/cancel notification")
            return
        }
        promptTasks[notification.sessionId]?.cancel()
    }
}
