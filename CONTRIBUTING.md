# Contributing

## Workflow

1. Sync types against the canonical schema (`https://agentclientprotocol.com/protocol/schema`, `schema.json` from the latest GitHub release) before changing `Sources/ACPKit/Models/`.
2. Keep `Agent`/`Client` defaults as `notImplemented`; add a handler in `AgentConnection`/`ClientConnection` only with its typed model.
3. Add/extend tests under `Tests/ACPKitTests/` (Swift Testing, `#expect`). Follow the table-driven pattern: one `@Test("behavior", arguments: [cases])` per behavior with a `Sendable` case struct (see `MCPClientTests.swift` and `TestTransports.swift` for the shared `CapturingTransport` / `AutoRespondingTransport` fakes). Add coverage as new rows, not new test funcs.
4. Run `swift build` and `swift test` before opening a PR.

## DocC

Document public types/methods with `///` comments. Docs publish automatically via `.github/workflows/docs.yml` on push to `main` (see `README.md` for the local preview command). Requires enabling GitHub Pages (source: GitHub Actions) once per repo.

## Known gaps (good first issues)

- `elicitation/create` + `elicitation/complete`: models, `AgentContext` outgoing call, `Client` + `ClientConnection` handlers.
- `SessionConfigOptionsCapabilities`: add `select`/future variants beyond `boolean`.
- Forward-compat: preserve unknown `_`-prefixed `SessionUpdate` / enum variants instead of throwing.
- Agent/client loopback tests and JSON fixture round-trips against the canonical schema.
