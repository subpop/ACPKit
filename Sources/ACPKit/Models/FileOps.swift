import Foundation

public struct ReadTextFileRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var path: String
    public var line: UInt32?
    public var limit: UInt32?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, path, line, limit
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId,
        path: String,
        line: UInt32? = nil,
        limit: UInt32? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.path = path
        self.line = line
        self.limit = limit
        self.meta = meta
    }
}

public struct ReadTextFileResponse: Sendable, Equatable, Codable {
    public var content: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case content
        case meta = "_meta"
    }

    public init(content: String, meta: [String: JSONValue]? = nil) {
        self.content = content
        self.meta = meta
    }
}

public struct WriteTextFileRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var path: String
    public var content: String
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, path, content
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId, path: String, content: String, meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.path = path
        self.content = content
        self.meta = meta
    }
}

public struct WriteTextFileResponse: Sendable, Equatable, Codable {
    public var meta: [String: JSONValue]?
    enum CodingKeys: String, CodingKey { case meta = "_meta" }
    public init(meta: [String: JSONValue]? = nil) { self.meta = meta }
}
