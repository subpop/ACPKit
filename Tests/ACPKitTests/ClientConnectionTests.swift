import Foundation
import Testing

@testable import ACPKit

private struct StubClient: Client, Sendable {
    var capabilities = ClientCapabilities(
        fs: FileSystemCapabilities(readTextFile: true, writeTextFile: true),
        terminal: true)
    var permissionOutcome = RequestPermissionOutcome.cancelled
    var updates = UpdateLog()

    func requestPermission(
        request: RequestPermissionRequest
    ) async throws -> RequestPermissionResponse {
        RequestPermissionResponse(outcome: permissionOutcome)
    }

    func sessionUpdate(_ notification: SessionNotification) async {
        await updates.append(notification)
    }

    func readTextFile(request: ReadTextFileRequest) async throws -> ReadTextFileResponse {
        ReadTextFileResponse(content: "contents-of-\(request.path)")
    }

    func createTerminal(request: CreateTerminalRequest) async throws -> CreateTerminalResponse {
        CreateTerminalResponse(terminalId: "t1")
    }
}

private actor UpdateLog {
    private var items: [SessionNotification] = []
    init() {}
    func append(_ n: SessionNotification) { items.append(n) }
    func count() -> Int { items.count }
}

private func sessionNotifData(sessionId: String) throws -> JSONValue {
    try JSONValue(
        encoding: SessionNotification(
            sessionId: SessionId(sessionId),
            update: .agentMessageChunk(ContentChunk(content: .text(TextContent(text: "hi"))))))
}

// MARK: - Incoming dispatch

@Test(
    "client handles agent requests",
    arguments: [
        (
            name: "permission", method: "session/request_permission",
            params: #"{"sessionId":"s","toolCall":{"toolCallId":"t"},"options":[]}"#
        ),
        (
            name: "read-file", method: "fs/read_text_file",
            params: #"{"sessionId":"s","path":"/tmp/f"}"#
        ),
        (
            name: "create-terminal", method: "terminal/create",
            params: #"{"sessionId":"s","command":"echo"}"#
        ),
    ])
func clientIncomingDispatch(c: (name: String, method: String, params: String)) async throws {
    let transport = CapturingTransport()
    let connection = ClientConnection(transport: transport, client: StubClient())
    try await connection.start()
    let id = RequestID.string("in-\(c.name)")
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
    "client unimplemented maps to -32601",
    arguments: [
        (
            name: "write", method: "fs/write_text_file",
            params: #"{"sessionId":"s","path":"/tmp/f","content":"x"}"#
        ),
        (
            name: "output", method: "terminal/output",
            params: #"{"sessionId":"s","terminalId":"t"}"#
        ),
        (
            name: "kill", method: "terminal/kill",
            params: #"{"sessionId":"s","terminalId":"t"}"#
        ),
        (
            name: "release", method: "terminal/release",
            params: #"{"sessionId":"s","terminalId":"t"}"#
        ),
        (
            name: "wait", method: "terminal/wait_for_exit",
            params: #"{"sessionId":"s","terminalId":"t"}"#
        ),
    ])
func clientNotImplementedMapping(c: (name: String, method: String, params: String)) async throws {
    struct EmptyClient: Client, Sendable {
        var capabilities = ClientCapabilities()
        func requestPermission(
            request: RequestPermissionRequest
        ) async throws -> RequestPermissionResponse {
            RequestPermissionResponse(outcome: .cancelled)
        }
        func sessionUpdate(_ notification: SessionNotification) async {}
    }
    let transport = CapturingTransport()
    let connection = ClientConnection(transport: transport, client: EmptyClient())
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

@Test(
    "client missing params is -32602",
    arguments: [
        "session/request_permission", "fs/read_text_file", "terminal/create",
    ])
func clientMissingParams(method: String) async throws {
    let transport = CapturingTransport()
    let connection = ClientConnection(transport: transport, client: StubClient())
    try await connection.start()
    let id = RequestID.string("mp-\(method)")
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

@Test("client forwards session/update without reply", arguments: ["s1", "s2"])
func clientSessionUpdate(sessionId: String) async throws {
    let log = UpdateLog()
    let client = StubClient(updates: log)
    let transport = CapturingTransport()
    let connection = ClientConnection(transport: transport, client: client)
    try await connection.start()
    transport.inject(
        try rpcNotificationData(
            method: "session/update", params: try sessionNotifData(sessionId: sessionId)))
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while await log.count() == 0, DispatchTime.now().uptimeNanoseconds < deadline {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(await log.count() == 1)
    #expect(transport.sent.isEmpty)
    await connection.close()
}

// MARK: - Outgoing calls

@Test(
    "client outgoing session calls",
    arguments: [
        (name: "new", method: "session/new"),
        (name: "prompt", method: "session/prompt"),
        (name: "list", method: "session/list"),
        (name: "close", method: "session/close"),
    ])
func clientOutgoingCalls(c: (name: String, method: String)) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, _ in
        #expect(method == c.method)
        switch c.name {
        case "new":
            return try JSONValue(encoding: NewSessionResponse(sessionId: "s1"))
        case "prompt":
            return try JSONValue(encoding: PromptResponse(stopReason: .endTurn))
        case "list":
            return try JSONValue(encoding: ListSessionsResponse(sessions: []))
        default:
            return try JSONValue(encoding: CloseSessionResponse())
        }
    }
    let connection = ClientConnection(transport: transport, client: StubClient())
    try await connection.start()
    switch c.name {
    case "new":
        let resp = try await connection.newSession(NewSessionRequest(cwd: "/tmp", mcpServers: []))
        #expect(resp.sessionId == "s1")
    case "prompt":
        let resp = try await connection.prompt(
            PromptRequest(
                sessionId: "s1", prompt: [.text(TextContent(text: "hi"))]))
        #expect(resp.stopReason == .endTurn)
    case "list":
        let resp = try await connection.listSessions(ListSessionsRequest())
        #expect(resp.sessions.isEmpty)
    default:
        _ = try await connection.closeSession(CloseSessionRequest(sessionId: "s1"))
    }
    await connection.close()
}

@Test("client cancel sends notification", arguments: ["s1", "s2"])
func clientCancel(sessionId: String) async throws {
    let transport = AutoRespondingTransport()
    let connection = ClientConnection(transport: transport, client: StubClient())
    try await connection.start()
    try await connection.cancel(sessionId: SessionId(sessionId))
    let found = transport.sent.contains { data in
        (try? JSONRPCMessage(data: data)).map {
            if case .notification(let n) = $0 { return n.method == "session/cancel" }
            return false
        } ?? false
    }
    #expect(found)
    await connection.close()
}
