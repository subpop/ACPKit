import Foundation
import Testing

@testable import ACPKit

// MARK: - Tables

struct MCPConnectCase: Sendable {
    var name: String
    var serverVersion: String
}

struct MCPListToolsCase: Sendable {
    var name: String
    var page1: [String]
    var page2: [String]?
    var expected: [String]
}

struct MCPCallToolCase: Sendable {
    var name: String
    var content: [MCPToolContent]
    var isError: Bool
    /// Expected combined text on success; nil means the call must throw.
    var expected: String?
}

struct MCPServerInitiatedCase: Sendable {
    var name: String
    var method: String
}

struct MCPContentCodecCase: Sendable {
    var name: String
    var raw: JSONValue
    var expected: MCPToolContent
    var expectedText: String?
}

struct MCPQualifiedNameCase: Sendable {
    var name: String
    var serverName: String
    var toolName: String
    var expected: String
}

struct MCPStdioInitCase: Sendable {
    var name: String
    var command: String
    var shouldThrow: Bool
}

func mcpInitializeResult(version: String = mcpProtocolVersion) throws -> JSONValue {
    try JSONValue(
        encoding: MCPInitializeResult(
            protocolVersion: version,
            capabilities: MCPServerCapabilities(tools: MCPToolsCapability()),
            serverInfo: MCPServerInfo(name: "fake-server", version: "0.1.0")
        ))
}

// MARK: - connect

@Test(
    "connect handshake",
    arguments: [
        MCPConnectCase(name: "exact-version", serverVersion: mcpProtocolVersion),
        MCPConnectCase(name: "version-mismatch-still-connects", serverVersion: "1999-01-01"),
    ])
func mcpClientConnect(_ c: MCPConnectCase) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, _ in
        #expect(method == "initialize")
        return try mcpInitializeResult(version: c.serverVersion)
    }
    let client = MCPClient(transport: transport)
    let result = try await client.connect()
    #expect(result.serverInfo.name == "fake-server")
    #expect(await client.isConnected)
    await client.close()
}

// MARK: - tools/list pagination

@Test(
    "listTools pagination",
    arguments: [
        MCPListToolsCase(name: "empty", page1: [], page2: nil, expected: []),
        MCPListToolsCase(name: "single-page", page1: ["a"], page2: nil, expected: ["a"]),
        MCPListToolsCase(name: "multi-page", page1: ["a"], page2: ["b"], expected: ["a", "b"]),
    ])
func mcpClientListTools(_ c: MCPListToolsCase) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, params in
        if method == "initialize" { return try mcpInitializeResult() }
        #expect(method == "tools/list")
        let request = try params?.decode(as: MCPListToolsRequest.self)
        if request?.cursor == nil {
            return try JSONValue(
                encoding: MCPListToolsResult(
                    tools: c.page1.map { MCPToolDescription(name: $0) },
                    nextCursor: c.page2 == nil ? nil : "page2"
                ))
        }
        return try JSONValue(
            encoding: MCPListToolsResult(
                tools: (c.page2 ?? []).map { MCPToolDescription(name: $0) }
            ))
    }
    let client = MCPClient(transport: transport)
    try await client.connect()
    let tools = try await client.listTools()
    #expect(tools.map(\.name) == c.expected)
    await client.close()
}

// MARK: - tools/call

@Test(
    "callTool text and errors",
    arguments: [
        MCPCallToolCase(
            name: "single-text", content: [.text("hello, ada")], isError: false,
            expected: "hello, ada"),
        MCPCallToolCase(
            name: "joins-multiple-text", content: [.text("a"), .text("b")], isError: false,
            expected: "a\nb"),
        MCPCallToolCase(
            name: "image-only-combines-empty",
            content: [.image(data: "AAA", mimeType: "image/png")],
            isError: false, expected: ""),
        MCPCallToolCase(
            name: "unknown-audio-falls-back-to-text",
            content: [
                .unknown(["type": "audio", "data": "AAA", "mimeType": "audio/mp3", "text": "aud"])
            ],
            isError: false, expected: "aud"),
        MCPCallToolCase(
            name: "isError-throws", content: [.text("boom")], isError: true, expected: nil),
    ])
func mcpClientCallTool(_ c: MCPCallToolCase) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, _ in
        if method == "initialize" { return try mcpInitializeResult() }
        #expect(method == "tools/call")
        return try JSONValue(encoding: MCPCallToolResult(content: c.content, isError: c.isError))
    }
    let client = MCPClient(transport: transport)
    try await client.connect()
    if let expected = c.expected {
        let text = try await client.callToolText(name: "tool")
        #expect(text == expected)
    } else {
        await #expect(throws: MCPError.self) {
            try await client.callToolText(name: "tool")
        }
    }
    await client.close()
}

@Test("callTool error message", arguments: ["boom", ""])
func mcpClientCallToolErrorMessage(message: String) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, _ in
        if method == "initialize" { return try mcpInitializeResult() }
        return try JSONValue(encoding: MCPCallToolResult(content: [.text(message)], isError: true))
    }
    let client = MCPClient(transport: transport)
    try await client.connect()
    await #expect(throws: MCPError.toolError(message)) {
        try await client.callToolText(name: "bad")
    }
    await client.close()
}

// MARK: - Server-initiated requests

@Test(
    "answers server-initiated requests",
    arguments: [
        MCPServerInitiatedCase(name: "ping", method: "ping"),
        MCPServerInitiatedCase(name: "roots-list", method: "roots/list"),
    ])
