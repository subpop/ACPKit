import Foundation
import Testing

@testable import ACPKit

/// Minimal agent stub with overridable hooks for dispatch tests.
private struct StubAgent: Agent, Sendable {
    var capabilities = AgentCapabilities()
    var hook: @Sendable (String) async throws -> JSONValue = { _ in .object([:]) }

    func createSession(request: NewSessionRequest) async throws -> NewSessionResponse {
        NewSessionResponse(sessionId: "s1")
    }

    func handlePrompt(request: PromptRequest, context: AgentContext) async throws -> PromptResponse
    {
        _ = try await hook("prompt")
        return PromptResponse(stopReason: .endTurn)
    }

    func listSessions(request: ListSessionsRequest) async throws -> ListSessionsResponse {
        _ = try await hook("list")
        return ListSessionsResponse(sessions: [])
    }
}

private func makeAgentConnection(
    agent: StubAgent = StubAgent()
) -> (AgentConnection, CapturingTransport) {
    let transport = CapturingTransport()
    let connection = AgentConnection(transport: transport, agent: agent)
    return (connection, transport)
}

private func initializeParams(version: Int) throws -> JSONValue {
    try JSONValue(
        encoding: InitializeRequest(
            protocolVersion: version, clientCapabilities: ClientCapabilities()))
}

// MARK: - initialize negotiation

@Test(
    "initialize version negotiation",
    arguments: [
        (name: "exact-echoes", clientVersion: acpProtocolVersion, expected: acpProtocolVersion),
        (name: "mismatch-falls-back", clientVersion: 999, expected: acpProtocolVersion),
    ])
func agentInitializeNegotiation(c: (name: String, clientVersion: Int, expected: Int)) async throws {
    let (connection, transport) = makeAgentConnection()
    try await connection.start()
    let id = RequestID.string("init-\(c.name)")
    transport.inject(
        try rpcRequestData(
            id: id, method: "initialize", params: try initializeParams(version: c.clientVersion)))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .response(let resp) = try JSONRPCMessage(data: data) else {
        Issue.record("expected response for \(c.name)")
        await connection.close()
        return
    }
    #expect(try resp.result.decode(as: InitializeResponse.self).protocolVersion == c.expected)
    await connection.close()
}

@Test("initialize missing params is -32602", arguments: ["initialize", "session/new"])
func agentMissingParams(method: String) async throws {
    let (connection, transport) = makeAgentConnection()
    try await connection.start()
    let id = RequestID.string("missing-\(method)")
    transport.inject(try rpcRequestData(id: id, method: method, params: nil))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .error(let err) = try JSONRPCMessage(data: data) else {
        Issue.record("expected error for \(method)")
        await connection.close()
        return
    }
    #expect(err.error.code == -32602)
    await connection.close()
}

// MARK: - session dispatch

@Test(
    "session handlers dispatch",
    arguments: [
        (
            name: "new", method: "session/new",
            params: #"{"cwd":"/tmp","mcpServers":[]}"#
        ),
        (
            name: "prompt", method: "session/prompt",
            params: #"{"sessionId":"s1","prompt":[{"type":"text","text":"hi"}]}"#
        ),
        (name: "list", method: "session/list", params: "{}"),
    ])
func agentSessionDispatch(c: (name: String, method: String, params: String)) async throws {
    let (connection, transport) = makeAgentConnection()
    try await connection.start()
    let id = RequestID.string("dispatch-\(c.name)")
    let params = try JSONDecoder.acpDecoder.decode(JSONValue.self, from: Data(c.params.utf8))
    transport.inject(try rpcRequestData(id: id, method: c.method, params: params))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .response = try JSONRPCMessage(data: data) else {
        Issue.record("expected response for \(c.name)")
        await connection.close()
        return
    }
    await connection.close()
}

