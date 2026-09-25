import Foundation

/// A `Transport` that frames JSON-RPC messages as newline-delimited JSON (ND-JSON) over
/// a pair of `FileHandle`s. This is the standard transport for ACP: agents are invoked
/// as subprocesses communicating over their own real stdin/stdout.
///
/// Diagnostic logging must never be written to `output` (stdout), since stdout is
/// reserved exclusively for JSON-RPC message framing; use stderr (or a `Logging.Logger`
/// backend pointed at stderr) instead.
public final class StdioTransport: Transport, @unchecked Sendable {
    private let input: FileHandle
    private let writer: WriteCoordinator

    public let messages: AsyncStream<Data>
    private let messagesContinuation: AsyncStream<Data>.Continuation

    public let state: AsyncStream<TransportState>
    private let stateContinuation: AsyncStream<TransportState>.Continuation

    private var reader: LineReader?

    public init(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        self.input = input
        self.writer = WriteCoordinator(output: output)

        var messagesContinuation: AsyncStream<Data>.Continuation!
        self.messages = AsyncStream { messagesContinuation = $0 }
        self.messagesContinuation = messagesContinuation

        var stateContinuation: AsyncStream<TransportState>.Continuation!
        self.state = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation
        stateContinuation.yield(.created)
    }

    public func start() async throws {
        stateContinuation.yield(.starting)
        let input = self.input
        let messagesContinuation = self.messagesContinuation
        let stateContinuation = self.stateContinuation
        // Dedicated reader thread (see LineReader): never parks shared
        // executors while waiting for input.
        let reader = LineReader(
            handle: input,
            onLine: { line in
                guard !line.isEmpty else { return }
                messagesContinuation.yield(line)
            },
            onEnd: {
                messagesContinuation.finish()
                stateContinuation.yield(.closed)
                stateContinuation.finish()
            })
        reader.start()
        self.reader = reader
        stateContinuation.yield(.started)
    }

    public func send(_ data: Data) async throws {
        var payload = data
        payload.append(0x0A)
        try await writer.write(payload)
    }

    public func close() async {
        stateContinuation.yield(.closing)
        reader?.stop()
    }
}

/// Serializes writes to the output `FileHandle` so that concurrently-sent messages
/// cannot interleave their bytes on the wire.
private actor WriteCoordinator {
    private let output: FileHandle

    init(output: FileHandle) {
        self.output = output
    }

    func write(_ data: Data) throws {
        try output.write(contentsOf: data)
    }
}
