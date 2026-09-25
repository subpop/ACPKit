import Foundation

/// The interface an ACP agent implementation provides. Conforming types are wrapped by
/// ``AgentConnection`` to serve requests from a connected client over a ``Transport``.
///
/// Only ``capabilities``, ``createSession(request:)``, and
/// ``handlePrompt(request:context:)`` are required. All other methods default to
/// throwing ``AgentError/notImplemented(method:)`` and should be overridden only if the
/// agent advertises the corresponding capability.
public protocol Agent: Sendable {
    /// Capabilities this agent supports, returned in the `initialize` response.
    var capabilities: AgentCapabilities { get }
    /// Authentication methods this agent supports, returned in the `initialize` response.
    var authMethods: [AuthMethod] { get }
    /// Optional agent implementation metadata, returned in the `initialize` response.
    var info: Implementation? { get }

    /// Handles `session/new`.
    func createSession(request: NewSessionRequest) async throws -> NewSessionResponse

    /// Handles `session/load`. Implementations should stream the session's prior
    /// history back to the client via `context.sendUpdate` before returning.
    func loadSession(request: LoadSessionRequest, context: AgentContext) async throws
        -> LoadSessionResponse

    /// Handles `session/resume`.
    func resumeSession(request: ResumeSessionRequest) async throws -> ResumeSessionResponse

    /// Handles `session/prompt`.
    func handlePrompt(request: PromptRequest, context: AgentContext) async throws -> PromptResponse

    /// Handles `session/list`.
    func listSessions(request: ListSessionsRequest) async throws -> ListSessionsResponse

    /// Handles `session/close`.
    func closeSession(request: CloseSessionRequest) async throws -> CloseSessionResponse

    /// Handles `session/delete`.
    func deleteSession(request: DeleteSessionRequest) async throws -> DeleteSessionResponse

    /// Handles `session/set_mode`.
    func setSessionMode(request: SetSessionModeRequest) async throws -> SetSessionModeResponse

    /// Handles `session/set_config_option`.
    func setSessionConfigOption(request: SetSessionConfigOptionRequest) async throws
        -> SetSessionConfigOptionResponse

    /// Handles `authenticate`.
    func authenticate(request: AuthenticateRequest) async throws -> AuthenticateResponse

    /// Handles `logout`.
    func logout(request: LogoutRequest) async throws -> LogoutResponse
}

extension Agent {
    public var authMethods: [AuthMethod] { [] }
    public var info: Implementation? { nil }

    public func loadSession(request: LoadSessionRequest, context: AgentContext) async throws
        -> LoadSessionResponse
    {
        throw AgentError.notImplemented(method: "session/load")
    }

    public func resumeSession(request: ResumeSessionRequest) async throws -> ResumeSessionResponse {
        throw AgentError.notImplemented(method: "session/resume")
    }

    public func listSessions(request: ListSessionsRequest) async throws -> ListSessionsResponse {
        throw AgentError.notImplemented(method: "session/list")
    }

    public func closeSession(request: CloseSessionRequest) async throws -> CloseSessionResponse {
        throw AgentError.notImplemented(method: "session/close")
    }

    public func deleteSession(request: DeleteSessionRequest) async throws -> DeleteSessionResponse {
        throw AgentError.notImplemented(method: "session/delete")
    }

    public func setSessionMode(request: SetSessionModeRequest) async throws
        -> SetSessionModeResponse
    {
        throw AgentError.notImplemented(method: "session/set_mode")
    }

    public func setSessionConfigOption(
        request: SetSessionConfigOptionRequest
    ) async throws -> SetSessionConfigOptionResponse {
        throw AgentError.notImplemented(method: "session/set_config_option")
    }

    public func authenticate(request: AuthenticateRequest) async throws -> AuthenticateResponse {
        throw AgentError.notImplemented(method: "authenticate")
    }

    public func logout(request: LogoutRequest) async throws -> LogoutResponse {
        throw AgentError.notImplemented(method: "logout")
    }
}
