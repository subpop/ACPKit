import Foundation

public enum PermissionOptionKind: String, Sendable, Equatable, Codable {
    case allowOnce = "allow_once"
    case allowAlways = "allow_always"
    case rejectOnce = "reject_once"
    case rejectAlways = "reject_always"
}

public struct PermissionOption: Sendable, Equatable, Codable {
    public var optionId: PermissionOptionId
    public var name: String
    public var kind: PermissionOptionKind
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case optionId, name, kind
        case meta = "_meta"
    }

    public init(
        optionId: PermissionOptionId, name: String, kind: PermissionOptionKind,
        meta: [String: JSONValue]? = nil
    ) {
        self.optionId = optionId
        self.name = name
        self.kind = kind
        self.meta = meta
    }
}

/// The outcome of a `session/request_permission` request. A tagged union discriminated by
/// `"outcome"`.
public enum RequestPermissionOutcome: Sendable, Equatable {
    case cancelled
    case selected(optionId: PermissionOptionId, meta: [String: JSONValue]? = nil)
}

extension RequestPermissionOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case outcome, optionId
        case meta = "_meta"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let outcome = try container.decode(String.self, forKey: .outcome)
        switch outcome {
        case "cancelled":
            self = .cancelled
        case "selected":
            self = .selected(
                optionId: try container.decode(PermissionOptionId.self, forKey: .optionId),
                meta: try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .outcome, in: container,
                debugDescription: "Unknown RequestPermissionOutcome: \(outcome)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cancelled:
            try container.encode("cancelled", forKey: .outcome)
        case .selected(let optionId, let meta):
            try container.encode("selected", forKey: .outcome)
            try container.encode(optionId, forKey: .optionId)
            try container.encodeIfPresent(meta, forKey: .meta)
        }
    }
}

/// Request params for `session/request_permission` (agent -> client).
public struct RequestPermissionRequest: Sendable, Equatable, Codable {
    public var sessionId: SessionId
    public var toolCall: ToolCallUpdate
    public var options: [PermissionOption]
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case sessionId, toolCall, options
        case meta = "_meta"
    }

    public init(
        sessionId: SessionId, toolCall: ToolCallUpdate, options: [PermissionOption],
        meta: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.toolCall = toolCall
        self.options = options
        self.meta = meta
    }
}

/// Response for `session/request_permission`.
public struct RequestPermissionResponse: Sendable, Equatable, Codable {
    public var outcome: RequestPermissionOutcome
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case outcome
        case meta = "_meta"
    }

    public init(outcome: RequestPermissionOutcome, meta: [String: JSONValue]? = nil) {
        self.outcome = outcome
        self.meta = meta
    }
}