@Test(
    "unimplemented methods map to -32601",
    arguments: [
        (
            name: "load", method: "session/load",
            params: #"{"sessionId":"s","cwd":"/tmp","mcpServers":[]}"#
        ),
        (
            name: "resume", method: "session/resume",
            params: #"{"sessionId":"s","cwd":"/tmp"}"#
        ),
        (
            name: "close", method: "session/close",
            params: #"{"sessionId":"s"}"#
        ),
        (
            name: "delete", method: "session/delete",
            params: #"{"sessionId":"s"}"#
        ),
        (
            name: "set-mode", method: "session/set_mode",
            params: #"{"sessionId":"s","modeId":"m"}"#
        ),
        (
            name: "set-config", method: "session/set_config_option",
            params: #"{"sessionId":"s","configId":"c","value":"v"}"#
        ),
        (
            name: "auth", method: "authenticate",
            params: #"{"methodId":"m"}"#
        ),
        (name: "logout", method: "logout", params: "{}"),
    ])
func agentNotImplementedMapping(c: (name: String, method: String, params: String)) async throws {
    let (connection, transport) = makeAgentConnection()
    try await connection.start()
    let id = RequestID.string("ni-\(c.name)")
    let params = try JSONDecoder.acpDecoder.decode(JSONValue.self, from: Data(c.params.utf8))
    transport.inject(try rpcRequestData(id: id, method: c.method, params: params))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .error(let err) = try JSONRPCMessage(data: data) else {
        Issue.record("expected error for \(c.method)")
        await connection.close()
        return
    }
    #expect(err.error.code == -32601)
    await connection.close()
}

@Test("unknown agent method is -32601", arguments: ["bogus", "session/nope"])
func agentUnknownMethod(method: String) async throws {
    let (connection, transport) = makeAgentConnection()
    try await connection.start()
    let id = RequestID.string("unk-\(method)")
    transport.inject(try rpcRequestData(id: id, method: method, params: nil))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .error(let err) = try JSONRPCMessage(data: data) else {
        Issue.record("expected error for \(method)")
        await connection.close()
        return
    }
    #expect(err.error.code == -32601)
    await connection.close()
}

// MARK: - prompt cancellation

@Test("session/cancel maps prompt to cancelled", arguments: ["s1", "s2"])
func agentPromptCancel(sessionId: String) async throws {
    let gated = LockedFlag()
    let agent = StubAgent(hook: { _ in
        try await gated.waitUntilCancelled()
        throw CancellationError()
    })
    let (connection, transport) = makeAgentConnection(agent: agent)
    try await connection.start()

    let promptId = RequestID.string("prompt-\(sessionId)")
    let prompt = try JSONValue(
        encoding: PromptRequest(
            sessionId: SessionId(sessionId), prompt: [.text(TextContent(text: "hi"))]))
    transport.inject(try rpcRequestData(id: promptId, method: "session/prompt", params: prompt))
    // Let the prompt task register, then cancel it.
    try await Task.sleep(nanoseconds: 100_000_000)
    let cancel = try JSONValue(encoding: CancelNotification(sessionId: SessionId(sessionId)))
    transport.inject(try rpcNotificationData(method: "session/cancel", params: cancel))
    await gated.cancel()

    let data = try await transport.awaitSent(matching: isResponseData(for: promptId))
    guard case .response(let resp) = try JSONRPCMessage(data: data) else {
        Issue.record("expected response for cancelled prompt \(sessionId)")
        await connection.close()
        return
    }
    #expect(try resp.result.decode(as: PromptResponse.self).stopReason == .cancelled)
    await connection.close()
}

private actor LockedFlag {
    private var cancelled = false
    private var waiters: [CheckedContinuation<Void, Error>] = []
    func cancel() {
        cancelled = true
        let waiters = self.waiters
        self.waiters.removeAll()
        for w in waiters { w.resume() }
    }
    func waitUntilCancelled() async throws {
        if cancelled { return }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            waiters.append(c)
        }
    }
}
