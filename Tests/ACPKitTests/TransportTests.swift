import Foundation
import Synchronization
import Testing

@testable import ACPKit

// MARK: - Tables

struct FramingCase: Sendable {
    var name: String
    var payloads: [String]
    var expected: [String]
}

struct DelayedAnswerCase: Sendable {
    var name: String
    var script: String
    var sends: [String]
    var expected: [String]
}

// MARK: - Helpers

/// Collects exactly `count` messages from a transport, failing loudly
/// instead of hanging the suite when delivery stalls.
private func collectMessages(
    from transport: any Transport, count: Int, timeoutNanoseconds: UInt64 = 10_000_000_000
) async throws -> [Data] {
    try await withThrowingTaskGroup(of: [Data].self) { group in
        group.addTask {
            var collected: [Data] = []
            for await message in transport.messages {
                collected.append(message)
                if collected.count == count {
                    return collected
                }
            }
            throw TableTestError.timedOut
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw TableTestError.timedOut
        }
        guard let first = try await group.next() else { throw TableTestError.timedOut }
        group.cancelAll()
        return first
    }
}

private func utf8(_ data: [Data]) -> [String] {
    data.map { String(data: $0, encoding: .utf8) ?? "<non-utf8>" }
}

/// Builds a StdioTransport over two fresh pipes, returning the transport
/// plus the ends the test drives: write lines here, read frames there.
private func makePipedStdio() -> (
    transport: StdioTransport, writeInput: FileHandle, readOutput: FileHandle
) {
    let inbound = Pipe()
    let outbound = Pipe()
    let transport = StdioTransport(
        input: inbound.fileHandleForReading, output: outbound.fileHandleForWriting)
    return (transport, inbound.fileHandleForWriting, outbound.fileHandleForReading)
}

private func writeLines(_ handle: FileHandle, _ lines: [String]) throws {
    for line in lines {
        try handle.write(contentsOf: Data((line + "\n").utf8))
    }
}

