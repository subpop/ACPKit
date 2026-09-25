import Foundation

/// A type-safe wrapper around the plain string identifiers used throughout the ACP schema
/// (e.g. `SessionId`, `ToolCallId`). Each distinct identifier kind is a distinct Swift type,
/// achieved via a phantom `Tag` type parameter, so that (for example) a `ToolCallId` can never
/// be accidentally passed where a `SessionId` is expected, while both encode/decode identically
/// to a plain JSON string on the wire.
public struct AcpId<Tag>: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension AcpId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension AcpId: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension AcpId: CustomStringConvertible {
    public var description: String { rawValue }
}

public enum SessionIdTag: Sendable {}
public typealias SessionId = AcpId<SessionIdTag>

public enum ToolCallIdTag: Sendable {}
public typealias ToolCallId = AcpId<ToolCallIdTag>

public enum TerminalIdTag: Sendable {}
public typealias TerminalId = AcpId<TerminalIdTag>

public enum PermissionOptionIdTag: Sendable {}
public typealias PermissionOptionId = AcpId<PermissionOptionIdTag>

public enum MessageIdTag: Sendable {}
public typealias MessageId = AcpId<MessageIdTag>

public enum ElicitationIdTag: Sendable {}
public typealias ElicitationId = AcpId<ElicitationIdTag>

public enum AuthMethodIdTag: Sendable {}
public typealias AuthMethodId = AcpId<AuthMethodIdTag>

public enum SessionModeIdTag: Sendable {}
public typealias SessionModeId = AcpId<SessionModeIdTag>

public enum SessionConfigIdTag: Sendable {}
public typealias SessionConfigId = AcpId<SessionConfigIdTag>

public enum SessionConfigGroupIdTag: Sendable {}
public typealias SessionConfigGroupId = AcpId<SessionConfigGroupIdTag>

public enum SessionConfigValueIdTag: Sendable {}
public typealias SessionConfigValueId = AcpId<SessionConfigValueIdTag>

/// The ACP protocol version, a plain integer (e.g. `1`), negotiated during `initialize`.
public typealias ProtocolVersion = Int

/// The latest ACP protocol version this implementation supports.
public let acpProtocolVersion: ProtocolVersion = 1
