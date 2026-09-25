import Foundation

/// A JSON-RPC 2.0 request: expects a response identified by `id`.
public struct JSONRPCRequest: Sendable, Equatable {
    public var jsonrpc: String = "2.0"
    public var id: RequestID
    public var method: String
    public var params: JSONValue?

    public init(id: RequestID, method: String, params: JSONValue?) {
        self.id = id
        self.method = method
        self.params = params
    }
}

extension JSONRPCRequest: Codable {}

/// A JSON-RPC 2.0 notification: one-way, no response expected.
public struct JSONRPCNotification: Sendable, Equatable {
    public var jsonrpc: String = "2.0"
    public var method: String
    public var params: JSONValue?

    public init(method: String, params: JSONValue?) {
        self.method = method
        self.params = params
    }
}

extension JSONRPCNotification: Codable {}

/// A successful JSON-RPC 2.0 response.
public struct JSONRPCResponse: Sendable, Equatable {
    public var jsonrpc: String = "2.0"
    public var id: RequestID
    public var result: JSONValue

    public init(id: RequestID, result: JSONValue) {
        self.id = id
        self.result = result
    }
}

extension JSONRPCResponse: Codable {}

/// A JSON-RPC 2.0 error object, embedded in an error response.
public struct JSONRPCErrorObject: Sendable, Equatable, Error {
    public var code: Int
    public var message: String
    public var data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

extension JSONRPCErrorObject: Codable {}

/// A failed JSON-RPC 2.0 response.
public struct JSONRPCErrorResponse: Sendable, Equatable {
    public var jsonrpc: String = "2.0"
    public var id: RequestID?
    public var error: JSONRPCErrorObject

    public init(id: RequestID?, error: JSONRPCErrorObject) {
        self.id = id
        self.error = error
    }
}

extension JSONRPCErrorResponse: Codable {}

/// A decoded, dispatch-ready JSON-RPC 2.0 message.
public enum JSONRPCMessage: Sendable {
    case request(JSONRPCRequest)
    case notification(JSONRPCNotification)
    case response(JSONRPCResponse)
    case error(JSONRPCErrorResponse)
}

public enum JSONRPCDecodingError: Error, Sendable {
    case unrecognizedMessage
    case responseMissingId
}

extension JSONRPCMessage {
    /// A permissive envelope used purely to discriminate incoming JSON-RPC messages by shape.
    private struct Envelope: Decodable {
        var id: RequestID?
        var method: String?
        var params: JSONValue?
        var result: JSONValue?
        var error: JSONRPCErrorObject?
    }

    public init(data: Data) throws {
        let envelope = try JSONDecoder.acpDecoder.decode(Envelope.self, from: data)
        if let method = envelope.method {
            if let id = envelope.id {
                self = .request(JSONRPCRequest(id: id, method: method, params: envelope.params))
            } else {
                self = .notification(JSONRPCNotification(method: method, params: envelope.params))
            }
        } else if let error = envelope.error {
            self = .error(JSONRPCErrorResponse(id: envelope.id, error: error))
        } else if let result = envelope.result {
            guard let id = envelope.id else {
                throw JSONRPCDecodingError.responseMissingId
            }
            self = .response(JSONRPCResponse(id: id, result: result))
        } else {
            throw JSONRPCDecodingError.unrecognizedMessage
        }
    }

    public func encoded() throws -> Data {
        switch self {
        case .request(let value):
            return try JSONEncoder.acpEncoder.encode(value)
        case .notification(let value):
            return try JSONEncoder.acpEncoder.encode(value)
        case .response(let value):
            return try JSONEncoder.acpEncoder.encode(value)
        case .error(let value):
            return try JSONEncoder.acpEncoder.encode(value)
        }
    }
}

/// Conforming error types carry a specific JSON-RPC error code (and optional structured
/// data) rather than being collapsed into a generic internal-error (-32603) response.
public protocol JSONRPCErrorConvertible: Error {
    var errorCode: Int { get }
    var errorMessage: String { get }
    var errorData: JSONValue? { get }
}

extension JSONRPCErrorConvertible {
    public var errorData: JSONValue? { nil }
}
