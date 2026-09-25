import Foundation

public struct EnvVariable: Sendable, Equatable, Codable {
    public var name: String
    public var value: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, value
        case meta = "_meta"
    }

    public init(name: String, value: String, meta: [String: JSONValue]? = nil) {
        self.name = name
        self.value = value
        self.meta = meta
    }
}

public struct HttpHeader: Sendable, Equatable, Codable {
    public var name: String
    public var value: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, value
        case meta = "_meta"
    }

    public init(name: String, value: String, meta: [String: JSONValue]? = nil) {
        self.name = name
        self.value = value
        self.meta = meta
    }
}

public struct McpServerHttp: Sendable, Equatable, Codable {
    public var name: String
    public var url: String
    public var headers: [HttpHeader]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, url, headers
        case meta = "_meta"
    }

    public init(name: String, url: String, headers: [HttpHeader], meta: [String: JSONValue]? = nil)
    {
        self.name = name
        self.url = url
        self.headers = headers
        self.meta = meta
    }
}

public struct McpServerSse: Sendable, Equatable, Codable {
    public var name: String
    public var url: String
    public var headers: [HttpHeader]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, url, headers
        case meta = "_meta"
    }

    public init(name: String, url: String, headers: [HttpHeader], meta: [String: JSONValue]? = nil)
    {
        self.name = name
        self.url = url
        self.headers = headers
        self.meta = meta
    }
}

public struct McpServerStdio: Sendable, Equatable, Codable {
    public var name: String
    public var command: String
    public var args: [String]
    public var env: [EnvVariable]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, command, args, env
        case meta = "_meta"
    }

    public init(
        name: String, command: String, args: [String], env: [EnvVariable],
        meta: [String: JSONValue]? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.meta = meta
    }
}

/// An MCP server configuration. An untagged union: `http`/`sse` variants carry an explicit
/// `"type"` field; `stdio` is the default variant used when `type` is absent.
public enum McpServer: Sendable, Equatable {
    case http(McpServerHttp)
    case sse(McpServerSse)
    case stdio(McpServerStdio)
}

extension McpServer: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        switch type {
        case "http":
            self = .http(try McpServerHttp(from: decoder))
        case "sse":
            self = .sse(try McpServerSse(from: decoder))
        default:
            self = .stdio(try McpServerStdio(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .http(let server):
            var container = encoder.container(keyedBy: TypeKey.self)
            try container.encode("http", forKey: .type)
            try server.encode(to: encoder)
        case .sse(let server):
            var container = encoder.container(keyedBy: TypeKey.self)
            try container.encode("sse", forKey: .type)
            try server.encode(to: encoder)
        case .stdio(let server):
            try server.encode(to: encoder)
        }
    }
}
