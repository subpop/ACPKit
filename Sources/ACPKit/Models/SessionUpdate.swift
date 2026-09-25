import Foundation

// MARK: - Plan

/// An execution plan for accomplishing complex tasks, reported by the agent to give the
/// client visibility into its execution strategy.
public struct Plan: Sendable, Equatable, Codable {
    public var entries: [PlanEntry]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case entries
        case meta = "_meta"
    }

    public init(entries: [PlanEntry], meta: [String: JSONValue]? = nil) {
        self.entries = entries
        self.meta = meta
    }
}

// MARK: - Content chunk

/// A streamed item of content, shared by the `user_message_chunk`, `agent_message_chunk`, and
/// `agent_thought_chunk` session update variants.
public struct ContentChunk: Sendable, Equatable, Codable {
    public var content: ContentBlock
    public var messageId: MessageId?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case content, messageId
        case meta = "_meta"
    }

    public init(
        content: ContentBlock, messageId: MessageId? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.content = content
        self.messageId = messageId
        self.meta = meta
    }
}

// MARK: - Available commands

public struct UnstructuredCommandInput: Sendable, Equatable, Codable {
    public var hint: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case hint
        case meta = "_meta"
    }

    public init(hint: String, meta: [String: JSONValue]? = nil) {
        self.hint = hint
        self.meta = meta
    }
}

/// The input shape for an `AvailableCommand`. Currently the schema defines only a single
/// (`UnstructuredCommandInput`) variant.
public typealias AvailableCommandInput = UnstructuredCommandInput

public struct AvailableCommand: Sendable, Equatable, Codable {
    public var name: String
    public var description: String
    public var input: AvailableCommandInput?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name, description, input
        case meta = "_meta"
    }

    public init(
        name: String,
        description: String,
        input: AvailableCommandInput? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.name = name
        self.description = description
        self.input = input
        self.meta = meta
    }
}

// MARK: - Usage update

public struct Cost: Sendable, Equatable, Codable {
    public var amount: Double
    public var currency: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case amount, currency
        case meta = "_meta"
    }

    public init(amount: Double, currency: String, meta: [String: JSONValue]? = nil) {
        self.amount = amount
        self.currency = currency
        self.meta = meta
    }
}

public struct UsageUpdate: Sendable, Equatable, Codable {
    public var used: UInt64
    public var size: UInt64
    public var cost: Cost?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case used, size, cost
        case meta = "_meta"
    }

    public init(used: UInt64, size: UInt64, cost: Cost? = nil, meta: [String: JSONValue]? = nil) {
        self.used = used
        self.size = size
        self.cost = cost
        self.meta = meta
    }
}

// MARK: - SessionUpdate

/// A real-time update sent from the agent to the client during `session/prompt` processing.
/// A tagged union discriminated by the wire-level `"sessionUpdate"` field.
///
/// Note: unlike `ContentBlock`'s payload types, the payload structs used here (`ContentChunk`,
/// `ToolCall`, `ToolCallUpdate`, `Plan`) do NOT store the `sessionUpdate` discriminator
/// themselves, since they are also used bare elsewhere in the protocol (e.g.
/// `RequestPermissionRequest.toolCall: ToolCallUpdate`). The discriminator is spliced in/out
/// only by this enum's own `Codable` implementation.
public enum SessionUpdate: Sendable, Equatable {
    case userMessageChunk(ContentChunk)
    case agentMessageChunk(ContentChunk)
    case agentThoughtChunk(ContentChunk)
    case toolCall(ToolCall)
    case toolCallUpdate(ToolCallUpdate)
    case plan(Plan)
    case availableCommandsUpdate(
        availableCommands: [AvailableCommand], meta: [String: JSONValue]? = nil)
    case currentModeUpdate(currentModeId: SessionModeId, meta: [String: JSONValue]? = nil)
    case configOptionUpdate(configOptions: [SessionConfigOption], meta: [String: JSONValue]? = nil)
    case sessionInfoUpdate(title: String?, updatedAt: String?, meta: [String: JSONValue]? = nil)
    case usageUpdate(UsageUpdate)
}

