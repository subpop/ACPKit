import Foundation

public struct AuthMethodTerminal: Sendable, Equatable, Codable {
    public var id: AuthMethodId
    public var name: String
    public var description: String?
    public var args: [String]?
    public var env: [String: String]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, args, env
        case meta = "_meta"
    }

    public init(
        id: AuthMethodId,
        name: String,
        description: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.args = args
        self.env = env
        self.meta = meta
    }
}

public struct AuthMethodAgent: Sendable, Equatable, Codable {
    public var id: AuthMethodId
    public var name: String
    public var description: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case meta = "_meta"
    }

    public init(
        id: AuthMethodId, name: String, description: String? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.meta = meta
    }
}

/// Describes an available authentication method. An untagged union: the `terminal` variant
/// carries an explicit `"type": "terminal"` field; when `type` is absent, the method is
/// treated as `agent` (the default).
public enum AuthMethod: Sendable, Equatable {
    case terminal(AuthMethodTerminal)
    case agent(AuthMethodAgent)
}

extension AuthMethod: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        if type == "terminal" {
            self = .terminal(try AuthMethodTerminal(from: decoder))
        } else {
            self = .agent(try AuthMethodAgent(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .terminal(let method):
            var container = encoder.container(keyedBy: TypeKey.self)
            try container.encode("terminal", forKey: .type)
            try method.encode(to: encoder)
        case .agent(let method):
            try method.encode(to: encoder)
        }
    }
}

// MARK: - Authenticate / Logout

public struct AuthenticateRequest: Sendable, Equatable, Codable {
    public var methodId: AuthMethodId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case methodId
        case meta = "_meta"
    }

    public init(methodId: AuthMethodId, meta: [String: JSONValue]? = nil) {
        self.methodId = methodId
        self.meta = meta
    }
}

public struct AuthenticateResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct LogoutRequest: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct LogoutResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}
