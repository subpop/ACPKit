import Foundation

/// A JSON-RPC 2.0 request identifier, which per spec may be a string or a number.
public enum RequestID: Sendable, Equatable, Hashable {
    case string(String)
    case number(Int)
}

extension RequestID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}

extension RequestID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension RequestID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(value) }
}
