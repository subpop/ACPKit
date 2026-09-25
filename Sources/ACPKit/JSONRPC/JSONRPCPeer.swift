import Foundation
import Logging

public enum JSONRPCPeerError: Error, Sendable, Equatable {
    case notStarted
    case closed
    case timedOut
}

/// A transport-agnostic JSON-RPC 2.0 peer.
///
/// `JSONRPCPeer` is deliberately symmetric: both the agent side (`AgentConnection`) and
/// the client side (`ClientConnection`) of ACPKit are built on top of the same actor,
/// since ACP requires each side to both send and receive requests/notifications
/// (e.g. an agent sends `session/update` notifications and `fs/read_text_file` requests
/// to the client, while the client sends `session/prompt` requests and `session/cancel`
/// notifications to the agent).
public actor JSONRPCPeer {
    public typealias RequestHandler = @Sendable (JSONValue?) async throws -> JSONValue
    public typealias NotificationHandler = @Sendable (JSONValue?) async -> Void

    private let transport: any Transport
    private let logger: Logger

    private var requestHandlers: [String: RequestHandler] = [:]
    private var notificationHandlers: [String: NotificationHandler] = [:]

    private var pendingOutgoing: [RequestID: CheckedContinuation<JSONValue, Error>] = [:]
    private var incomingTasks: [RequestID: Task<Void, Never>] = [:]
    private var nextRequestNumber: Int = 0
    private var dispatchTask: Task<Void, Never>?
    private var isClosed = false

    public init(transport: any Transport, logger: Logger = Logger(label: "ACPKit.JSONRPCPeer")) {
        self.transport = transport
        self.logger = logger
    }

    // MARK: - Handler registration

    public func onRequest(method: String, handler: @escaping RequestHandler) {
        requestHandlers[method] = handler
    }

    public func onNotification(method: String, handler: @escaping NotificationHandler) {
        notificationHandlers[method] = handler
    }

    // MARK: - Lifecycle

    public func start() async throws {
        try await transport.start()
        let messages = transport.messages
        dispatchTask = Task { [weak self] in
            for await data in messages {
                guard let self else { return }
                await self.handleIncoming(data: data)
            }
            await self?.failAllPending(with: JSONRPCPeerError.closed)
        }
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        dispatchTask?.cancel()
        for task in incomingTasks.values { task.cancel() }
        incomingTasks.removeAll()
        failAllPending(with: JSONRPCPeerError.closed)
        await transport.close()
    }

    // MARK: - Outgoing

    /// Sends a JSON-RPC request and awaits the typed result.
    ///
    /// - Parameter timeout: maximum time to wait for the response. `nil`
    ///   waits indefinitely (as before). Exceeding it throws
    ///   ``JSONRPCPeerError/timedOut`` and drops the pending request, so a
    ///   late response is ignored. Cancelling the calling task throws
    ///   `CancellationError` instead of hanging.
    @discardableResult
    public func sendRequest<Params: Encodable, Result: Decodable>(
        method: String,
        params: Params?,
        as resultType: Result.Type = Result.self,
        timeout: TimeInterval? = nil
    ) async throws -> Result {
        let value = try await sendRequest(method: method, params: params, timeout: timeout)
        return try value.decode(as: Result.self)
    }

    /// Sends a JSON-RPC request and awaits the raw `JSONValue` result.
    ///
    /// - Parameter timeout: maximum time to wait for the response. `nil`
    ///   waits indefinitely (as before). Exceeding it throws
    ///   ``JSONRPCPeerError/timedOut`` and drops the pending request, so a
    ///   late response is ignored. Cancelling the calling task throws
    ///   `CancellationError` instead of hanging.
    public func sendRequest<Params: Encodable>(
        method: String,
        params: Params?,
        timeout: TimeInterval? = nil
    ) async throws -> JSONValue {
        guard !isClosed else { throw JSONRPCPeerError.closed }
        let id = allocateRequestId()
        let paramsValue = try params.map { try JSONValue(encoding: $0) }
        let request = JSONRPCRequest(id: id, method: method, params: paramsValue)
        let data = try JSONRPCMessage.request(request).encoded()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<JSONValue, Error>) in
                self.pendingOutgoing[id] = continuation
                // The cancellation handler may already have run before
                // registration; re-check so an already-cancelled caller never
                // parks on a continuation nobody will resume.
                if Task.isCancelled {
                    self.failPending(id: id, error: CancellationError())
                    return
                }
                Task {
                    do {
                        try await self.transport.send(data)
                    } catch {
                        self.failPending(id: id, error: error)
                    }
                }
                if let timeout {
                    self.scheduleTimeout(id: id, after: timeout)
                }
            }
        } onCancel: {
            Task { await self.failPending(id: id, error: CancellationError()) }
        }
    }

    /// Sends a one-way JSON-RPC notification.
    public func sendNotification<Params: Encodable>(method: String, params: Params?) async throws {
        guard !isClosed else { throw JSONRPCPeerError.closed }
        let paramsValue = try params.map { try JSONValue(encoding: $0) }
        let notification = JSONRPCNotification(method: method, params: paramsValue)
        let data = try JSONRPCMessage.notification(notification).encoded()
        try await transport.send(data)
    }

    // MARK: - Incoming dispatch

    private func handleIncoming(data: Data) async {
        let message: JSONRPCMessage
        do {
            message = try JSONRPCMessage(data: data)
        } catch {
            logger.warning("Failed to decode JSON-RPC message: \(error)")
            return
        }

        switch message {
        case .request(let request):
            handleIncomingRequest(request)
        case .notification(let notification):
            await handleIncomingNotification(notification)
        case .response(let response):
            resolvePending(id: response.id, result: .success(response.result))
        case .error(let errorResponse):
            if let id = errorResponse.id {
                resolvePending(id: id, result: .failure(errorResponse.error))
            } else {
                logger.warning("Received JSON-RPC error with no id: \(errorResponse.error)")
            }
        }
    }

    private func handleIncomingRequest(_ request: JSONRPCRequest) {
        guard let handler = requestHandlers[request.method] else {
            let response = JSONRPCErrorResponse(
                id: request.id,
                error: JSONRPCErrorObject(
                    code: -32601, message: "Method not found: \(request.method)")
            )
            sendRaw(.error(response))
            return
        }

        let requestId = request.id
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await handler(request.params)
                await self.sendRaw(.response(JSONRPCResponse(id: requestId, result: result)))
            } catch let convertible as JSONRPCErrorConvertible {
                let errorObject = JSONRPCErrorObject(
                    code: convertible.errorCode,
                    message: convertible.errorMessage,
                    data: convertible.errorData
                )
                await self.sendRaw(.error(JSONRPCErrorResponse(id: requestId, error: errorObject)))
            } catch {
                let errorObject = JSONRPCErrorObject(code: -32603, message: "\(error)")
                await self.sendRaw(.error(JSONRPCErrorResponse(id: requestId, error: errorObject)))
            }
            await self.clearIncomingTask(id: requestId)
        }
        incomingTasks[requestId] = task
    }

    private func handleIncomingNotification(_ notification: JSONRPCNotification) async {
        guard let handler = notificationHandlers[notification.method] else {
            logger.debug("No handler registered for notification method: \(notification.method)")
            return
        }
        await handler(notification.params)
    }

    private func clearIncomingTask(id: RequestID) {
        incomingTasks.removeValue(forKey: id)
    }

    private func sendRaw(_ message: JSONRPCMessage) {
        guard !isClosed else { return }
        do {
            let data = try message.encoded()
            Task { try? await self.transport.send(data) }
        } catch {
            logger.error("Failed to encode outgoing JSON-RPC message: \(error)")
        }
    }

    // MARK: - Pending request bookkeeping

    private func allocateRequestId() -> RequestID {
        defer { nextRequestNumber += 1 }
        return .number(nextRequestNumber)
    }

    private func resolvePending(id: RequestID, result: Result<JSONValue, Error>) {
        guard let continuation = pendingOutgoing.removeValue(forKey: id) else {
            logger.warning("Received response for unknown request id: \(id)")
            return
        }
        continuation.resume(with: result)
    }

    private func failPending(id: RequestID, error: Error) {
        guard let continuation = pendingOutgoing.removeValue(forKey: id) else { return }
        continuation.resume(throwing: error)
    }

    /// Fails `id` with ``JSONRPCPeerError/timedOut`` unless it resolved first.
    /// No-op when the response (or cancellation) already won the race.
    private func scheduleTimeout(id: RequestID, after timeout: TimeInterval) {
        Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(timeout, 0.001) * 1_000_000_000))
            self.failPending(id: id, error: JSONRPCPeerError.timedOut)
        }
    }

    private func failAllPending(with error: Error) {
        let continuations = pendingOutgoing
        pendingOutgoing.removeAll()
        for continuation in continuations.values {
            continuation.resume(throwing: error)
        }
    }
}
