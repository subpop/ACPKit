import Foundation

/// The interface an ACP client implementation provides. Conforming types are wrapped by
/// ``ClientConnection`` to serve requests/notifications from a connected agent over a
/// ``Transport``.
///
/// Only ``capabilities``, ``requestPermission(request:)``, and
/// ``sessionUpdate(_:)`` are required. File-system and terminal operations default to
/// throwing ``ClientError/notImplemented(method:)`` and should be overridden only if the
/// client advertises the corresponding capability.
public protocol Client: Sendable {
    /// Capabilities this client supports, sent in the `initialize` request.
    var capabilities: ClientCapabilities { get }
    /// Optional client implementation metadata, sent in the `initialize` request.
    var info: Implementation? { get }

    /// Handles `session/request_permission`.
    func requestPermission(request: RequestPermissionRequest) async throws -> RequestPermissionResponse

    /// Handles the `session/update` notification.
    func sessionUpdate(_ notification: SessionNotification) async

    /// Handles `fs/read_text_file`.
    func readTextFile(request: ReadTextFileRequest) async throws -> ReadTextFileResponse

    /// Handles `fs/write_text_file`.
    func writeTextFile(request: WriteTextFileRequest) async throws -> WriteTextFileResponse

    /// Handles `terminal/create`.
    func createTerminal(request: CreateTerminalRequest) async throws -> CreateTerminalResponse

    /// Handles `terminal/output`.
    func terminalOutput(request: TerminalOutputRequest) async throws -> TerminalOutputResponse

    /// Handles `terminal/kill`.
    func killTerminal(request: KillTerminalRequest) async throws -> KillTerminalResponse

    /// Handles `terminal/release`.
    func releaseTerminal(request: ReleaseTerminalRequest) async throws -> ReleaseTerminalResponse

    /// Handles `terminal/wait_for_exit`.
    func waitForTerminalExit(request: WaitForTerminalExitRequest) async throws -> WaitForTerminalExitResponse
}

extension Client {
    public var info: Implementation? { nil }

    public func readTextFile(request: ReadTextFileRequest) async throws -> ReadTextFileResponse {
        throw ClientError.notImplemented(method: "fs/read_text_file")
    }

    public func writeTextFile(request: WriteTextFileRequest) async throws -> WriteTextFileResponse {
        throw ClientError.notImplemented(method: "fs/write_text_file")
    }

    public func createTerminal(request: CreateTerminalRequest) async throws -> CreateTerminalResponse {
        throw ClientError.notImplemented(method: "terminal/create")
    }

    public func terminalOutput(request: TerminalOutputRequest) async throws -> TerminalOutputResponse {
        throw ClientError.notImplemented(method: "terminal/output")
    }

    public func killTerminal(request: KillTerminalRequest) async throws -> KillTerminalResponse {
        throw ClientError.notImplemented(method: "terminal/kill")
    }

    public func releaseTerminal(request: ReleaseTerminalRequest) async throws -> ReleaseTerminalResponse {
        throw ClientError.notImplemented(method: "terminal/release")
    }

    public func waitForTerminalExit(request: WaitForTerminalExitRequest) async throws -> WaitForTerminalExitResponse {
        throw ClientError.notImplemented(method: "terminal/wait_for_exit")
    }
}
