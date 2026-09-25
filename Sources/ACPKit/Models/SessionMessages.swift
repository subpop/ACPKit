import Foundation

// MARK: - Stop reason

public enum StopReason: String, Sendable, Equatable, Codable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case maxTurnRequests = "max_turn_requests"
    case refusal = "refusal"
    case cancelled = "cancelled"
}

// MARK: - Session modes

public struct SessionMode: Sendable, Equatable, Codable {
    public var id: SessionModeId
    public var name: String
    public var description: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case meta = "_meta"
    }

    public init(
        id: SessionModeId, name: String, description: String? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.meta = meta
    }
}

public struct SessionModeState: Sendable, Equatable, Codable {
    public var currentModeId: SessionModeId
    public var availableModes: [SessionMode]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case currentModeId, availableModes
        case meta = "_meta"
    }

    public init(
        currentModeId: SessionModeId, availableModes: [SessionMode],
        meta: [String: JSONValue]? = nil
    ) {
        self.currentModeId = currentModeId
        self.availableModes = availableModes
        self.meta = meta
    }
}

// MARK: - Session info (session/list)

public struct SessionInfo: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var cwd: String
    public var additionalDirectories: [String]?
    public var title: String?
    public var updatedAt: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, cwd, additionalDirectories, title, updatedAt
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        cwd: String,
        additionalDirectories: [String]? = nil,
        title: String? = nil,
        updatedAt: String? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.title = title
        self.updatedAt = updatedAt
        self.meta = meta
    }
}

// MARK: - session/new

public struct NewSessionRequest: Sendable, Equatable, Codable {
    public var cwd: String
    public var mcpServers: [McpServer]
    public var additionalDirectories: [String]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case cwd, mcpServers, additionalDirectories
        case meta = "_meta"
    }

    public init(
        cwd: String,
        mcpServers: [McpServer],
        additionalDirectories: [String]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.cwd = cwd
        self.mcpServers = mcpServers
        self.additionalDirectories = additionalDirectories
        self.meta = meta
    }
}

public struct NewSessionResponse: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var modes: SessionModeState?
    public var configOptions: [SessionConfigOption]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, modes, configOptions
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        modes: SessionModeState? = nil,
        configOptions: [SessionConfigOption]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.modes = modes
        self.configOptions = configOptions
        self.meta = meta
    }
}

// MARK: - session/load

public struct LoadSessionRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var cwd: String
    public var mcpServers: [McpServer]
    public var additionalDirectories: [String]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, cwd, mcpServers, additionalDirectories
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        cwd: String,
        mcpServers: [McpServer],
        additionalDirectories: [String]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.mcpServers = mcpServers
        self.additionalDirectories = additionalDirectories
        self.meta = meta
    }
}

public struct LoadSessionResponse: Sendable, Equatable, Codable {
    public var modes: SessionModeState?
    public var configOptions: [SessionConfigOption]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case modes, configOptions
        case meta = "_meta"
    }

    public init(
        modes: SessionModeState? = nil,
        configOptions: [SessionConfigOption]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.modes = modes
        self.configOptions = configOptions
        self.meta = meta
    }
}

// MARK: - session/resume

public struct ResumeSessionRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var cwd: String
    public var mcpServers: [McpServer]?
    public var additionalDirectories: [String]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, cwd, mcpServers, additionalDirectories
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        cwd: String,
        mcpServers: [McpServer]? = nil,
        additionalDirectories: [String]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.mcpServers = mcpServers
        self.additionalDirectories = additionalDirectories
        self.meta = meta
    }
}

public struct ResumeSessionResponse: Sendable, Equatable, Codable {
    public var modes: SessionModeState?
    public var configOptions: [SessionConfigOption]?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case modes, configOptions
        case meta = "_meta"
    }

    public init(
        modes: SessionModeState? = nil,
        configOptions: [SessionConfigOption]? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.modes = modes
        self.configOptions = configOptions
        self.meta = meta
    }
}

// MARK: - session/prompt

public struct PromptRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var prompt: [ContentBlock]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, prompt
        case meta = "_meta"
    }

    public init(sessionId: SessionId, prompt: [ContentBlock], meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.prompt = prompt
        self.meta = meta
    }
}

public struct PromptResponse: Sendable, Equatable, Codable {
    public var stopReason: StopReason
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case stopReason
        case meta = "_meta"
    }

    public init(stopReason: StopReason, meta: [String: JSONValue]? = nil) {
        self.stopReason = stopReason
        self.meta = meta
    }
}

// MARK: - session/cancel

/// Client -> Agent notification requesting cancellation of the in-flight `session/prompt`.
public struct CancelNotification: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.meta = meta
    }
}

// MARK: - session/set_mode

public struct SetSessionModeRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var modeId: SessionModeId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, modeId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, modeId: SessionModeId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.modeId = modeId
        self.meta = meta
    }
}

public struct SetSessionModeResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

// MARK: - session/list

public struct ListSessionsRequest: Sendable, Equatable, Codable {
    public var cursor: String?
    public var cwd: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case cursor, cwd
        case meta = "_meta"
    }

    public init(cursor: String? = nil, cwd: String? = nil, meta: [String: JSONValue]? = nil) {
        self.cursor = cursor
        self.cwd = cwd
        self.meta = meta
    }
}

public struct ListSessionsResponse: Sendable, Equatable, Codable {
    public var sessions: [SessionInfo]
    public var nextCursor: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessions, nextCursor
        case meta = "_meta"
    }

    public init(
        sessions: [SessionInfo], nextCursor: String? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.sessions = sessions
        self.nextCursor = nextCursor
        self.meta = meta
    }
}

// MARK: - session/close, session/delete

public struct CloseSessionRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.meta = meta
    }
}

public struct CloseSessionResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct DeleteSessionRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.meta = meta
    }
}

public struct DeleteSessionResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}
