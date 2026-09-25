import Foundation

/// Errors a ``Client`` implementation may throw. Conforms to ``JSONRPCErrorConvertible``
/// so that ``ClientConnection`` can translate these into specific JSON-RPC error codes
/// instead of a generic internal error.
public enum ClientError: Error, Sendable, Equatable, LocalizedError, JSONRPCErrorConvertible {
    /// The client does not implement the given method.
    case notImplemented(method: String)
    /// The request params were missing or malformed.
    case invalidParams(String)
    /// An unexpected internal error occurred.
    case internalError(String)

    public var errorCode: Int {
        switch self {
        case .notImplemented:
            return -32601
        case .invalidParams:
            return -32602
        case .internalError:
            return -32603
        }
    }

    public var errorMessage: String {
        switch self {
        case .notImplemented(let method):
            return "Method not implemented: \(method)"
        case .invalidParams(let message):
            return "Invalid params: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }

    public var errorDescription: String? {
        errorMessage
    }
}
