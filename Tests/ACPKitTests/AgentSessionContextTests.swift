import Foundation
import Testing

@testable import ACPKit

struct GatingCase: Sendable {
    var name: String
    var fsRead: Bool
    var fsWrite: Bool
    var terminal: Bool
}

/// Agent stub that exercises one context capability per prompt and reports
/// the outcome back through the prompt response meta.
private struct GatingAgent: Agent, Sendable {
    var probe: String
    var capabilities = AgentCapabilities()

    func createSession(request: NewSessionRequest) async throws -> NewSessionResponse {
        NewSessionResponse(sessionId: "s1")
    }

    func handlePrompt(request: PromptRequest, context: AgentContext) async throws -> PromptResponse
    {
        let outcome: String
        switch probe {
        case "read":
            do {
                _ = try await context.readTextFile(path: "/tmp/f")
                outcome = "ok"
            } catch { outcome = "denied" }
        case "write":
            do {
                try await context.writeTextFile(path: "/tmp/f", content: "x")
                outcome = "ok"
            } catch { outcome = "denied" }
        case "terminal":
            do {
                _ = try await context.createTerminal(command: "echo")
                outcome = "ok"
            } catch { outcome = "denied" }
        case "permission":
            let toolCall = ToolCallUpdate(toolCallId: "t")
            let response = try await context.requestPermission(
                toolCall: toolCall, options: [])
            outcome = response == .cancelled ? "cancelled" : "selected"
        case "update":
            try await context.sendTextMessage("hello")
            outcome = "sent"
        default:
            outcome = "unknown"
        }
        return PromptResponse(
            stopReason: .endTurn, meta: ["probe": .string(outcome)])
    }
}

private func drivePrompt(
    probe: String, clientCaps: ClientCapabilities
) async throws -> String {
    let (agentEnd, clientEnd) = makeLoopbackPair()
    let connection = AgentConnection(
        transport: agentEnd, agent: GatingAgent(probe: probe))

    // Client-side driver peer answering agent->client calls.
    let driver = JSONRPCPeer(transport: clientEnd)
    await driver.onRequest(method: "session/request_permission") { _ in
        try JSONValue(encoding: RequestPermissionResponse(outcome: .cancelled))
    }
    await driver.onRequest(method: "fs/read_text_file") { _ in
        try JSONValue(encoding: ReadTextFileResponse(content: "file-bytes"))
    }
    await driver.onRequest(method: "fs/write_text_file") { _ in
        try JSONValue(encoding: WriteTextFileResponse())
    }
    await driver.onRequest(method: "terminal/create") { _ in
        try JSONValue(encoding: CreateTerminalResponse(terminalId: "t1"))
    }
    let notified = NotifiedFlag()
    await driver.onNotification(method: "session/update") { _ in
        await notified.set()
    }

    try await connection.start()
    try await driver.start()

    let initParams = try JSONValue(
        encoding: InitializeRequest(
            protocolVersion: acpProtocolVersion, clientCapabilities: clientCaps))
    _ = try await driver.sendRequest(
        method: "initialize", params: initParams, as: InitializeResponse.self)
    let prompt = try await driver.sendRequest(
        method: "session/prompt",
        params: PromptRequest(sessionId: "s1", prompt: [.text(TextContent(text: "go"))]),
        as: PromptResponse.self)
    await connection.close()
    await driver.close()
    return prompt.meta?["probe"]?.stringValue ?? "missing"
}

private actor NotifiedFlag {
    private var value = false
    func set() { value = true }
}

// MARK: - Capability gating table

@Test(
    "context capability gating",
    arguments: [
        (
            name: "read-allowed", probe: "read",
            caps: ClientCapabilities(
                fs: FileSystemCapabilities(readTextFile: true), terminal: false),
            expected: "ok"
        ),
        (
            name: "read-denied", probe: "read",
            caps: ClientCapabilities(fs: FileSystemCapabilities(), terminal: false),
            expected: "denied"
        ),
        (
            name: "write-allowed", probe: "write",
            caps: ClientCapabilities(
                fs: FileSystemCapabilities(writeTextFile: true), terminal: false),
            expected: "ok"
        ),
        (
            name: "write-denied", probe: "write",
            caps: ClientCapabilities(fs: FileSystemCapabilities(), terminal: false),
            expected: "denied"
        ),
        (
            name: "terminal-allowed", probe: "terminal",
            caps: ClientCapabilities(terminal: true), expected: "ok"
        ),
        (
            name: "terminal-denied", probe: "terminal",
            caps: ClientCapabilities(terminal: false), expected: "denied"
        ),
    ])
func contextGating(
    c: (name: String, probe: String, caps: ClientCapabilities, expected: String)
) async throws {
    #expect(try await drivePrompt(probe: c.probe, clientCaps: c.caps) == c.expected)
}

// MARK: - Forwarding table

@Test("context forwarding", arguments: ["permission", "update"])
func contextForwarding(probe: String) async throws {
    let expected = probe == "permission" ? "cancelled" : "sent"
    let caps = ClientCapabilities(
        fs: FileSystemCapabilities(readTextFile: true, writeTextFile: true),
        terminal: true)
    #expect(try await drivePrompt(probe: probe, clientCaps: caps) == expected)
}
