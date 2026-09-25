import Foundation

/// The role a piece of content is intended for, used in `Annotations.audience`.
public enum Role: String, Sendable, Equatable, Codable {
    case assistant
    case user
}

public struct Annotations: Sendable, Equatable, Codable {
    public var audience: [Role]?
    public var lastModified: String?
    public var priority: Double?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case audience, lastModified, priority
        case meta = "_meta"
    }

    public init(
        audience: [Role]? = nil,
        lastModified: String? = nil,
        priority: Double? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.audience = audience
        self.lastModified = lastModified
        self.priority = priority
        self.meta = meta
    }
}

/// A block of content exchanged in prompts and session updates. A tagged union discriminated
/// by the wire-level `"type"` field.
public enum ContentBlock: Sendable, Equatable {
    case text(TextContent)
    case image(ImageContent)
    case audio(AudioContent)
    case resourceLink(ResourceLink)
    case resource(EmbeddedResource)
}

extension ContentBlock: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "image":
            self = .image(try ImageContent(from: decoder))
        case "audio":
            self = .audio(try AudioContent(from: decoder))
        case "resource_link":
            self = .resourceLink(try ResourceLink(from: decoder))
        case "resource":
            self = .resource(try EmbeddedResource(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown ContentBlock type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .audio(let value): try value.encode(to: encoder)
        case .resourceLink(let value): try value.encode(to: encoder)
        case .resource(let value): try value.encode(to: encoder)
        }
    }
}

public struct TextContent: Sendable, Equatable, Codable {
    public var type: String = "text"
    public var text: String
    public var annotations: Annotations?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, text, annotations
        case meta = "_meta"
    }

    public init(text: String, annotations: Annotations? = nil, meta: [String: JSONValue]? = nil) {
        self.text = text
        self.annotations = annotations
        self.meta = meta
    }
}

public struct ImageContent: Sendable, Equatable, Codable {
    public var type: String = "image"
    /// Base64-encoded image data.
    public var data: String
    public var mimeType: String
    public var uri: String?
    public var annotations: Annotations?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, data, mimeType, uri, annotations
        case meta = "_meta"
    }

    public init(
        data: String,
        mimeType: String,
        uri: String? = nil,
        annotations: Annotations? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.data = data
        self.mimeType = mimeType
        self.uri = uri
        self.annotations = annotations
        self.meta = meta
    }
}

public struct AudioContent: Sendable, Equatable, Codable {
    public var type: String = "audio"
    /// Base64-encoded audio data.
    public var data: String
    public var mimeType: String
    public var annotations: Annotations?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, data, mimeType, annotations
        case meta = "_meta"
    }

    public init(
        data: String, mimeType: String, annotations: Annotations? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.data = data
        self.mimeType = mimeType
        self.annotations = annotations
        self.meta = meta
    }
}

/// A reference to a resource (e.g. a file) without inlining its content.
public struct ResourceLink: Sendable, Equatable, Codable {
    public var type: String = "resource_link"
    public var name: String
    public var uri: String
    public var description: String?
    public var mimeType: String?
    public var size: Int64?
    public var title: String?
    public var annotations: Annotations?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, name, uri, description, mimeType, size, title, annotations
        case meta = "_meta"
    }

    public init(
        name: String,
        uri: String,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int64? = nil,
        title: String? = nil,
        annotations: Annotations? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.name = name
        self.uri = uri
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.title = title
        self.annotations = annotations
        self.meta = meta
    }
}

/// A resource with its content inlined directly (as opposed to `ResourceLink`, which is a
/// pointer). Requires the agent to advertise `PromptCapabilities.embeddedContext`.
public struct EmbeddedResource: Sendable, Equatable, Codable {
    public var type: String = "resource"
    public var resource: EmbeddedResourceResource
    public var annotations: Annotations?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, resource, annotations
        case meta = "_meta"
    }

    public init(
        resource: EmbeddedResourceResource, annotations: Annotations? = nil,
        meta: [String: JSONValue]? = nil
    ) {
        self.resource = resource
        self.annotations = annotations
        self.meta = meta
    }
}

/// The inlined content of an `EmbeddedResource`: either text or base64-encoded binary data.
/// An untagged union, disambiguated structurally by the presence of `text` vs `blob`.
public enum EmbeddedResourceResource: Sendable, Equatable {
    case text(TextResourceContents)
    case blob(BlobResourceContents)
}

extension EmbeddedResourceResource: Codable {
    private enum PeekKeys: String, CodingKey { case text, blob }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PeekKeys.self)
        if container.contains(.text) {
            self = .text(try TextResourceContents(from: decoder))
        } else if container.contains(.blob) {
            self = .blob(try BlobResourceContents(from: decoder))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "EmbeddedResourceResource requires either a 'text' or 'blob' field"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .blob(let value): try value.encode(to: encoder)
        }
    }
}

public struct TextResourceContents: Sendable, Equatable, Codable {
    public var text: String
    public var uri: String
    public var mimeType: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case text, uri, mimeType
        case meta = "_meta"
    }

    public init(
        text: String, uri: String, mimeType: String? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.text = text
        self.uri = uri
        self.mimeType = mimeType
        self.meta = meta
    }
}

public struct BlobResourceContents: Sendable, Equatable, Codable {
    /// Base64-encoded binary data.
    public var blob: String
    public var uri: String
    public var mimeType: String?
    public var meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case blob, uri, mimeType
        case meta = "_meta"
    }

    public init(
        blob: String, uri: String, mimeType: String? = nil, meta: [String: JSONValue]? = nil
    ) {
        self.blob = blob
        self.uri = uri
        self.mimeType = mimeType
        self.meta = meta
    }
}