/// Reads output-pipe bytes until `newlineCount` frames arrive or the
/// deadline passes. Driven by LineReader (never blocks a thread).
private func readFrames(
    handle: FileHandle, newlineCount: Int, deadlineNanoseconds: UInt64 = 5_000_000_000
) async throws -> [String] {
    final class Box: @unchecked Sendable {
        private let items = Mutex<[String]>([])
        func append(_ s: String) { items.withLock { $0.append(s) } }
        func snapshot() -> [String] { items.withLock { $0 } }
    }
    let box = Box()
    let reader = LineReader(
        handle: handle,
        onLine: {
            if let text = String(data: $0, encoding: .utf8), !text.isEmpty {
                box.append(text)
            }
        },
        onEnd: {})
    reader.start()
    defer { reader.stop() }
    let deadline = Date().addingTimeInterval(Double(deadlineNanoseconds) / 1_000_000_000)
    while Date() < deadline {
        let lines = box.snapshot()
        if lines.count >= newlineCount {
            return Array(lines.prefix(newlineCount))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw TableTestError.timedOut
}

// Real-process and pipe tests. Each transport pumps its own reader thread
// (see LineReader), so tests stay independent of each other. Every wait is
// bounded by an explicit timeout so a stall fails loudly instead of
// hanging the suite. See plan file Step 1.
@Suite("transport integration")
struct TransportIntegrationTests {
    private final class Box: @unchecked Sendable {
        private let items = Mutex<[String]>([])
        func append(_ s: String) { items.withLock { $0.append(s) } }
        func snapshot() -> [String] { items.withLock { $0 } }
    }

    @Test("LineReader delivers buffered lines")
    func lineReaderDeliversBufferedLines() async throws {
        let pipe = Pipe()
        let box = Box()
        let reader = LineReader(
            handle: pipe.fileHandleForReading,
            onLine: { box.append(String(data: $0, encoding: .utf8) ?? "?") },
            onEnd: {})
        reader.start()
        try pipe.fileHandleForWriting.write(contentsOf: Data("a\nb\n".utf8))
        let deadline = Date().addingTimeInterval(5)
        while box.snapshot().count < 2, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        reader.stop()
        #expect(box.snapshot() == ["a", "b"])
    }

// MARK: - StdioTransport framing

    // A reader parked with no data available must not stall delivery on
    // another transport. Regression test for shared-queue head-of-line
    // blocking: transport A stays silent while B delivers.
    @Test("silent transport does not stall other transports")
    func silentTransportDoesNotStallOthers() async throws {
        let (silent, _, _) = makePipedStdio()
        let (live, writeInput, _) = makePipedStdio()
        try await silent.start()
        try await live.start()
        try writeLines(writeInput, ["hello"])
        let received = try await collectMessages(from: live, count: 1)
        #expect(utf8(received) == ["hello"])
        await silent.close()
        await live.close()
    }

    @Test(
        "stdio receives framed lines",
        arguments: [
            FramingCase(name: "single", payloads: ["hello"], expected: ["hello"]),
            FramingCase(
                name: "ordering", payloads: ["one", "two", "three"],
                expected: ["one", "two", "three"]),
            FramingCase(
                name: "empty-lines-skipped", payloads: ["a", "", "b"],
                expected: ["a", "b"]),
            FramingCase(
                name: "unicode", payloads: ["héllo 🌍 世界"],
                expected: ["héllo 🌍 世界"]),
            FramingCase(
                name: "large", payloads: [String(repeating: "x", count: 200_000)],
                expected: [String(repeating: "x", count: 200_000)]),
        ])
    func stdioReceivesFramedLines(_ c: FramingCase) async throws {
        let (transport, writeInput, _) = makePipedStdio()
        try await transport.start()
        try writeLines(writeInput, c.payloads)
        let received = try await collectMessages(from: transport, count: c.expected.count)
        #expect(utf8(received) == c.expected)
        await transport.close()
    }
    
    @Test(
        "stdio sends framed lines",
        arguments: [
            FramingCase(name: "single", payloads: ["hi"], expected: ["hi"]),
            FramingCase(
                name: "multi", payloads: ["a", "b"], expected: ["a", "b"]),
        ])
    func stdioSendsFramedLines(_ c: FramingCase) async throws {
        let (transport, _, readOutput) = makePipedStdio()
        try await transport.start()
        for payload in c.payloads {
            try await transport.send(Data(payload.utf8))
        }
        #expect(try await readFrames(handle: readOutput, newlineCount: c.expected.count) == c.expected)
        await transport.close()
    }
    
    @Test("stdio lifecycle states")
    func stdioLifecycleStates() async throws {
        let (transport, _, _) = makePipedStdio()
        try await transport.start()
        var states: [TransportState] = []
        for await state in transport.state {
            states.append(state)
            if states.count == 3 { break }
        }
        // init() yields .created; start() appends .starting then .started.
        #expect(states == [.created, .starting, .started])
        await transport.close()
    }
    
    // MARK: - ProcessTransport over real children (env-gated)
    
    @Test(
        "process echo preserves order",
        arguments: [
            FramingCase(name: "single", payloads: ["hello"], expected: ["hello"]),
            FramingCase(
                name: "multi", payloads: ["one", "two", "three"],
                expected: ["one", "two", "three"]),
        ])
    func processEchoPreservesOrder(_ c: FramingCase) async throws {
        guard FileManager.default.fileExists(atPath: "/bin/cat") else { return }
        let transport = ProcessTransport(command: "/bin/cat", args: ["-u"])
        try await transport.start()
        for payload in c.payloads {
            try await transport.send(Data(payload.utf8))
        }
        let received = try await collectMessages(from: transport, count: c.expected.count)
        #expect(utf8(received) == c.expected)
        await transport.close()
    }
    
    @Test(
        "process delayed answers arrive",
        arguments: [
            DelayedAnswerCase(
                name: "second-answer-delayed",
                script: #"read l; echo "R1: $l"; read l; sleep 1; echo "R2: $l""#,
                sends: ["L1", "L2"],
                expected: ["R1: L1", "R2: L2"]),
            DelayedAnswerCase(
                name: "first-answer-delayed",
                script: #"read l; sleep 1; echo "R1: $l"; read l; echo "R2: $l""#,
                sends: ["L1", "L2"],
                expected: ["R1: L1", "R2: L2"]),
        ])
    func processDelayedAnswersArrive(_ c: DelayedAnswerCase) async throws {
        guard FileManager.default.fileExists(atPath: "/bin/sh") else { return }
        let transport = ProcessTransport(command: "sh", args: ["-c", c.script])
        try await transport.start()
        for payload in c.sends {
            try await transport.send(Data(payload.utf8))
        }
        let received = try await collectMessages(from: transport, count: c.expected.count)
        #expect(utf8(received) == c.expected)
        await transport.close()
    }
    
    @Test("peer resolves two requests over a process with a delayed first answer")
    func peerTwoRequestsDelayedFirst() async throws {
        guard FileManager.default.fileExists(atPath: "/bin/sh") else { return }
        // sh responder: answer the first request after 1 s, later ones at once.
        // Numeric ids come straight from the peer's allocator.
        let script = """
            n=0
            while IFS= read -r l; do
              n=$((n+1))
              if [ "$n" -eq 1 ]; then sleep 1; fi
              id=$(printf '%s' "$l" | sed -n 's/.*"id": *\\([0-9][0-9]*\\).*/\\1/p')
              printf '{"jsonrpc":"2.0","id":%s,"result":{"n":%d}}\\n' "$id" "$n"
            done
            """
        let transport = ProcessTransport(command: "sh", args: ["-c", script])
        let peer = JSONRPCPeer(transport: transport)
        try await peer.start()
        // Two concurrent requests; the first answer is delayed 1 s. Both must
        // resolve (a hang here fails loudly via the sleeper, not the suite).
        let (r1, r2) = try await (
            withThrowingTaskGroup(of: JSONValue.self) { group in
                group.addTask {
                    try await peer.sendRequest(
                        method: "ping", params: ["x": "1"]) as JSONValue
                }
                group.addTask {
                    try await peer.sendRequest(
                        method: "ping", params: ["x": "2"]) as JSONValue
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    throw TableTestError.timedOut
                }
                var results: [JSONValue] = []
                while results.count < 2 {
                    guard let next = try await group.next() else { break }
                    results.append(next)
                }
                group.cancelAll()
                #expect(results.count == 2)
                return (results[0], results[1])
            })
        #expect(r1 != r2)
        for value in [r1, r2] {
            #expect(value == ["n": .number(1)] || value == ["n": .number(2)])
        }
        await peer.close()
    }
}
