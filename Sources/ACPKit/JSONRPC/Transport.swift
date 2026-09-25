import Foundation

/// The lifecycle state of a `Transport`.
public enum TransportState: Sendable, Equatable {
    case created
    case starting
    case started
    case closing
    case closed
}

/// An abstraction over a bidirectional, message-oriented channel carrying raw JSON-RPC
/// payloads (one `Data` value per JSON-RPC message, already framed/deframed).
///
/// Both `JSONRPCPeer` (used by agents and clients alike) and consumers writing tests
/// operate purely against this protocol, so the same peer/dispatch code works whether
/// the underlying channel is real stdio, a WebSocket, or an in-memory pipe.
public protocol Transport: Sendable {
    /// Incoming, already-deframed JSON-RPC message payloads.
    var messages: AsyncStream<Data> { get }

    /// Lifecycle state changes for this transport.
    var state: AsyncStream<TransportState> { get }

    /// Begins reading/writing. Must be safe to call exactly once.
    func start() async throws

    /// Sends a single JSON-RPC message payload.
    func send(_ data: Data) async throws

    /// Closes the transport. Safe to call multiple times.
    func close() async
}
