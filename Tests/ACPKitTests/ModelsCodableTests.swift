import Foundation
import Testing

@testable import ACPKit

// MARK: - ContentBlock

struct ContentBlockCase: Sendable {
    var name: String
    var json: String
}

@Test(
    "ContentBlock discriminators round-trip",
    arguments: [
        ContentBlockCase(
            name: "text",
            json: #"{"type":"text","text":"hi"}"#),
        ContentBlockCase(
            name: "image",
            json: #"{"type":"image","data":"AAA","mimeType":"image/png"}"#),
        ContentBlockCase(
            name: "audio",
            json: #"{"type":"audio","data":"AAA","mimeType":"audio/mp3"}"#),
        ContentBlockCase(
            name: "resource-link",
            json: #"{"type":"resource_link","name":"f","uri":"file:///f"}"#),
        ContentBlockCase(
            name: "resource-text",
            json: #"{"type":"resource","resource":{"text":"hi","uri":"file:///f"}}"#),
        ContentBlockCase(
            name: "resource-blob",
            json: #"{"type":"resource","resource":{"blob":"AAA","uri":"file:///f"}}"#),
    ])
func contentBlockRoundTrip(_ c: ContentBlockCase) throws {
    let block = try JSONDecoder.acpDecoder.decode(
        ContentBlock.self, from: Data(c.json.utf8))
    let reencoded = try JSONEncoder.acpEncoder.encode(block)
    let decodedAgain = try JSONDecoder.acpDecoder.decode(ContentBlock.self, from: reencoded)
    #expect(decodedAgain == block)
    // Discriminator preserved as snake_case.
    let value = try JSONDecoder.acpDecoder.decode(JSONValue.self, from: reencoded)
    #expect(value.objectValue?["type"]?.stringValue != nil)
}

@Test("ContentBlock unknown type throws", arguments: ["video", "bogus", ""])
func contentBlockUnknownType(tag: String) {
    let json = #"{"type":"\#(tag)","text":"hi"}"#
    #expect(throws: Error.self) {
        try JSONDecoder.acpDecoder.decode(ContentBlock.self, from: Data(json.utf8))
    }
}

@Test("ContentBlock _meta passthrough", arguments: [true, false])
func contentBlockMeta(hasMeta: Bool) throws {
    let meta: String = hasMeta ? #", "_meta":{"k":"v"}"# : ""
    let json = #"{"type":"text","text":"hi"\#(meta)}"#
    let block = try JSONDecoder.acpDecoder.decode(ContentBlock.self, from: Data(json.utf8))
    guard case .text(let text) = block else {
        Issue.record("expected text block")
        return
    }
    #expect((text.meta?["k"] == "v") == hasMeta)
}

// MARK: - SessionUpdate

@Test(
    "SessionUpdate discriminators round-trip",
    arguments: [
        (
            name: "agent-message",
            json: #"{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"hi"}}"#
        ),
        (
            name: "agent-thought",
            json: #"{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"hmm"}}"#
        ),
        (
            name: "tool-call",
            json: #"{"sessionUpdate":"tool_call","toolCallId":"t1","title":"run"}"#
        ),
        (name: "plan", json: #"{"sessionUpdate":"plan","entries":[]}"#),
        (
            name: "available-commands",
            json: #"{"sessionUpdate":"available_commands_update","availableCommands":[]}"#
        ),
        (
            name: "current-mode",
            json: #"{"sessionUpdate":"current_mode_update","currentModeId":"m"}"#
        ),
        (name: "usage", json: #"{"sessionUpdate":"usage_update","used":1,"size":10}"#),
        (name: "session-info", json: #"{"sessionUpdate":"session_info_update","title":"t"}"#),
    ])
func sessionUpdateRoundTrip(c: (name: String, json: String)) throws {
    let update = try JSONDecoder.acpDecoder.decode(
        SessionUpdate.self, from: Data(c.json.utf8))
    let reencoded = try JSONEncoder.acpEncoder.encode(update)
    let decodedAgain = try JSONDecoder.acpDecoder.decode(SessionUpdate.self, from: reencoded)
    #expect(decodedAgain == update)
}

@Test("SessionUpdate unknown tag throws", arguments: ["nope", "future_kind"])
func sessionUpdateUnknown(tag: String) {
    let json = #"{"sessionUpdate":"\#(tag)"}"#
    #expect(throws: Error.self) {
        try JSONDecoder.acpDecoder.decode(SessionUpdate.self, from: Data(json.utf8))
    }
}

// MARK: - SessionConfigOption

@Test(
    "SessionConfigOption variants",
    arguments: [
        (name: "boolean", json: #"{"id":"o","name":"N","type":"boolean","currentValue":true}"#),
        (
            name: "select-ungrouped",
            json:
                #"{"id":"o","name":"N","type":"select","currentValue":"v","options":[{"value":"v","name":"V"}]}"#
        ),
        (
            name: "select-grouped",
            json:
                #"{"id":"o","name":"N","type":"select","currentValue":"v","options":[{"group":"g","name":"G","options":[{"value":"v","name":"V"}]}]}"#
        ),
    ])
func sessionConfigOptionVariants(c: (name: String, json: String)) throws {
    let option = try JSONDecoder.acpDecoder.decode(
        SessionConfigOption.self, from: Data(c.json.utf8))
    let reencoded = try JSONEncoder.acpEncoder.encode(option)
    #expect(try JSONDecoder.acpDecoder.decode(SessionConfigOption.self, from: reencoded) == option)
}

@Test(
    "SessionConfigOptionCategory other preserved",
    arguments: [
        "mode", "model", "model_config", "thought_level", "future_custom",
    ])
func configCategoryRoundTrip(raw: String) throws {
    let category = SessionConfigOptionCategory(rawValue: raw)
    let data = try JSONEncoder.acpEncoder.encode(category)
    #expect(
        try JSONDecoder.acpDecoder.decode(
            SessionConfigOptionCategory.self, from: data) == category)
    #expect(category.rawValue == raw)
}

@Test(
    "SetSessionConfigOptionValue shapes",
    arguments: [
        (
            name: "valueId-default", json: #"{"sessionId":"s","configId":"c","value":"v"}"#,
            isBool: false
        ),
        (
            name: "boolean",
            json: #"{"sessionId":"s","configId":"c","type":"boolean","value":true}"#, isBool: true
        ),
        (
            name: "unknown-type-falls-back",
            json: #"{"sessionId":"s","configId":"c","type":"future","value":"v"}"#, isBool: false
        ),
    ])
func setConfigOptionValue(c: (name: String, json: String, isBool: Bool)) throws {
    let req = try JSONDecoder.acpDecoder.decode(
        SetSessionConfigOptionRequest.self, from: Data(c.json.utf8))
    switch req.value {
    case .boolean: #expect(c.isBool)
    case .valueId: #expect(!c.isBool)
    }
    #expect(
        try JSONDecoder.acpDecoder.decode(
            SetSessionConfigOptionRequest.self,
            from: try JSONEncoder.acpEncoder.encode(req)) == req)
}

// MARK: - McpServer / AuthMethod polymorphism

@Test(
    "McpServer variants",
    arguments: [
        (name: "stdio-default", json: #"{"name":"s","command":"c","args":[],"env":[]}"#),
        (name: "http", json: #"{"type":"http","name":"s","url":"https://x","headers":[]}"#),
        (name: "sse", json: #"{"type":"sse","name":"s","url":"https://x","headers":[]}"#),
    ])
func mcpServerVariants(c: (name: String, json: String)) throws {
    let server = try JSONDecoder.acpDecoder.decode(McpServer.self, from: Data(c.json.utf8))
    let reencoded = try JSONEncoder.acpEncoder.encode(server)
    #expect(try JSONDecoder.acpDecoder.decode(McpServer.self, from: reencoded) == server)
}

@Test(
    "AuthMethod variants",
    arguments: [
        (name: "agent-default", json: #"{"id":"a","name":"N"}"#, isTerminal: false),
        (name: "terminal", json: #"{"type":"terminal","id":"a","name":"N"}"#, isTerminal: true),
    ])
func authMethodVariants(c: (name: String, json: String, isTerminal: Bool)) throws {
    let method = try JSONDecoder.acpDecoder.decode(AuthMethod.self, from: Data(c.json.utf8))
    switch method {
    case .terminal: #expect(c.isTerminal)
    case .agent: #expect(!c.isTerminal)
    }
}

// MARK: - Capability defaults and ToolKind

@Test("capability defaults decode empty object", arguments: ["client", "agent"])
func capabilityDefaults(kind: String) throws {
    if kind == "client" {
        let caps = try JSONDecoder.acpDecoder.decode(
            ClientCapabilities.self, from: Data("{}".utf8))
        #expect(caps == ClientCapabilities())
    } else {
        let caps = try JSONDecoder.acpDecoder.decode(
            AgentCapabilities.self, from: Data("{}".utf8))
        #expect(caps == AgentCapabilities())
    }
}

@Test("permission outcome codec", arguments: ["cancelled", "selected"])
func permissionOutcome(kind: String) throws {
    let json: String =
        kind == "cancelled"
        ? #"{"outcome":{"outcome":"cancelled"}}"#
        : #"{"outcome":{"outcome":"selected","optionId":"o"}}"#
    let response = try JSONDecoder.acpDecoder.decode(
        RequestPermissionResponse.self, from: Data(json.utf8))
    #expect(
        try JSONDecoder.acpDecoder.decode(
            RequestPermissionResponse.self,
            from: try JSONEncoder.acpEncoder.encode(response)) == response)
}

@Test(
    "ToolKind snake_case",
    arguments: [
        (raw: "switch_mode", expected: ToolKind.switchMode),
        (raw: "read", expected: ToolKind.read),
        (raw: "other", expected: ToolKind.other),
    ])
func toolKindCases(c: (raw: String, expected: ToolKind)) throws {
    #expect(
        try JSONDecoder.acpDecoder.decode(
            ToolKind.self, from: Data(#""\#(c.raw)""#.utf8)) == c.expected)
}
