import Foundation
import Testing

@testable import ACPKit

struct RequestIDCase: Sendable {
    var name: String
    var id: RequestID
    var json: String
}

@Test(
    "request id codec",
    arguments: [
        RequestIDCase(name: "string", id: "abc", json: "\"abc\""),
        RequestIDCase(name: "number", id: 7, json: "7"),
        RequestIDCase(name: "zero", id: 0, json: "0"),
    ])
func requestIDCodec(_ c: RequestIDCase) throws {
    let data = try JSONEncoder.acpEncoder.encode(c.id)
    #expect(String(decoding: data, as: UTF8.self) == c.json)
    let decoded = try JSONDecoder.acpDecoder.decode(RequestID.self, from: data)
    #expect(decoded == c.id)
}

@Test(
    "message discrimination",
    arguments: [
        (name: "request", json: #"{"jsonrpc":"2.0","id":1,"method":"m","params":{"a":1}}"#),
        (name: "notification", json: #"{"jsonrpc":"2.0","method":"m","params":{"a":1}}"#),
        (name: "response", json: #"{"jsonrpc":"2.0","id":"x","result":{"ok":true}}"#),
        (name: "error", json: #"{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"nf"}}"#),
        (name: "error-no-id", json: #"{"jsonrpc":"2.0","error":{"code":-32603,"message":"boom"}}"#),
    ])
func messageDiscrimination(c: (name: String, json: String)) throws {
    let message = try JSONRPCMessage(data: Data(c.json.utf8))
    switch c.name {
    case "request":
        guard case .request(let req) = message else {
            Issue.record("expected request for \(c.name)")
            return
        }
        #expect(req.method == "m")
    case "notification":
        guard case .notification(let notif) = message else {
            Issue.record("expected notification for \(c.name)")
            return
        }
        #expect(notif.method == "m")
    case "response":
        guard case .response(let resp) = message else {
            Issue.record("expected response for \(c.name)")
            return
        }
        #expect(resp.id == "x")
    case "error", "error-no-id":
        guard case .error = message else {
            Issue.record("expected error for \(c.name)")
            return
        }
    default:
        Issue.record("unknown case \(c.name)")
    }
    // Re-encode round-trips through the same variant.
    let reencoded = try message.encoded()
    let decodedAgain = try JSONRPCMessage(data: reencoded)
    switch (message, decodedAgain) {
    case (.request(let a), .request(let b)): #expect(a == b)
    case (.notification(let a), .notification(let b)): #expect(a == b)
    case (.response(let a), .response(let b)): #expect(a == b)
    case (.error(let a), .error(let b)): #expect(a == b)
    default: Issue.record("variant changed on re-encode for \(c.name)")
    }
}

@Test(
    "message decoding failures",
    arguments: [
        (name: "unrecognized", json: #"{"jsonrpc":"2.0","id":1}"#),
        (name: "response-missing-id", json: #"{"jsonrpc":"2.0","result":{}}"#),
    ])
func messageDecodingFailures(c: (name: String, json: String)) {
    #expect(throws: Error.self) {
        try JSONRPCMessage(data: Data(c.json.utf8))
    }
}
