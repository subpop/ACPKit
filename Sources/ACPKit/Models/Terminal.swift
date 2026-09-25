import Foundation

public struct TerminalExitStatus: Sendable, Equatable, Codable {
    public var exitCode: UInt32?
    public var signal: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case exitCode, signal
        case meta = "_meta"
    }

    public init(exitCode: UInt32? = nil, signal: String? = nil, meta: [String: JSONValue]? = nil) {
        self.exitCode = exitCode
        self.signal = signal
        self.meta = meta
    }
}

public struct CreateTerminalRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var command: String
    public var args: [String]?
    public var env: [EnvVariable]?
    public var cwd: String?
    public var outputByteLimit: UInt64?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, command, args, env, cwd, outputByteLimit
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        command: String,
        args: [String]? = nil,
        env: [EnvVariable]? = nil,
        cwd: String? = nil,
        outputByteLimit: UInt64? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.command = command
        self.args = args
        self.env = env
        self.cwd = cwd
        self.outputByteLimit = outputByteLimit
        self.meta = meta
    }
}

public struct CreateTerminalResponse: Sendable, Equatable, Codable {
    public var terminalId: TerminalId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case terminalId
        case meta = "_meta"
    }

    public init(terminalId: TerminalId, meta: [String: JSONValue]? = nil) {
        self.terminalId = terminalId
        self.meta = meta
    }
}

public struct TerminalOutputRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var terminalId: TerminalId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, terminalId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, terminalId: TerminalId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.terminalId = terminalId
        self.meta = meta
    }
}

public struct TerminalOutputResponse: Sendable, Equatable, Codable {
    public var output: String
    public var truncated: Bool
    public var exitStatus: TerminalExitStatus?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case output, truncated, exitStatus
        case meta = "_meta"
    }

    public init(
        output: String,
        truncated: Bool,
        exitStatus: TerminalExitStatus? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.output = output
        self.truncated = truncated
        self.exitStatus = exitStatus
        self.meta = meta
    }
}

public struct KillTerminalRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var terminalId: TerminalId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, terminalId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, terminalId: TerminalId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.terminalId = terminalId
        self.meta = meta
    }
}

public struct KillTerminalResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct ReleaseTerminalRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var terminalId: TerminalId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, terminalId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, terminalId: TerminalId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.terminalId = terminalId
        self.meta = meta
    }
}

public struct ReleaseTerminalResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}

public struct WaitForTerminalExitRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var terminalId: TerminalId
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, terminalId
        case meta = "_meta"
    }

    public init(sessionId: SessionId, terminalId: TerminalId, meta: [String: JSONValue]? = nil) {
        self.sessionId = sessionId
        self.terminalId = terminalId
        self.meta = meta
    }
}

/// Note: unlike `TerminalOutputResponse`, this response is FLAT (exitCode/signal directly on
/// the response), not wrapped in a nested `exitStatus` field.
public struct WaitForTerminalExitResponse: Sendable, Equatable, Codable {
    public var exitCode: UInt32?
    public var signal: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case exitCode, signal
        case meta = "_meta"
    }

    public init(exitCode: UInt32? = nil, signal: String? = nil, meta: [String: JSONValue]? = nil) {
        self.exitCode = exitCode
        self.signal = signal
        self.meta = meta
    }
}
