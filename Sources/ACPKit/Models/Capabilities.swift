import Foundation

// MARK: - Client capabilities

/// Capabilities advertised by the Client during `initialize`.
public struct ClientCapabilities: Sendable, Equatable {
    public var fs: FileSystemCapabilities
    public var terminal: Bool
    public var session: ClientSessionCapabilities?
    public var auth: AuthCapabilities
    public var elicitation: ElicitationCapabilities?
    public var meta: [String: JSONValue]?

    public init(
        fs: FileSystemCapabilities = FileSystemCapabilities(),
        terminal: Bool = false,
        session: ClientSessionCapabilities? = nil,
        auth: AuthCapabilities = AuthCapabilities(),
        elicitation: ElicitationCapabilities? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.fs = fs
        self.terminal = terminal
        self.session = session
        self.auth = auth
        self.elicitation = elicitation
        self.meta = meta
    }
}

extension ClientCapabilities: Codable {
    enum CodingKeys: String, CodingKey {
        case fs, terminal, session, auth, elicitation
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fs = try container.decode(
            FileSystemCapabilities.self, forKey: .fs, default: FileSystemCapabilities())
        terminal = try container.decode(Bool.self, forKey: .terminal, default: false)
        session = try container.decodeIfPresent(ClientSessionCapabilities.self, forKey: .session)
        auth = try container.decode(
            AuthCapabilities.self, forKey: .auth, default: AuthCapabilities())
        elicitation = try container.decodeIfPresent(
            ElicitationCapabilities.self, forKey: .elicitation)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct FileSystemCapabilities: Sendable, Equatable, Codable {
    public var readTextFile: Bool
    public var writeTextFile: Bool
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case readTextFile, writeTextFile
        case meta = "_meta"
    }

    public init(
        readTextFile: Bool = false, writeTextFile: Bool = false, meta: [String: JSONValue]? = nil
    ) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readTextFile = try container.decode(Bool.self, forKey: .readTextFile, default: false)
        writeTextFile = try container.decode(Bool.self, forKey: .writeTextFile, default: false)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct AuthCapabilities: Sendable, Equatable, Codable {
    public var terminal: Bool
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case terminal
        case meta = "_meta"
    }

    public init(terminal: Bool = false, meta: [String: JSONValue]? = nil) {
        self.terminal = terminal
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terminal = try container.decode(Bool.self, forKey: .terminal, default: false)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct ClientSessionCapabilities: Sendable, Equatable, Codable {
    public var configOptions: SessionConfigOptionsCapabilities?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case configOptions
        case meta = "_meta"
    }

    public init(
        configOptions: SessionConfigOptionsCapabilities? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.configOptions = configOptions
        self.meta = meta
    }
}

public struct SessionConfigOptionsCapabilities: Sendable, Equatable, Codable {
    public var boolean: BooleanConfigOptionCapabilities?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case boolean
        case meta = "_meta"
    }

    public init(boolean: BooleanConfigOptionCapabilities? = nil, meta: [String: JSONValue]? = nil) {
        self.boolean = boolean
        self.meta = meta
    }
}

/// An empty marker capability. Its mere presence (non-`nil`) in a containing optional field
/// signals that the capability is supported; it carries no fields of its own besides `_meta`.
public struct BooleanConfigOptionCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
    }

    public init(meta: [String: JSONValue]? = nil) {
        self.meta = meta
    }
}

public struct ElicitationCapabilities: Sendable, Equatable, Codable {
    public var form: ElicitationFormCapabilities?
    public var url: ElicitationUrlCapabilities?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case form, url
        case meta = "_meta"
    }

    public init(
        form: ElicitationFormCapabilities? = nil,
        url: ElicitationUrlCapabilities? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.form = form
        self.url = url
        self.meta = meta
    }
}

public struct ElicitationFormCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
    }

    public init(meta: [String: JSONValue]? = nil) {
        self.meta = meta
    }
}

public struct ElicitationUrlCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
    }

    public init(meta: [String: JSONValue]? = nil) {
        self.meta = meta
    }
}

// MARK: - Agent capabilities

