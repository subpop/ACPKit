import Foundation
import Synchronization

/// Newline-delimited frame reader pumping a file handle on a dedicated thread.
///
/// Rationale: `FileHandle.AsyncBytes` funnels every reader in the process
/// through one shared serial IO queue, so a reader parked with no data
/// available head-of-line blocks all other readers (a silent MCP server can
/// stall agent stdin reads and vice versa; a parked `read` also ignores
/// task cancellation, so cancelling doesn't help). Separately,
/// `FileHandle.read(upToCount:)` was observed to never return with data
/// available. A dedicated thread driving the raw `read` syscall keeps
/// readers independent at the cost of one thread each; threads exit on EOF
/// or `stop()`.
///
/// Framing matches the previous `bytes.lines` loops byte-for-byte: `\n`
/// terminated, `\n` stripped, empty lines passed through (callers filter).
final class LineReader: @unchecked Sendable {
    private let handle: FileHandle
    private let onLine: @Sendable (Data) -> Void
    private let onEnd: @Sendable () -> Void
    private let stopped = Mutex(false)
    private var thread: Thread?

    init(
        handle: FileHandle,
        onLine: @escaping @Sendable (Data) -> Void,
        onEnd: @escaping @Sendable () -> Void
    ) {
        self.handle = handle
        self.onLine = onLine
        self.onEnd = onEnd
    }

    func start() {
        // Pipes may arrive O_NONBLOCK (loader/runtime); a blocking read loop
        // needs blocking mode, otherwise an empty pipe reads as EOF.
        let flags = fcntl(handle.fileDescriptor, F_GETFL)
        if flags != -1 {
            _ = fcntl(handle.fileDescriptor, F_SETFL, flags & ~O_NONBLOCK)
        }
        let thread = Thread { [weak self] in self?.run() }
        self.thread = thread
        thread.start()
    }

    /// Requests shutdown. A parked `read` still needs EOF (or process exit)
    /// to return; stopping merely prevents further callbacks afterwards.
    func stop() {
        stopped.withLock { $0 = true }
        thread = nil
    }

    private func run() {
        var buffer = Data()
        while !(stopped.withLock({ $0 })) {
            var tmp = [UInt8](repeating: 0, count: 65536)
            let count: Int = tmp.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return -1 }
                return read(handle.fileDescriptor, base, raw.count)
            }
            if count > 0 {
                buffer.append(contentsOf: tmp.prefix(count))
            } else if count == 0 {
                break // EOF
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                // Non-blocking fd with nothing ready yet; poll briefly.
                Thread.sleep(forTimeInterval: 0.01)
                continue
            } else {
                break // read error: treat like EOF
            }
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[..<newline])
                if !(stopped.withLock({ $0 })) {
                    onLine(line)
                }
                buffer.removeSubrange(...newline)
            }
        }
        if !(stopped.withLock({ $0 })) {
            onEnd()
        }
    }
}
