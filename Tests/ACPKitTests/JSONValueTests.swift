import Foundation
import Testing

@testable import ACPKit

struct JSONLiteralCase: Sendable {
    var name: String
    var value: JSONValue
    var json: String
}

struct JSONAccessorCase: Sendable {
    var name: String
    var value: JSONValue
    var string: String?
    var arrayCount: Int?
    var objectKeys: [String]?
}

@Test("literals round-trip", arguments: [
    JSONLiteralCase(name: "null", value: nil, json: "null"),
    JSONLiteralCase(name: "bool", value: true, json: "true"),
    JSONLiteralCase(name: "int", value: 42, json: "42"),
    JSONLiteralCase(name: "float", value: 1.5, json: "1.5"),
    JSONLiteralCase(name: "string", value: "hi", json: "\"hi\""),
    JSONLiteralCase(name: "array", value: [1, "a"], json: "[1,\"a\"]"),
    JSONLiteralCase(name: "object", value: ["a": 1], json: "{\"a\":1}"),
])
func jsonLiterals(_ c: JSONLiteralCase) throws {
    let data = try JSONEncoder.acpEncoder.encode(c.value)
    let decoded = try JSONDecoder.acpDecoder.decode(JSONValue.self, from: data)
    #expect(decoded == c.value)
    // Canonical JSON spot-check: re-decode the expected JSON text too.
    let fromText = try JSONDecoder.acpDecoder.decode(
        JSONValue.self, from: Data(c.json.utf8))
    #expect(fromText == c.value)
}

@Test("accessors", arguments: [
    JSONAccessorCase(
        name: "string", value: "hi", string: "hi", arrayCount: nil, objectKeys: nil),
    JSONAccessorCase(
        name: "non-string", value: 1, string: nil, arrayCount: nil, objectKeys: nil),
    JSONAccessorCase(
        name: "array", value: [1, 2], string: nil, arrayCount: 2, objectKeys: nil),
    JSONAccessorCase(
        name: "object", value: ["a": 1], string: nil, arrayCount: nil, objectKeys: ["a"]),
    JSONAccessorCase(
        name: "null", value: nil, string: nil, arrayCount: nil, objectKeys: nil),
])
func jsonAccessors(_ c: JSONAccessorCase) {
    #expect(c.value.stringValue == c.string)
    #expect(c.value.arrayValue?.count == c.arrayCount)
    #expect(c.value.objectValue.map { Array($0.keys).sorted() } == c.objectKeys)
}

@Test("bool decodes before number", arguments: [true, false])
func jsonBoolNotNumber(flag: Bool) throws {
    let value: JSONValue = flag ? true : false
    let data = try JSONEncoder.acpEncoder.encode(value)
    let decoded = try JSONDecoder.acpDecoder.decode(JSONValue.self, from: data)
    #expect(decoded == .bool(flag))
}

@Test("encode-decode helper round-trip", arguments: [
    (name: "struct", text: "hello"),
    (name: "empty", text: ""),
])
func jsonHelperRoundTrip(c: (name: String, text: String)) throws {
    let original = TextContent(text: c.text)
    let value = try JSONValue(encoding: original)
    let decoded: TextContent = try value.decode(as: TextContent.self)
    #expect(decoded == original)
}

@Test("taggedObject merges discriminator", arguments: [
    (name: "type", key: "type", tag: "text"),
    (name: "sessionUpdate", key: "sessionUpdate", tag: "plan"),
])
func jsonTaggedObject(c: (name: String, key: String, tag: String)) throws {
    let payload = TextContent(text: "hi")
    let tagged = try JSONValue.taggedObject(tag: c.key, value: c.tag, payload: payload)
    #expect(tagged.objectValue?[c.key] == .string(c.tag))
    #expect(tagged.objectValue?["text"] == .string("hi"))
}
