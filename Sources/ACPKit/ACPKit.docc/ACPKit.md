# ``ACPKit``

Swift implementation of the Agent Client Protocol (ACP, `protocolVersion: 1`).

## Overview

ACPKit implements the core ACP pieces:

- Model `session/new`, `session/prompt`, and related requests with `Codable`
  types such as ``PromptRequest``, ``PromptResponse``, and ``NewSessionRequest``,
  identified by ``SessionId``.
- Exchange ND-JSON messages with ``JSONRPCPeer`` over a ``Transport`` such as
  ``StdioTransport`` or ``ProcessTransport``, using ``JSONValue`` and ``RequestID``.
- Serve an agent with ``Agent`` by implementing `capabilities`, `createSession`,
  and `handlePrompt`, hosted by ``AgentConnection`` and replying through
  ``AgentContext``.
- Drive an agent as a client with ``Client``, hosted by ``ClientConnection``,
  receiving ``SessionNotification`` values carrying ``SessionUpdate`` and
  ``ContentBlock`` payloads.

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

let agentConnection = AgentConnection(transport: StdioTransport(), agent: MyAgent())
try await agentConnection.start()
```

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

let clientConnection = ClientConnection(transport: StdioTransport(), client: MyClient())
let initResponse = try await clientConnection.connect()
let session = try await clientConnection.newSession(NewSessionRequest(cwd: "/tmp", mcpServers: []))
let result = try await clientConnection.prompt(PromptRequest(sessionId: session.sessionId, prompt: [.text("Hi")]))
```

## Topics

### Agent

- ``Agent``
- ``AgentConnection``
- ``AgentContext``
- ``AgentError``

### Client

- ``Client``
- ``ClientConnection``
- ``ClientError``

### Transport

- ``Transport``
- ``StdioTransport``
- ``ProcessTransport``
- ``JSONRPCPeer``
- ``JSONValue``
- ``RequestID``

### Sessions

- ``SessionId``
- ``NewSessionRequest``
- ``NewSessionResponse``
- ``PromptRequest``
- ``PromptResponse``
- ``CancelNotification``

### Updates

- ``SessionUpdate``
- ``SessionNotification``
- ``ContentBlock``
- ``ToolCall``
- ``ToolCallUpdate``

### Capabilities

- ``AgentCapabilities``
- ``ClientCapabilities``
- ``Implementation``
- ``InitializeRequest``
- ``InitializeResponse``
