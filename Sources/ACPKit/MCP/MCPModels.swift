import Foundation

/// The MCP protocol version this client proposes during the `initialize`
/// handshake. If the server answers with a different version we log it and
/// proceed (servers are expected to be backwards compatible across adjacent
/// spec revisions for the `tools` surface we use).
public let mcpProtocolVersion = "2025-11-25"

// MARK: - Client / server info

public struct MCPClientInfo: Sendable, Equatable, Codable {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    public static var `default`: MCPClientInfo {
        MCPClientInfo(name: "ACPKit", version: "1.0.0")
    }
}

public struct MCPServerInfo: Sendable, Equatable, Codable {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

// MARK: - Capabilities

public struct MCPClientCapabilities: Sendable, Equatable, Codable {
    public var roots: MCPRootsCapability?
    public var sampling: MCPSamplingCapability?

    public init(roots: MCPRootsCapability? = nil, sampling: MCPSamplingCapability? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

public struct MCPRootsCapability: Sendable, Equatable, Codable {
    public var listChanged: Bool

    public init(listChanged: Bool = false) {
        self.listChanged = listChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listChanged = try container.decode(Bool.self, forKey: .listChanged, default: false)
    }

    enum CodingKeys: String, CodingKey { case listChanged }
}

public struct MCPSamplingCapability: Sendable, Equatable, Codable {
    public init() {}
}

public struct MCPServerCapabilities: Sendable, Equatable, Codable {
    public var tools: MCPToolsCapability?
    public var resources: MCPResourcesCapability?
    public var prompts: MCPPromptsCapability?
    public var logging: MCPLoggingCapability?

    public init(
        tools: MCPToolsCapability? = nil,
        resources: MCPResourcesCapability? = nil,
        prompts: MCPPromptsCapability? = nil,
        logging: MCPLoggingCapability? = nil
    ) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
        self.logging = logging
    }
}

public struct MCPToolsCapability: Sendable, Equatable, Codable {
    public var listChanged: Bool

    public init(listChanged: Bool = false) {
        self.listChanged = listChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listChanged = try container.decode(Bool.self, forKey: .listChanged, default: false)
    }

    enum CodingKeys: String, CodingKey { case listChanged }
}

public struct MCPResourcesCapability: Sendable, Equatable, Codable {
    public var listChanged: Bool

    public init(listChanged: Bool = false) {
        self.listChanged = listChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listChanged = try container.decode(Bool.self, forKey: .listChanged, default: false)
    }

    enum CodingKeys: String, CodingKey { case listChanged }
}

public struct MCPPromptsCapability: Sendable, Equatable, Codable {
    public var listChanged: Bool

    public init(listChanged: Bool = false) {
        self.listChanged = listChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listChanged = try container.decode(Bool.self, forKey: .listChanged, default: false)
    }

    enum CodingKeys: String, CodingKey { case listChanged }
}

public struct MCPLoggingCapability: Sendable, Equatable, Codable {
    public init() {}
}

// MARK: - initialize

public struct MCPInitializeRequest: Sendable, Equatable, Codable {
    public var protocolVersion: String
    public var capabilities: MCPClientCapabilities
    public var clientInfo: MCPClientInfo

    public init(
        protocolVersion: String = mcpProtocolVersion,
        capabilities: MCPClientCapabilities = MCPClientCapabilities(),
        clientInfo: MCPClientInfo = .default
    ) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

public struct MCPInitializeResult: Sendable, Equatable, Codable {
    public var protocolVersion: String
    public var capabilities: MCPServerCapabilities
    public var serverInfo: MCPServerInfo

    public init(
        protocolVersion: String,
        capabilities: MCPServerCapabilities,
        serverInfo: MCPServerInfo
    ) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

// MARK: - tools/list

public struct MCPListToolsRequest: Sendable, Equatable, Codable {
    public var cursor: String?

    public init(cursor: String? = nil) {
        self.cursor = cursor
    }
}

public struct MCPToolDescription: Sendable, Equatable, Codable {
    public var name: String
    public var title: String?
    public var description: String?
    public var inputSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case name, title, description, inputSchema
    }

    public init(
        name: String,
        title: String? = nil,
        description: String? = nil,
        inputSchema: JSONValue = .object([:])
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        inputSchema = try container.decode(JSONValue.self, forKey: .inputSchema, default: .object([:]))
    }
}

public struct MCPListToolsResult: Sendable, Equatable, Codable {
    public var tools: [MCPToolDescription]
    public var nextCursor: String?