func mcpClientAnswersServerRequests(_ c: MCPServerInitiatedCase) async throws {
    let transport = AutoRespondingTransport()
    transport.handler = { method, _ in
        if method == "initialize" { return try mcpInitializeResult() }
        return .object([:])
    }
    let client = MCPClient(transport: transport)
    try await client.connect()

    let id = RequestID.string("s-\(c.method)")
    let inbound = try rpcRequestData(id: id, method: c.method)
    transport.inject(inbound)
    let response = try await transport.awaitSent(matching: isResponseData(for: id))
    #expect(response.count > 0)
    await client.close()
}

// MARK: - Content codec

@Test(
    "tool content codec",
    arguments: [
        MCPContentCodecCase(
            name: "text", raw: ["type": "text", "text": "hi"],
            expected: .text("hi"), expectedText: "hi"),
        MCPContentCodecCase(
            name: "image", raw: ["type": "image", "data": "AAA", "mimeType": "image/png"],
            expected: .image(data: "AAA", mimeType: "image/png"), expectedText: nil),
        MCPContentCodecCase(
            name: "unknown-audio-round-trips",
            raw: ["type": "audio", "data": "AAA", "mimeType": "audio/mp3"],
            expected: .unknown(["type": "audio", "data": "AAA", "mimeType": "audio/mp3"]),
            expectedText: nil),
        MCPContentCodecCase(
            name: "missing-type-is-unknown",
            raw: ["data": "AAA"],
            expected: .unknown(["data": "AAA"]), expectedText: nil),
    ])
func mcpToolContentCodec(_ c: MCPContentCodecCase) throws {
    let data = try JSONEncoder.acpEncoder.encode(c.raw)
    let content = try JSONDecoder.acpDecoder.decode(MCPToolContent.self, from: data)
    #expect(content == c.expected)
    #expect(content.textValue == c.expectedText)
}

// MARK: - Namespacing

@Test(
    "namespaced tool qualified name",
    arguments: [
        MCPQualifiedNameCase(
            name: "basic", serverName: "fs", toolName: "read_file", expected: "fs__read_file"),
        MCPQualifiedNameCase(
            name: "dashes", serverName: "my-server", toolName: "do-thing",
            expected: "my-server__do-thing"),
        MCPQualifiedNameCase(
            name: "empty-tool", serverName: "s", toolName: "", expected: "s__"),
    ])
func mcpNamespacedToolName(_ c: MCPQualifiedNameCase) {
    let tool = MCPNamespacedTool(
        serverName: c.serverName, tool: MCPToolDescription(name: c.toolName))
    #expect(tool.qualifiedName == c.expected)
}

// MARK: - stdio init validation (table)

@Test(
    "stdio init validation",
    arguments: [
        MCPStdioInitCase(name: "empty-command-throws", command: "", shouldThrow: true),
        MCPStdioInitCase(name: "valid-command-ok", command: "/bin/cat", shouldThrow: false),
    ])
func mcpClientStdioInit(_ c: MCPStdioInitCase) throws {
    let server = McpServerStdio(name: "s", command: c.command, args: [], env: [])
    if c.shouldThrow {
        #expect(throws: MCPError.self) { try MCPClient(stdio: server) }
    } else {
        _ = try MCPClient(stdio: server)
    }
}

// MARK: - Timeouts

enum MCPTimeoutOperation: String, Sendable {
    case connect
    case listTools
    case callTool
}

struct MCPRequestTimeoutCase: Sendable {
    var name: String
    var operation: MCPTimeoutOperation
}

@Test(
    "mcp requests time out",
    arguments: [
        MCPRequestTimeoutCase(name: "connect", operation: .connect),
        MCPRequestTimeoutCase(name: "list-tools", operation: .listTools),
        MCPRequestTimeoutCase(name: "call-tool", operation: .callTool),
    ])
func mcpRequestTimeout(_ c: MCPRequestTimeoutCase) async throws {
    // CapturingTransport never answers, simulating a server that spawns yet
    // stays silent.
    let transport = CapturingTransport()
    let client = MCPClient(transport: transport)
    switch c.operation {
    case .connect:
        await #expect(throws: JSONRPCPeerError.timedOut) {
            try await client.connect(timeout: 0.05)
        }
        #expect(await client.isConnected == false)
    case .listTools:
        await #expect(throws: JSONRPCPeerError.timedOut) {
            try await client.listTools(timeout: 0.05)
        }
    case .callTool:
        await #expect(throws: JSONRPCPeerError.timedOut) {
            try await client.callToolText(name: "tool", timeout: 0.05)
        }
    }
    await client.close()
}

// MARK: - ProcessTransport echo over /bin/cat (not tabular: env-gated)

@Test func processTransportEchoesLines() async throws {
    guard FileManager.default.fileExists(atPath: "/bin/cat") else { return }
    let transport = ProcessTransport(command: "/bin/cat", args: ["-u"])
    try await transport.start()
    let payload = try JSONEncoder.acpEncoder.encode(["echo": "hello"])
    try await transport.send(payload)
    let echoed = try await withThrowingTaskGroup(of: Data.self) { group in
        group.addTask {
            for await msg in transport.messages {
                return msg
            }
            throw TableTestError.timedOut
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            throw TableTestError.timedOut
        }
        guard let first = try await group.next() else {
            throw TableTestError.timedOut
        }
        group.cancelAll()
        return first
    }
    #expect(echoed == payload)
    await transport.close()
}
