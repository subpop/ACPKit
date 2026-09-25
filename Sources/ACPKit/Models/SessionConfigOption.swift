import Foundation

/// Semantic category for a session configuration option. Open string enum: known categories
/// plus an `.other` fallback for forward-compatibility with unrecognized values.
public enum SessionConfigOptionCategory: Sendable, Equatable, RawRepresentable {
    case mode
    case model
    case modelConfig
    case thoughtLevel
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "mode": self = .mode
        case "model": self = .model
        case "model_config": self = .modelConfig
        case "thought_level": self = .thoughtLevel
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .mode: return "mode"
        case .model: return "model"
        case .modelConfig: return "model_config"
        case .thoughtLevel: return "thought_level"
        case .other(let value): return value
        }
    }
}

extension SessionConfigOptionCategory: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct SessionConfigSelectOption: Sendable, Equatable, Codable {
    public var value: SessionConfigValueId
    public var name: String
    public var description: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case value, name, description
        case meta = "_meta"
    }

    public init(
        value: SessionConfigValueId, name: String, description: String? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.value = value
        self.name = name
        self.description = description
        self.meta = meta
    }
}

public struct SessionConfigSelectGroup: Sendable, Equatable, Codable {
    public var group: SessionConfigGroupId
    public var name: String
    public var options: [SessionConfigSelectOption]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case group, name, options
        case meta = "_meta"
    }

    public init(
        group: SessionConfigGroupId,
        name: String,
        options: [SessionConfigSelectOption],
        meta: [String: JSONValue]? = nil
    ) {
        self.group = group
        self.name = name
        self.options = options
        self.meta = meta
    }
}

/// The set of selectable values for a `select`-type `SessionConfigOption`. An untagged union
/// of two array shapes, disambiguated by attempting the ungrouped shape first.
public enum SessionConfigSelectOptions: Sendable, Equatable {
    case ungrouped([SessionConfigSelectOption])
    case grouped([SessionConfigSelectGroup])
}

extension SessionConfigSelectOptions: Codable {
    public init(from decoder: Decoder) throws {
        if let options = try? [SessionConfigSelectOption](from: decoder) {
            self = .ungrouped(options)
            return
        }
        self = .grouped(try [SessionConfigSelectGroup](from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .ungrouped(let options): try options.encode(to: encoder)
        case .grouped(let groups): try groups.encode(to: encoder)
        }
    }
}

/// A single-value selector (dropdown) session configuration option payload.
public struct SessionConfigSelect: Sendable, Equatable, Codable {
    public var currentValue: SessionConfigValueId
    public var options: SessionConfigSelectOptions

    public init(currentValue: SessionConfigValueId, options: SessionConfigSelectOptions) {
        self.currentValue = currentValue
        self.options = options
    }
}

/// A boolean on/off toggle session configuration option payload.
public struct SessionConfigBoolean: Sendable, Equatable, Codable {
    public var currentValue: Bool

    public init(currentValue: Bool) {
        self.currentValue = currentValue
    }
}

/// A session configuration option selector and its current state. A Pattern-B hybrid: common
/// base fields plus a `"type"`-discriminated variant delta (`select` or `boolean`).
public enum SessionConfigOption: Sendable, Equatable {
    case select(
        id: SessionConfigId, name: String, description: String?,
        category: SessionConfigOptionCategory?, select: SessionConfigSelect,
        meta: [String: JSONValue]?)
    case boolean(
        id: SessionConfigId, name: String, description: String?,
        category: SessionConfigOptionCategory?, boolean: SessionConfigBoolean,
        meta: [String: JSONValue]?)
}

extension SessionConfigOption: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, type
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(SessionConfigId.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        let category = try container.decodeIfPresent(
            SessionConfigOptionCategory.self, forKey: .category)
        let meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "select":
            self = .select(
                id: id, name: name, description: description, category: category,
                select: try SessionConfigSelect(from: decoder), meta: meta
            )
        case "boolean":
            self = .boolean(
                id: id, name: name, description: description, category: category,
                boolean: try SessionConfigBoolean(from: decoder), meta: meta
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown SessionConfigOption type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .select(let id, let name, let description, let category, let select, let meta):
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(meta, forKey: .meta)
            try container.encode("select", forKey: .type)
            try select.encode(to: encoder)
        case .boolean(let id, let name, let description, let category, let boolean, let meta):
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(meta, forKey: .meta)
            try container.encode("boolean", forKey: .type)
            try boolean.encode(to: encoder)
        }
    }
}

// MARK: - SetSessionConfigOption

/// Request to update a session configuration option's value. Values may be a plain
/// `SessionConfigValueId` (the default when `type` is absent, or when `type` is an unrecognized
/// string) or a `Bool` (when `type == "boolean"`).
public enum SetSessionConfigOptionValue: Sendable, Equatable {
    case valueId(SessionConfigValueId)
    case boolean(Bool)
}

public struct SetSessionConfigOptionRequest: Sendable, Equatable {
    public var sessionId: SessionId
    public var configId: SessionConfigId
    public var value: SetSessionConfigOptionValue
    public var meta: [String: JSONValue]?

    public init(
        sessionId: SessionId,
        configId: SessionConfigId,
        value: SetSessionConfigOptionValue,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.configId = configId
        self.value = value
        self.meta = meta
    }
}

extension SetSessionConfigOptionRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case sessionId, configId, type, value
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(SessionId.self, forKey: .sessionId)
        configId = try container.decode(SessionConfigId.self, forKey: .configId)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        if type == "boolean" {
            value = .boolean(try container.decode(Bool.self, forKey: .value))
        } else {
            value = .valueId(try container.decode(SessionConfigValueId.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(configId, forKey: .configId)
        try container.encodeIfPresent(meta, forKey: .meta)
        switch value {
        case .valueId(let id):
            try container.encode(id, forKey: .value)
        case .boolean(let flag):
            try container.encode("boolean", forKey: .type)
            try container.encode(flag, forKey: .value)
        }
    }
}

public struct SetSessionConfigOptionResponse: Sendable, Equatable, Codable {
    public var configOptions: [SessionConfigOption]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case configOptions
        case meta = "_meta"
    }

    public init(configOptions: [SessionConfigOption], meta: [String: JSONValue]? = nil) {
        self.configOptions = configOptions
        self.meta = meta
    }
}