/// Capabilities advertised by the Agent during `initialize`.
public struct AgentCapabilities: Sendable, Equatable {
    public var loadSession: Bool
    public var promptCapabilities: PromptCapabilities
    public var mcpCapabilities: McpCapabilities
    public var sessionCapabilities: SessionCapabilities
    public var auth: AgentAuthCapabilities
    public var meta: [String: JSONValue]?

    public init(
        loadSession: Bool = false,
        promptCapabilities: PromptCapabilities = PromptCapabilities(),
        mcpCapabilities: McpCapabilities = McpCapabilities(),
        sessionCapabilities: SessionCapabilities = SessionCapabilities(),
        auth: AgentAuthCapabilities = AgentAuthCapabilities(),
        meta: [String: JSONValue]? = nil
    ) {
        self.loadSession = loadSession
        self.promptCapabilities = promptCapabilities
        self.mcpCapabilities = mcpCapabilities
        self.sessionCapabilities = sessionCapabilities
        self.auth = auth
        self.meta = meta
    }
}

extension AgentCapabilities: Codable {
    enum CodingKeys: String, CodingKey {
        case loadSession, promptCapabilities, mcpCapabilities, sessionCapabilities, auth
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        loadSession = try container.decode(Bool.self, forKey: .loadSession, default: false)
        promptCapabilities = try container.decode(
            PromptCapabilities.self, forKey: .promptCapabilities, default: PromptCapabilities()
        )
        mcpCapabilities = try container.decode(
            McpCapabilities.self, forKey: .mcpCapabilities, default: McpCapabilities()
        )
        sessionCapabilities = try container.decode(
            SessionCapabilities.self, forKey: .sessionCapabilities, default: SessionCapabilities()
        )
        auth = try container.decode(
            AgentAuthCapabilities.self, forKey: .auth, default: AgentAuthCapabilities())
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct PromptCapabilities: Sendable, Equatable, Codable {
    public var image: Bool
    public var audio: Bool
    public var embeddedContext: Bool
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case image, audio, embeddedContext
        case meta = "_meta"
    }

    public init(
        image: Bool = false, audio: Bool = false, embeddedContext: Bool = false,
        meta: [String: JSONValue]? = nil
    ) {
        self.image = image
        self.audio = audio
        self.embeddedContext = embeddedContext
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        image = try container.decode(Bool.self, forKey: .image, default: false)
        audio = try container.decode(Bool.self, forKey: .audio, default: false)
        embeddedContext = try container.decode(Bool.self, forKey: .embeddedContext, default: false)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct McpCapabilities: Sendable, Equatable, Codable {
    public var http: Bool
    public var sse: Bool
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case http, sse
        case meta = "_meta"
    }

    public init(http: Bool = false, sse: Bool = false, meta: [String: JSONValue]? = nil) {
        self.http = http
        self.sse = sse
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        http = try container.decode(Bool.self, forKey: .http, default: false)
        sse = try container.decode(Bool.self, forKey: .sse, default: false)
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
}

public struct SessionCapabilities: Sendable, Equatable, Codable {
    public var list: SessionListCapabilities?
    public var delete: SessionDeleteCapabilities?
    public var additionalDirectories: SessionAdditionalDirectoriesCapabilities?
    public var resume: SessionResumeCapabilities?
    public var close: SessionCloseCapabilities?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case list, delete, additionalDirectories, resume, close
        case meta = "_meta"
    }

    public init(
        list: SessionListCapabilities? = nil,
        delete: SessionDeleteCapabilities? = nil,
        additionalDirectories: SessionAdditionalDirectoriesCapabilities? = nil,
        resume: SessionResumeCapabilities? = nil,
        close: SessionCloseCapabilities? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.list = list
        self.delete = delete
        self.additionalDirectories = additionalDirectories
        self.resume = resume
        self.close = close
        self.meta = meta
    }
}

public struct SessionListCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct SessionDeleteCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct SessionAdditionalDirectoriesCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct SessionResumeCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct SessionCloseCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct AgentAuthCapabilities: Sendable, Equatable, Codable {
    public var logout: LogoutCapabilities?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case logout
        case meta = "_meta"
    }

    public init(logout: LogoutCapabilities? = nil, meta: [String: JSONValue]? = nil) {
        self.logout = logout
        self.meta = meta
    }
}

public struct LogoutCapabilities: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}
