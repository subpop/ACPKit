import Foundation

/// Metadata about the implementation of a client or agent.
public struct Implementation: Sendable, Equatable, Codable {
    public var name: String
    public var title: String?
    public var version: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, title, version
        case meta = "_meta"
    }

    public init(
        name: String, title: String? = nil, version: String, meta: [String: JSONValue]? = nil
    ) {
        self.name = name
        self.title = title
        self.version = version
        self.meta = meta
    }
}

public struct InitializeRequest: Sendable, Equatable {
    public var protocolVersion: ProtocolVersion
    public var clientCapabilities: ClientCapabilities
    public var clientInfo: Implementation?
    public var meta: [String: JSONValue]?

    public init(
        protocolVersion: ProtocolVersion,
        clientCapabilities: ClientCapabilities = ClientCapabilities(),
        clientInfo: Implementation? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.clientCapabilities = clientCapabilities
        self.clientInfo = clientInfo
        self.meta = meta
    }
}

extension InitializeRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case protocolVersion, clientCapabilities, clientInfo
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(ProtocolVersion.self, forKey: .protocolVersion)
        clientCapabilities = try container.decode(
            ClientCapabilities.self, forKey: .clientCapabilities, default: ClientCapabilities()
        )
        clientInfo = try container.decodeIfPresent(Implementation.self, forKey: .clientInfo)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct InitializeResponse: Sendable, Equatable {
    public var protocolVersion: ProtocolVersion
    public var agentCapabilities: AgentCapabilities
    public var authMethods: [AuthMethod]
    public var agentInfo: Implementation?
    public var meta: [String: JSONValue]?

    public init(
        protocolVersion: ProtocolVersion,
        agentCapabilities: AgentCapabilities = AgentCapabilities(),
        authMethods: [AuthMethod] = [],
        agentInfo: Implementation? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.agentCapabilities = agentCapabilities
        self.authMethods = authMethods
        self.agentInfo = agentInfo
        self.meta = meta
    }
}

extension InitializeResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case protocolVersion, agentCapabilities, authMethods, agentInfo
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(ProtocolVersion.self, forKey: .protocolVersion)
        agentCapabilities = try container.decode(
            AgentCapabilities.self, forKey: .agentCapabilities, default: AgentCapabilities()
        )
        authMethods = try container.decode([AuthMethod].self, forKey: .authMethods, default: [])
        agentInfo = try container.decodeIfPresent(Implementation.self, forKey: .agentInfo)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}
