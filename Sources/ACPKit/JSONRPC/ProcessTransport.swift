import Foundation
import Logging
import Synchronization

/// Errors thrown by ``ProcessTransport``.
public enum ProcessTransportError: Error, Sendable, Equatable {
    case alreadyStarted
    case notStarted
    case launchFailed(String)
}

/// A ``Transport`` that spawns a child process and frames JSON-RPC messages as
/// newline-delimited JSON (ND-JSON) over its stdin/stdout.
///
/// This is the standard transport for MCP stdio servers: the client launches the
/// configured command and speaks to it through pipes. (Contrast with
/// ``StdioTransport``, which binds to the *current* process's own stdin/stdout
/// and is used when *we* are the subprocess, e.g. ACP agent mode.)
///
/// Diagnostic logging must never be written to the child's stdin; stderr output
/// from the child is forwarded to the configured `Logger`.
public final class ProcessTransport: Transport, @unchecked Sendable {
    private let command: String
    private let args: [String]
    private let environment: [String: String]?
    private let currentDirectory: String?
    private let logger: Logger

    public let messages: AsyncStream<Data>
    private let messagesContinuation: AsyncStream<Data>.Continuation

    public let state: AsyncStream<TransportState>
    private let stateContinuation: AsyncStream<TransportState>.Continuation

    private let stdinWriter = StdinWriter()
    private let mutex = Mutex<ProcessState>(ProcessState())
    private struct ProcessState {
        var process: Process?
        var started = false
        var closed = false
        var readers: [LineReader] = []
    }

    public init(
        command: String,
        args: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: String? = nil,
        logger: Logger = Logger(label: "ACPKit.ProcessTransport")
    ) {
        self.command = command
        self.args = args
        self.environment = environment
        self.currentDirectory = currentDirectory
        self.logger = logger

        var messagesContinuation: AsyncStream<Data>.Continuation!
        self.messages = AsyncStream { messagesContinuation = $0 }
        self.messagesContinuation = messagesContinuation

        var stateContinuation: AsyncStream<TransportState>.Continuation!
        self.state = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation
        stateContinuation.yield(.created)
    }

    public func start() async throws {
        let alreadyStarted = mutex.withLock { (state: inout ProcessState) -> Bool in
            if state.started { return true }
            state.started = true
            return false
        }
        if alreadyStarted {
            throw ProcessTransportError.alreadyStarted
        }

        stateContinuation.yield(.starting)

        let process = Process()
        if command.contains("/") {
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = args
        } else {
            // Resolve via PATH so bare commands like "npx" or "uvx" work.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + args
        }
        if let environment {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                merged[key] = value
            }
            process.environment = merged
        }
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            mutex.withLock { (state: inout ProcessState) in state.started = false }
            throw ProcessTransportError.launchFailed("\(error)")
        }

        mutex.withLock { (state: inout ProcessState) in state.process = process }

        await stdinWriter.set(handle: inputPipe.fileHandleForWriting)

        let outputHandle = outputPipe.fileHandleForReading
        let messagesContinuation = self.messagesContinuation
        let stateContinuation = self.stateContinuation
        // Dedicated reader threads (see LineReader): a silent server must
        // never stall other channels by parking shared executors.
        let readReader = LineReader(
            handle: outputHandle,
            onLine: { line in
                guard !line.isEmpty else { return }
                messagesContinuation.yield(line)
            },
            onEnd: {
                messagesContinuation.finish()
                stateContinuation.yield(.closed)
                stateContinuation.finish()
            })
        readReader.start()

        let errorHandle = errorPipe.fileHandleForReading
        let logger = self.logger
        let command = self.command
        let stderrReader = LineReader(
            handle: errorHandle,
            onLine: { line in
                if let text = String(data: line, encoding: .utf8) {
                    logger.debug("MCP server (\(command)) stderr: \(text)")
                }
            },
            onEnd: {})
        stderrReader.start()
        mutex.withLock { (state: inout ProcessState) in
            state.readers = [readReader, stderrReader]
        }

        stateContinuation.yield(.started)
    }

    public func send(_ data: Data) async throws {
        var payload = data
        payload.append(0x0A)
        try await stdinWriter.write(payload)
    }

    public func close() async {
        let snapshot = mutex.withLock { (state: inout ProcessState) -> (alreadyClosed: Bool, process: Process?) in
            let alreadyClosed = state.closed
            state.closed = true
            return (alreadyClosed, state.process)
        }
        guard !snapshot.alreadyClosed else { return }
        stateContinuation.yield(.closing)
        let readers = mutex.withLock { (state: inout ProcessState) -> [LineReader] in
            let readers = state.readers
            state.readers = []
            return readers
        }
        for reader in readers {
            reader.stop()
        }
        snapshot.process?.terminate()
        await stdinWriter.invalidate()
        mutex.withLock { (state: inout ProcessState) in state.process = nil }
    }
}

/// Serializes writes to the child process's stdin so concurrently-sent messages
/// cannot interleave their bytes on the wire.
private actor StdinWriter {
    private var handle: FileHandle?

    func set(handle: FileHandle) {
        self.handle = handle
    }

    func write(_ data: Data) throws {
        guard let handle else { throw ProcessTransportError.notStarted }
        try handle.write(contentsOf: data)
    }

    func invalidate() {
        if let handle {
            try? handle.close()
        }
        handle = nil
    }
}
