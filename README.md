# ACPKit

Swift implementation of the [Agent Client Protocol](https://agentclientprotocol.com/) (ACP, `protocolVersion: 1`): typed models, JSON-RPC transport, and agent/client connections over stdio.

## Layout

| Path | Description |
| --- | --- |
| `Sources/ACPKit/Models/` | Codable request/response/notification types: sessions, updates, tool calls, terminals, fs ops, auth, MCP servers, capabilities, `_meta` passthrough. |
| `Sources/ACPKit/JSONRPC/` | `JSONRPCPeer` (request/notification dispatch), `StdioTransport`, `Transport`, `JSONValue`, `RequestID`. |
| `Sources/ACPKit/Agent/` | `Agent` protocol, `AgentConnection` (serves `initialize`, `session/*`, `authenticate`, `logout`), `AgentContext` (outgoing `session/update`, `session/request_permission`, fs, terminal). |
| `Sources/ACPKit/Client/` | `Client` protocol, `ClientConnection` (serves `session/request_permission`, `session/update`, fs, terminal; drives `initialize`, `session/*`, auth). |

## Usage

Implement an agent (only `capabilities`, `createSession`, `handlePrompt` are required):

```swift
import ACPKit

struct MyAgent: Agent {
    var capabilities: AgentCapabilities { AgentCapabilities() }

    func createSession(request: NewSessionRequest) async throws -> NewSessionResponse {
        NewSessionResponse(sessionId: SessionId("sess_1"))
    }

    func handlePrompt(request: PromptRequest, context: AgentContext) async throws -> PromptResponse {
        try await context.sendTextMessage("Hello")
        return PromptResponse(stopReason: .endTurn)
    }
}

let connection = AgentConnection(transport: StdioTransport(), agent: MyAgent())
try await connection.start()
```

Drive an agent as a client:

```swift
import ACPKit

struct MyClient: Client {
    var capabilities: ClientCapabilities { ClientCapabilities() }

    func requestPermission(request: RequestPermissionRequest) async throws -> RequestPermissionResponse {
        RequestPermissionResponse(outcome: .cancelled)
    }

    func sessionUpdate(_ notification: SessionNotification) async {
        print(notification.update)
    }
}

let connection = ClientConnection(transport: StdioTransport(), client: MyClient())
let initResponse = try await connection.connect()
let session = try await connection.newSession(NewSessionRequest(cwd: "/tmp", mcpServers: []))
let result = try await connection.prompt(PromptRequest(sessionId: session.sessionId, prompt: [.text("Hi")]))
```

All other `Agent`/`Client` methods default to `notImplemented` errors; override only what the advertised capabilities require.

## Build & test

```sh
swift build
swift test
```

## Documentation

API reference is generated with Swift DocC and published to GitHub Pages by
`.github/workflows/docs.yml` on every push to `main`.

Preview locally:

```sh
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target ACPKit \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path ACPKit
```

## Feature coverage

Implements ACP v1 core: `initialize`, `session/new|load|resume|prompt|cancel|list|close|delete|set_mode|set_config_option`, `session/update`, `session/request_permission`, `fs/read_text_file|write_text_file`, `terminal/create|output|kill|release|wait_for_exit`, `authenticate|logout`, with capability gating in `AgentSessionContext`.

## Future enhancements

Not yet implemented (see `CONTRIBUTING.md` for schema-sync process):

- `elicitation/create` + `elicitation/complete` (form/url elicitation, `ElicitationSchema`, request-scoped elicitation). `ElicitationCapabilities` exists but no models, handlers, or `AgentContext`/`Client` methods use it.
- Full `SessionConfigOptionsCapabilities`: only `boolean` is modeled; add `select`/future variants when confirmed in the schema.
- Forward-compatible decoding: `SessionUpdate` throws on unknown `sessionUpdate` tags (`Sources/ACPKit/Models/SessionUpdate.swift`); unknown `_`-prefixed extensions should be preserved, not rejected.
- ACP v2 draft: `state_update`, full message updates, `git_patch` diffs, uniform ID patching semantics. This package targets v1 only.
- Tests: `Tests/ACPKitTests/ACPKitTests.swift` is a placeholder; no round-trip or agent/client interop coverage yet.
