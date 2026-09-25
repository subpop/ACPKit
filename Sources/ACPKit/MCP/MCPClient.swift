import Foundation
import Logging

/// An MCP client: connects to a single MCP server over a ``Transport`` and
/// speaks the MCP JSON-RPC surface (`initialize`, `tools/list`, `tools/call`,
/// `ping`, `roots/list`).
///
/// Transport framing is supplied by the caller. For stdio servers use
/// ``ProcessTransport`` via ``init(stdio:clientInfo:logger:)``; HTTP/SSE
/// servers have no transport yet (see ``MCPError/unsupportedTransport``).
public actor MCPClient {
    private let transport: any Transport
    private let peer: JSONRPCPeer
    private let logger: Logger
    private let clientInfo: MCPClientInfo

    private var connected = false
    private var serverInfo: MCPServerInfo?
    private var serverCapabilities: MCPServerCapabilities?

    public init(
        transport: any Transport,
        clientInfo: MCPClientInfo = .default,
        logger: Logger = Logger(label: "ACPKit.MCPClient")
    ) {
        self.transport = transport
        self.peer = JSONRPCPeer(transport: transport, logger: logger)
        self.logger = logger
        self.clientInfo = clientInfo
    }

    /// Creates a client for an MCP stdio server, spawning `server.command`.
    public init(
        stdio server: McpServerStdio,
        clientInfo: MCPClientInfo = .default,
        logger: Logger = Logger(label: "ACPKit.MCPClient")
    ) throws {
        guard !server.command.isEmpty else {
            throw MCPError.invalidServerConfig("stdio server '\(server.name)' has an empty command")
        }
        var env: [String: String] = [:]
        for variable in server.env {
            env[variable.name] = variable.value
        }
        let transport = ProcessTransport(
            command: server.command,
            args: server.args,
            environment: env,
            logger: logger
        )
        self.init(transport: transport, clientInfo: clientInfo, logger: logger)
    }

    public var isConnected: Bool { connected }
    public var info: MCPServerInfo? { serverInfo }
    public var capabilities: MCPServerCapabilities? { serverCapabilities }

    /// Starts the transport and performs the MCP `initialize` handshake,
    /// followed by the mandatory `notifications/initialized` notification.
    ///
    /// - Parameter timeout: maximum time to wait for the handshake response.
    ///   Defaults to 60 seconds (covers process spawn plus the round-trip), so
    ///   a server that spawns yet never answers throws
    ///   ``JSONRPCPeerError/timedOut`` instead of hanging forever.
    @discardableResult
    public func connect(timeout: TimeInterval = 60) async throws -> MCPInitializeResult {
        await registerHandlers()
        try await peer.start()

        let request = MCPInitializeRequest(clientInfo: clientInfo)
        let result = try await peer.sendRequest(
            method: "initialize", params: request, as: MCPInitializeResult.self,
            timeout: timeout)
        if result.protocolVersion != mcpProtocolVersion {
            logger.warning(
                "MCP server negotiated protocol version \(result.protocolVersion) (client proposed \(mcpProtocolVersion))")
        }
        try await peer.sendNotification(
            method: "notifications/initialized", params: EmptyParams())
        serverInfo = result.serverInfo
        serverCapabilities = result.capabilities
        connected = true
        logger.info(
            "Connected to MCP server \(result.serverInfo.name) \(result.serverInfo.version)")
        return result
    }

    /// Lists all tools, following `nextCursor` pagination until exhausted.
    ///
    /// - Parameter timeout: maximum time to wait per `tools/list` page. `nil`
    ///   waits indefinitely.
    public func listTools(timeout: TimeInterval? = nil) async throws -> [MCPToolDescription] {
        var tools: [MCPToolDescription] = []
        var cursor: String?
        repeat {
            let result = try await peer.sendRequest(
                method: "tools/list",
                params: MCPListToolsRequest(cursor: cursor),
                as: MCPListToolsResult.self,
                timeout: timeout
            )
            tools.append(contentsOf: result.tools)
            cursor = result.nextCursor
        } while cursor != nil
        return tools
    }

    /// Calls a tool by name. Returns the raw result; use ``callToolText`` when
    /// plain-text output is expected.
    ///
    /// - Parameter timeout: maximum time to wait for the response. `nil`
    ///   waits indefinitely.
    public func callTool(
        name: String, arguments: [String: JSONValue]? = nil, timeout: TimeInterval? = nil
    ) async throws -> MCPCallToolResult {
        let request = MCPCallToolRequest(
            name: name, arguments: arguments.map(JSONValue.object))
        return try await peer.sendRequest(
            method: "tools/call", params: request, as: MCPCallToolResult.self,
            timeout: timeout)
    }

    /// Calls a tool and returns its combined text output, throwing
    /// ``MCPError/toolError`` when the server reports `isError: true`.
    ///
    /// - Parameter timeout: maximum time to wait for the response. `nil`
    ///   waits indefinitely.
    @discardableResult
    public func callToolText(
        name: String, arguments: [String: JSONValue]? = nil, timeout: TimeInterval? = nil
    ) async throws -> String {
        let result = try await callTool(name: name, arguments: arguments, timeout: timeout)
        if result.isError {
            throw MCPError.toolError(result.combinedText)
        }
        return result.combinedText
    }

    public func close() async {
        connected = false
        await peer.close()
    }

    // MARK: - Server-initiated requests

    private func registerHandlers() async {
        await peer.onRequest(method: "ping") { _ in
            JSONValue.object([:])
        }
        await peer.onRequest(method: "roots/list") { _ in
            // v1 advertises no roots; return an empty list.
            try JSONValue(encoding: MCPListRootsResult())
        }
        await peer.onNotification(method: "notifications/tools/list_changed") { [weak self] _ in
            self?.logger.info("MCP server tools changed")
        }
    }
}

private struct EmptyParams: Encodable {}
