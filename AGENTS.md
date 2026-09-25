# AGENTS.md

## Commands

```sh
swift build
swift test
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target ACPKit \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path ACPKit
```

`swift test` currently runs a placeholder (`Tests/ACPKitTests/ACPKitTests.swift`).

## Structure

- `Sources/ACPKit/Models/`: wire types, all `Codable` with `_meta` passthrough. Method-name strings live in `Agent/` + `Client/`, not here.
- `Sources/ACPKit/JSONRPC/`: `Transport` protocol, `StdioTransport` (ND-JSON over `FileHandle`), `JSONRPCPeer` (symmetric dispatch, `-32601` unknown method / `-32602` invalid params / `-32603` internal via `JSONRPCErrorConvertible`).
- `Sources/ACPKit/Agent/`: `Agent` protocol (required: `capabilities`, `createSession`, `handlePrompt`; rest default to `AgentError.notImplemented`), `AgentConnection` actor (registers `initialize`, `session/*`, `authenticate`, `logout`, `session/cancel`; tracks in-flight prompts by `SessionId` for cooperative cancellation), `AgentContext` / `AgentSessionContext` (outgoing calls, capability-gated).
- `Sources/ACPKit/Client/`: `Client` protocol (required: `capabilities`, `requestPermission`, `sessionUpdate`; fs/terminal default to `ClientError.notImplemented`), `ClientConnection` actor (`start()` vs `connect()` which also sends `initialize`; outgoing `session/*` + auth calls).

## Conventions

- Swift 6, `Sendable` throughout; `swift-tools-version: 6.4` with `ApproachableConcurrency` enabled.
- Use `Synchronization.Mutex` (not `NSLock`) for shared mutable state: `import Synchronization`, hold protected state inside `Mutex<State>` and access via `withLock`. Requires macOS 15+ (see `platforms` in `Package.swift`).
- `acpProtocolVersion: ProtocolVersion = 1` in `Models/Identifiers.swift`; version negotiation in `AgentConnection.handleInitialize` echoes client version only on exact match.
- Keep `Codable` keys camelCase; discriminator values snake_case; preserve unknown `_`-prefixed extensions where supported (`ToolKind.other`, `SessionConfigOptionCategory.other`).
- Capability gating belongs in `AgentSessionContext`, not in `Agent` implementations.
- Runtime dependency: `swift-log`. Build-time only: `swift-docc-plugin` (DocC generation).
- Tests are table-driven (Swift Testing): one `@Test("name", arguments: [cases])` per behavior group with a `Sendable` case struct (`name` field for failure identification, expected-value field, single assertion path). Add new cases as rows, not new funcs. Shared fakes live in `Tests/ACPKitTests/TestTransports.swift` (`CapturingTransport`, `AutoRespondingTransport`, loopback pair). Single-test exception only for env-gated tests (e.g. `/bin/cat` echo).