extension SessionUpdate: Codable {
    private enum CodingKeys: String, CodingKey {
        case sessionUpdate
        case availableCommands
        case currentModeId
        case configOptions
        case title
        case updatedAt
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(String.self, forKey: .sessionUpdate)
        switch tag {
        case "user_message_chunk":
            self = .userMessageChunk(try ContentChunk(from: decoder))
        case "agent_message_chunk":
            self = .agentMessageChunk(try ContentChunk(from: decoder))
        case "agent_thought_chunk":
            self = .agentThoughtChunk(try ContentChunk(from: decoder))
        case "tool_call":
            self = .toolCall(try ToolCall(from: decoder))
        case "tool_call_update":
            self = .toolCallUpdate(try ToolCallUpdate(from: decoder))
        case "plan":
            self = .plan(try Plan(from: decoder))
        case "available_commands_update":
            self = .availableCommandsUpdate(
                availableCommands: try container.decode(
                    [AvailableCommand].self, forKey: .availableCommands),
                meta: try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
            )
        case "current_mode_update":
            self = .currentModeUpdate(
                currentModeId: try container.decode(SessionModeId.self, forKey: .currentModeId),
                meta: try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
            )
        case "config_option_update":
            self = .configOptionUpdate(
                configOptions: try container.decode(
                    [SessionConfigOption].self, forKey: .configOptions),
                meta: try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
            )
        case "session_info_update":
            self = .sessionInfoUpdate(
                title: try container.decodeIfPresent(String.self, forKey: .title),
                updatedAt: try container.decodeIfPresent(String.self, forKey: .updatedAt),
                meta: try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
            )
        case "usage_update":
            self = .usageUpdate(try UsageUpdate(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .sessionUpdate, in: container,
                debugDescription: "Unknown SessionUpdate type: \(tag)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .userMessageChunk(let chunk):
            try container.encode("user_message_chunk", forKey: .sessionUpdate)
            try chunk.encode(to: encoder)
        case .agentMessageChunk(let chunk):
            try container.encode("agent_message_chunk", forKey: .sessionUpdate)
            try chunk.encode(to: encoder)
        case .agentThoughtChunk(let chunk):
            try container.encode("agent_thought_chunk", forKey: .sessionUpdate)
            try chunk.encode(to: encoder)
        case .toolCall(let call):
            try container.encode("tool_call", forKey: .sessionUpdate)
            try call.encode(to: encoder)
        case .toolCallUpdate(let update):
            try container.encode("tool_call_update", forKey: .sessionUpdate)
            try update.encode(to: encoder)
        case .plan(let plan):
            try container.encode("plan", forKey: .sessionUpdate)
            try plan.encode(to: encoder)
        case .availableCommandsUpdate(let commands, let meta):
            try container.encode("available_commands_update", forKey: .sessionUpdate)
            try container.encode(commands, forKey: .availableCommands)
            try container.encodeIfPresent(meta, forKey: .meta)
        case .currentModeUpdate(let modeId, let meta):
            try container.encode("current_mode_update", forKey: .sessionUpdate)
            try container.encode(modeId, forKey: .currentModeId)
            try container.encodeIfPresent(meta, forKey: .meta)
        case .configOptionUpdate(let options, let meta):
            try container.encode("config_option_update", forKey: .sessionUpdate)
            try container.encode(options, forKey: .configOptions)
            try container.encodeIfPresent(meta, forKey: .meta)
        case .sessionInfoUpdate(let title, let updatedAt, let meta):
            try container.encode("session_info_update", forKey: .sessionUpdate)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(meta, forKey: .meta)
        case .usageUpdate(let usage):
            try container.encode("usage_update", forKey: .sessionUpdate)
            try usage.encode(to: encoder)
        }
    }
}

/// The wire-level notification params for `session/update` (agent -> client).
public struct SessionNotification: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var update: SessionUpdate
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, update
        case meta = "_meta"
    }

    public init(sessionId: SessionId, update: SessionUpdate, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.update = update
        self.meta = meta
    }
}