    public init(tools: [MCPToolDescription], nextCursor: String? = nil) {
        self.tools = tools
        self.nextCursor = nextCursor
    }
}

// MARK: - tools/call

public struct MCPCallToolRequest: Sendable, Equatable, Codable {
    public var name: String
    public var arguments: JSONValue?

    public init(name: String, arguments: JSONValue? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// A single content item in a `tools/call` result. `text` and `image` are
/// decoded structurally; any other `type` is preserved verbatim as `unknown`
/// so future content kinds survive the round-trip.
public enum MCPToolContent: Sendable, Equatable {
    case text(String)
    case image(data: String, mimeType: String)
    case unknown(JSONValue)
}

extension MCPToolContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType
    }

    public init(from decoder: Decoder) throws {
        // Peek at the discriminator first, keeping the raw value for fallback.
        let raw = try JSONValue(from: decoder)
        guard let object = raw.objectValue,
            let type = object["type"]?.stringValue
        else {
            self = .unknown(raw)
            return
        }
        switch type {
        case "text":
            let text = try raw.decode(as: MCPTextContent.self).text
            self = .text(text)
        case "image":
            let image = try raw.decode(as: MCPImageContent.self)
            self = .image(data: image.data, mimeType: image.mimeType)
        default:
            self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            try MCPTextContent(text: text).encode(to: encoder)
        case .image(let data, let mimeType):
            try MCPImageContent(data: data, mimeType: mimeType).encode(to: encoder)
        case .unknown(let raw):
            try raw.encode(to: encoder)
        }
    }

    /// Best-effort plain-text rendering of this content item, if it has one.
    public var textValue: String? {
        switch self {
        case .text(let text):
            return text
        case .image:
            return nil
        case .unknown(let raw):
            return raw.objectValue?["text"]?.stringValue
        }
    }
}

private struct MCPTextContent: Codable {
    var type: String = "text"
    var text: String
}

private struct MCPImageContent: Codable {
    var type: String = "image"
    var data: String
    var mimeType: String
}

public struct MCPCallToolResult: Sendable, Equatable, Codable {
    public var content: [MCPToolContent]
    public var isError: Bool

    enum CodingKeys: String, CodingKey { case content, isError }

    public init(content: [MCPToolContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode([MCPToolContent].self, forKey: .content, default: [])
        isError = try container.decode(Bool.self, forKey: .isError, default: false)
    }

    /// Concatenated text of all content items that carry text.
    public var combinedText: String {
        content.compactMap(\.textValue).joined(separator: "\n")
    }
}

// MARK: - ping / roots (client-side handlers)

public struct MCPPingResult: Sendable, Equatable, Codable {
    public init() {}

    public init(from decoder: Decoder) throws {
        // Accept `{}` (or any payload); nothing to decode.
        _ = try? JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try JSONValue.object([:]).encode(to: encoder)
    }
}

public struct MCPListRootsResult: Sendable, Equatable, Codable {
    public var roots: [JSONValue]

    public init(roots: [JSONValue] = []) {
        self.roots = roots
    }
}

// MARK: - Errors

/// Errors thrown by ``MCPClient`` and ``MCPClientManager``.
public enum MCPError: Error, Sendable, Equatable, LocalizedError, JSONRPCErrorConvertible {
    /// The server reported `isError: true` for a `tools/call`.
    case toolError(String)
    /// A stdio server entry was malformed (empty command).
    case invalidServerConfig(String)
    /// HTTP/SSE servers are not yet supported (no `HTTPTransport` yet).
    case unsupportedTransport(String)
    /// The transport closed mid-request.
    case connectionClosed
    /// The server's response could not be decoded.
    case invalidResponse(String)

    public var errorCode: Int {
        switch self {
        case .toolError:
            return -32002
        case .invalidServerConfig, .unsupportedTransport, .invalidResponse:
            return -32602
        case .connectionClosed:
            return -32000
        }
    }

    public var errorMessage: String {
        switch self {
        case .toolError(let message):
            return "MCP tool error: \(message)"
        case .invalidServerConfig(let message):
            return "Invalid MCP server config: \(message)"
        case .unsupportedTransport(let message):
            return "Unsupported MCP transport: \(message)"
        case .connectionClosed:
            return "MCP connection closed"
        case .invalidResponse(let message):
            return "Invalid MCP response: \(message)"
        }
    }

    public var errorDescription: String? { errorMessage }
}
