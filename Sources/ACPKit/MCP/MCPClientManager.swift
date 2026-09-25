import Foundation
import Logging

/// A tool discovered on an MCP server, namespaced by the owning server so that
/// identically-named tools on different servers do not collide.
public struct MCPNamespacedTool: Sendable, Equatable {
    /// The `McpServer` name from the ACP `session/new` config.
    public var serverName: String
    public var tool: MCPToolDescription

    public init(serverName: String, tool: MCPToolDescription) {
        self.serverName = serverName
        self.tool = tool
    }

    /// Stable, collision-free name for surfacing to the model
    /// (e.g. `myserver__read_file`).
    public var qualifiedName: String {
        "\(serverName)__\(tool.name)"
    }
}

/// Owns the set of MCP server connections for one agent session.
///
/// `connectAll` dials every stdio server from the ACP `session/new`
/// `mcpServers` list. Individual server failures are logged and skipped so one
/// bad entry cannot kill the session. HTTP/SSE servers are skipped with a
/// warning until an HTTP transport exists (see
/// ``MCPError/unsupportedTransport``).
public actor MCPClientManager {
    private let logger: Logger
    private let clientInfo: MCPClientInfo
    private var clients: [String: MCPClient] = [:]
    private var cachedTools: [MCPNamespacedTool] = []

    public init(
        clientInfo: MCPClientInfo = .default,
        logger: Logger = Logger(label: "ACPKit.MCPClientManager")
    ) {
        self.clientInfo = clientInfo
        self.logger = logger
    }

    /// Connects all supported servers and returns the aggregated tool list.
    @discardableResult
    public func connectAll(servers: [McpServer]) async -> [MCPNamespacedTool] {
        var aggregated: [MCPNamespacedTool] = []
        for server in servers {
            switch server {
            case .stdio(let stdio):
                do {
                    let client = try MCPClient(
                        stdio: stdio, clientInfo: clientInfo, logger: logger)
                    try await client.connect()
                    let tools = try await client.listTools()
                    clients[stdio.name] = client
                    aggregated.append(
                        contentsOf: tools.map {
                            MCPNamespacedTool(serverName: stdio.name, tool: $0)
                        })
                } catch {
                    logger.warning(
                        "Skipping MCP server '\(stdio.name)': \(error)")
                }
            case .http(let http):
                logger.warning(
                    "Skipping MCP server '\(http.name)': HTTP transport not yet supported")
            case .sse(let sse):
                logger.warning(
                    "Skipping MCP server '\(sse.name)': SSE transport not yet supported")
            }
        }
        cachedTools = aggregated
        return aggregated
    }

    /// Tools discovered by the last `connectAll` call (no network I/O).
    public var tools: [MCPNamespacedTool] { cachedTools }

    /// Calls a tool on the named server.
    public func callTool(
        serverName: String, toolName: String, arguments: [String: JSONValue]? = nil
    ) async throws -> MCPCallToolResult {
        guard let client = clients[serverName] else {
            throw MCPError.connectionClosed
        }
        return try await client.callTool(name: toolName, arguments: arguments)
    }

    /// Closes all connections. Safe to call multiple times.
    public func closeAll() async {
        for client in clients.values {
            await client.close()
        }
        clients.removeAll()
        cachedTools.removeAll()
    }
}
