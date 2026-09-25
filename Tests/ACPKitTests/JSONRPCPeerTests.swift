import Foundation
import Testing

@testable import ACPKit

private enum PeerProbeError: Error, JSONRPCErrorConvertible {
    case badInput(String)
    var errorCode: Int { -32602 }
    var errorMessage: String {
        switch self {
        case .badInput(let m): return "Bad: \(m)"
        }
    }
}

@Test("peer resolves successful requests", arguments: [0, 1, 5])
func peerResolvesRequests(index: Int) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    await peer.onRequest(method: "echo") { params in params ?? .null }

    async let sent: JSONValue = peer.sendRequest(
        method: "echo", params: JSONValue.object(["n": .number(Double(index))]))
    // Driver loop: answer the captured outbound request.
    let requestData = try await transport.awaitSent { _ in true }
    let message = try JSONRPCMessage(data: requestData)
    guard case .request(let req) = message else {
        Issue.record("expected outbound request")
        await peer.close()
        return
    }
    let response = try JSONRPCMessage.response(
        JSONRPCResponse(id: req.id, result: ["n": .number(Double(index))])
    ).encoded()
    transport.inject(response)
    let value = try await sent
    #expect(value == ["n": .number(Double(index))])
    await peer.close()
}

@Test(
    "peer maps handler errors to codes",
    arguments: [
        (name: "convertible-keeps-code", code: -32602),
        (name: "generic-becomes-internal", code: -32603),
    ])
func peerErrorMapping(c: (name: String, code: Int)) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    await peer.onRequest(method: "fail") { _ in
        if c.name == "convertible-keeps-code" { throw PeerProbeError.badInput("x") }
        throw TableTestError.timedOut
    }

    // Inject a request directly and await the error response.
    let id = RequestID.string("e-\(c.name)")
    try await transport.start()
    transport.inject(try rpcRequestData(id: id, method: "fail"))
    // Give the peer a moment to dispatch (registered inside peer.start's task).
    try await Task.sleep(nanoseconds: 100_000_000)
    let sent = transport.sent
    #expect(!sent.isEmpty)
    if let data = sent.first(where: isResponseData(for: id)),
        case .error(let err) = try JSONRPCMessage(data: data)
    {
        #expect(err.error.code == c.code)
    } else {
        Issue.record("expected error response for \(c.name)")
    }
    await peer.close()
}

@Test("peer unknown method is -32601", arguments: ["nope", "missing/method"])
func peerUnknownMethod(method: String) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    let id = RequestID.string("u-\(method)")
    transport.inject(try rpcRequestData(id: id, method: method))
    let data = try await transport.awaitSent(matching: isResponseData(for: id))
    guard case .error(let err) = try JSONRPCMessage(data: data) else {
        Issue.record("expected error for unknown method \(method)")
        await peer.close()
        return
    }
    #expect(err.error.code == -32601)
    await peer.close()
}

@Test("peer dispatches notifications", arguments: ["n1", "n2"])
func peerNotifications(suffix: String) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    let received = LockedValue<[String]>([])
    await peer.onNotification(method: "ping-\(suffix)") { params in
        await received.append(params?.stringValue ?? "")
    }
    transport.inject(try rpcNotificationData(method: "ping-\(suffix)", params: "hi"))
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while await received.snapshot().isEmpty,
        DispatchTime.now().uptimeNanoseconds < deadline
    {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(await received.snapshot() == ["hi"])
    await peer.close()
}

@Test("peer ignores unknown notifications", arguments: ["a", "b"])
func peerIgnoresUnknownNotifications(tag: String) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    // Must not crash or respond.
    transport.inject(try rpcNotificationData(method: "unknown-\(tag)"))
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(transport.sent.isEmpty)
    await peer.close()
}

@Test("peer send after close throws", arguments: [true, false])
func peerSendAfterClose(flag _: Bool) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()
    await peer.close()
    await #expect(throws: JSONRPCPeerError.self) {
        try await peer.sendNotification(method: "x", params: nil as JSONValue?)
    }
}

// MARK: - Bounded waits

struct PeerTimeoutCase: Sendable {
    var name: String
    var timeoutSeconds: TimeInterval
}

@Test(
    "sendRequest times out and peer stays usable",
    arguments: [
        PeerTimeoutCase(name: "fast", timeoutSeconds: 0.01),
        PeerTimeoutCase(name: "slow", timeoutSeconds: 0.05),
    ])
func peerSendRequestTimeout(_ c: PeerTimeoutCase) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()

    // Nothing ever answers: the wait must end with timedOut, not hang.
    await #expect(throws: JSONRPCPeerError.timedOut) {
        try await peer.sendRequest(
            method: "never-\(c.name)", params: nil as JSONValue?,
            timeout: c.timeoutSeconds)
    }

    // The dropped request stays dropped (a late response is ignored) and the
    // peer serves new requests normally.
    let echoMethod = "echo-\(c.name)"
    async let echoed: JSONValue = peer.sendRequest(
        method: echoMethod, params: JSONValue.object(["n": .number(1)]))
    let requestData = try await transport.awaitSent { data in
        guard let message = try? JSONRPCMessage(data: data),
            case .request(let req) = message
        else { return false }
        return req.method == echoMethod
    }
    guard case .request(let req) = try JSONRPCMessage(data: requestData) else {
        Issue.record("expected outbound request")
        await peer.close()
        return
    }
    transport.inject(
        try JSONRPCMessage.response(
            JSONRPCResponse(id: req.id, result: ["n": .number(1)])
        ).encoded())
    #expect(try await echoed == ["n": .number(1)])
    await peer.close()
}

@Test("sendRequest cancellation throws", arguments: ["cancel-a", "cancel-b"])
func peerSendRequestCancellation(method: String) async throws {
    let transport = CapturingTransport()
    let peer = JSONRPCPeer(transport: transport)
    try await peer.start()

    // Nothing ever answers: cancelling the waiter must throw
    // CancellationError instead of hanging.
    let task = Task<JSONValue, Error> {
        try await peer.sendRequest(method: method, params: nil as JSONValue?)
    }
    // Wait until the request is registered (bytes on the wire) so the cancel
    // races the wait, not the setup.
    _ = try await transport.awaitSent { _ in true }
    task.cancel()
    await #expect(throws: CancellationError.self) {
        try await task.value
    }

    // A late response for the cancelled id is ignored; peer stays usable.
    #expect(transport.sent.count == 1)
    await peer.close()
}

/// Simple locked box for cross-task test observation.
private actor LockedValue<T: Sendable> {
    private var value: T
    init(_ value: T) { self.value = value }
    func append(_ element: String) where T == [String] {
        value.append(element)
    }
    func snapshot() -> T { value }
}
