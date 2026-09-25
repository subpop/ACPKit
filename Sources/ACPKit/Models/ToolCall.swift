import Foundation

public enum ToolKind: String, Sendable, Equatable, Codable {
    case read
    case edit
    case delete
    case move
    case search
    case execute
    case think
    case fetch
    case switchMode = "switch_mode"
    case other
}

public enum ToolCallStatus: String, Sendable, Equatable, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

public struct ToolCallLocation: Sendable, Equatable, Codable {
    public var path: String
    public var line: UInt32?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case path, line
        case meta = "_meta"
    }

    public init(path: String, line: UInt32? = nil, meta: [String: JSONValue]? = nil) {
        self.path = path
        self.line = line
        self.meta = meta
    }
}

/// Content attached to a tool call: inline `ContentBlock` content, a file diff, or a reference
/// to a terminal. A tagged union discriminated by `"type"`.
public enum ToolCallContent: Sendable, Equatable {
    case content(ContentBlock)
    case diff(path: String, newText: String, oldText: String?)
    case terminal(terminalId: TerminalId)
}

extension ToolCallContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, content, path, newText, oldText, terminalId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "content":
            self = .content(try container.decode(ContentBlock.self, forKey: .content))
        case "diff":
            self = .diff(
                path: try container.decode(String.self, forKey: .path),
                newText: try container.decode(String.self, forKey: .newText),
                oldText: try container.decodeIfPresent(String.self, forKey: .oldText)
            )
        case "terminal":
            self = .terminal(terminalId: try container.decode(TerminalId.self, forKey: .terminalId))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown ToolCallContent type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .content(let block):
            try container.encode("content", forKey: .type)
            try container.encode(block, forKey: .content)
        case .diff(let path, let newText, let oldText):
            try container.encode("diff", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(newText, forKey: .newText)
            try container.encodeIfPresent(oldText, forKey: .oldText)
        case .terminal(let terminalId):
            try container.encode("terminal", forKey: .type)
            try container.encode(terminalId, forKey: .terminalId)
        }
    }
}

/// A full description of a tool call, as sent when a tool call is first reported.
public struct ToolCall: Sendable, Equatable, Codable {
    public var toolCallId: ToolCallId
    public var title: String
    public var kind: ToolKind?
    public var status: ToolCallStatus?
    public var content: [ToolCallContent]?
    public var locations: [ToolCallLocation]?
    public var rawInput: JSONValue?
    public var rawOutput: JSONValue?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case toolCallId, title, kind, status, content, locations, rawInput, rawOutput
        case meta = "_meta"
    }

    public init(
        toolCallId: ToolCallId,
        title: String,
        kind: ToolKind? = nil,
        status: ToolCallStatus? = nil,
        content: [ToolCallContent]? = nil,
        locations: [ToolCallLocation]? = nil,
        rawInput: JSONValue? = nil,
        rawOutput: JSONValue? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.toolCallId = toolCallId
        self.title = title
        self.kind = kind
        self.status = status
        self.content = content
        self.locations = locations
        self.rawInput = rawInput
        self.rawOutput = rawOutput
        self.meta = meta
    }
}

/// A partial update to a previously reported tool call. All fields besides `toolCallId` are
/// optional patch-semantics fields.
public struct ToolCallUpdate: Sendable, Equatable, Codable {
    public var toolCallId: ToolCallId
    public var kind: ToolKind?
    public var status: ToolCallStatus?
    public var title: String?
    public var content: [ToolCallContent]?
    public var locations: [ToolCallLocation]?
    public var rawInput: JSONValue?
    public var rawOutput: JSONValue?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case toolCallId, kind, status, title, content, locations, rawInput, rawOutput
        case meta = "_meta"
    }

    public init(
        toolCallId: ToolCallId,
        kind: ToolKind? = nil,
        status: ToolCallStatus? = nil,
        title: String? = nil,
        content: [ToolCallContent]? = nil,
        locations: [ToolCallLocation]? = nil,
        rawInput: JSONValue? = nil,
        rawOutput: JSONValue? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.toolCallId = toolCallId
        self.kind = kind
        self.status = status
        self.title = title
        self.content = content
        self.locations = locations
        self.rawInput = rawInput
        self.rawOutput = rawOutput
        self.meta = meta
    }
}

// MARK: - Plan

public enum PlanEntryPriority: String, Sendable, Equatable, Codable {
    case high
    case medium
    case low
}

public enum PlanEntryStatus: String, Sendable, Equatable, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
}

public struct PlanEntry: Sendable, Equatable, Codable {
    public var content: String
    public var priority: PlanEntryPriority
    public var status: PlanEntryStatus
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case content, priority, status
        case meta = "_meta"
    }

    public init(
        content: String, priority: PlanEntryPriority, status: PlanEntryStatus,
        meta: [String: JSONValue]? = nil
    ) {
        self.content = content
        self.priority = priority
        self.status = status
        self.meta = meta
    }
}
