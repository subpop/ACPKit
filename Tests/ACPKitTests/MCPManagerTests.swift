import Foundation
import Testing

@testable import ACPKit

struct MCPErrorCase: Sendable {
    var name: String
    var error: MCPError
    var code: Int
}

@Test("MCPError codes and messages", arguments: [
    MCPErrorCase(name: "tool", error: .toolError("x"), code: -32002),
    MCPErrorCase(name: "config", error: .invalidServerConfig("x"), code: -32602),
    MCPErrorCase(name: "transport", error: .unsupportedTransport("x"), code: -32602),
    MCPErrorCase(name: "closed", error: .connectionClosed, code: -32000),
    MCPErrorCase(name: "response", error: .invalidResponse("x"), code: -32602),
])
func mcpErrorMapping(_ c: MCPErrorCase) {
    #expect(c.error.errorCode == c.code)
    #expect(!(c.error.errorMessage.isEmpty))
    #expect(c.error.errorDescription == c.error.errorMessage)
}

@Test("MCPClientManager skips unsupported servers", arguments: [
    (name: "http", server: McpServer.http(
        McpServerHttp(name: "h", url: "https://x", headers: []))),
    (name: "sse", server: McpServer.sse(
        McpServerSse(name: "s", url: "https://x", headers: []))),
])
func mcpManagerSkipsUnsupported(c: (name: String, server: McpServer)) async {
    let manager = MCPClientManager()
    let tools = await manager.connectAll(servers: [c.server])
    #expect(tools.isEmpty)
    #expect(await manager.tools.isEmpty)
    await manager.closeAll()
}

@Test("MCPClientManager callTool without connection throws", arguments: ["a", "b"])
func mcpManagerMissingClient(serverName: String) async {
    let manager = MCPClientManager()
    await #expect(throws: MCPError.connectionClosed) {
        try await manager.callTool(serverName: serverName, toolName: "t")
    }
    await manager.closeAll()
}

@Test("MCPCallToolResult combinedText", arguments: [
    (name: "joins", texts: ["a", "b"], expected: "a\nb"),
    (name: "skips-image", texts: [] as [String], expected: ""),
    (name: "empty", texts: [] as [String], expected: ""),
])
func mcpCombinedText(c: (name: String, texts: [String], expected: String)) {
    let content: [MCPToolContent] =
        c.name == "skips-image"
        ? [.image(data: "AAA", mimeType: "image/png"), .text("only")]
        : c.texts.map { .text($0) }
    let expected = c.name == "skips-image" ? "only" : c.expected
    #expect(MCPCallToolResult(content: content).combinedText == expected)
}

@Test("MCPToolDescription inputSchema defaults", arguments: [true, false])
func mcpToolSchemaDefault(hasSchema: Bool) throws {
    let json: String =
        hasSchema
        ? #"{"name":"t","inputSchema":{"type":"object"}}"#
        : #"{"name":"t"}"#
    let tool = try JSONDecoder.acpDecoder.decode(
        MCPToolDescription.self, from: Data(json.utf8))
    #expect(tool.name == "t")
    #expect(tool.inputSchema == (hasSchema
        ? .object(["type": "object"])
        : .object([:])))
}
