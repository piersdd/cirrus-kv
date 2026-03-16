# Cirrus KV

A Swift CLI wrapping Apple's `NSUbiquitousKeyValueStore` for sub-second cross-device coordination via iCloud.

Designed for agentic dispatch systems where multiple machines need lightweight coordination primitives (locks, heartbeats, saga markers) without a dedicated server. All state is transient — durable data belongs elsewhere.

## Why

iCloud KV Store provides free, zero-infrastructure key-value storage that syncs across all devices signed into the same Apple ID. It's ideal for coordination signals between machines:

- **Distributed locks** — first machine to `cas` a lock key wins
- **Heartbeats** — periodic `set` proves liveness to peers
- **Saga checkpoints** — step markers for crash-resumable workflows
- **Writer claims** — advisory single-writer coordination

Apple enforces hard limits: **1,024 keys** and **1 MB** total storage. This is a feature, not a limitation — it forces the store to stay transient.

## Commands

```
cirrus-kv get <key>                       Get string value
cirrus-kv get-json <key>                  Get JSON value
cirrus-kv set <key> <value>               Set string value
cirrus-kv set-json <key> <json>           Set JSON value
cirrus-kv delete <key>                    Delete key
cirrus-kv list [--prefix <p>]             List keys (optionally filtered)
cirrus-kv cas <key> <expected> <new>      Compare-and-swap (use - for nil)
cirrus-kv sync                            Force iCloud synchronization
cirrus-kv budget                          Show key count and byte usage
cirrus-kv watch <key> [--timeout <s>]     Block until key changes (default 30s)
cirrus-kv version                         Print version
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Not found / timeout / usage error |
| 2 | Quota exceeded |
| 3 | iCloud unavailable |

## Building

Requires macOS 13+, Swift 6, and a **Developer ID Application** certificate with iCloud KV entitlement.

### Prerequisites

1. **Apple Developer Program** membership
2. **Developer ID Application** certificate installed in Keychain
3. **App ID** registered with iCloud Key-Value Storage capability (bundle ID: `cc.digitalassistant.cirrus-kv`)
4. **Developer ID provisioning profile** downloaded and installed to `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`

### Build and install

```sh
make install
```

This builds a release binary, signs it with your Developer ID certificate and iCloud entitlements, wraps it in a minimal `.app` bundle (required by macOS AMFI for provisioning profile validation), and symlinks the binary to `~/.local/bin/cirrus-kv`.

The `.app` bundle is not a GUI application (`LSUIElement = true`) — it exists solely to satisfy macOS code signing requirements for restricted entitlements.

### Verify

```sh
cirrus-kv budget
# keys:  0/1024 (0.0%)
# bytes: 0/1048576 (0.0%)
```

## Key naming convention

Keys are namespaced by prefix to partition the 1,024-key budget:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `lock/` | Distributed locks | `lock/pkm-operator-process-inbox` |
| `heartbeat/` | Machine liveness | `heartbeat/viper` |
| `saga/` | Workflow checkpoints | `saga/daily-digest-step` |
| `writer/` | Single-writer claims | `writer/+/ingest` |
| `test/` | Ephemeral testing | `test/hello` |

## Graceful degradation

All consumers gate on `[ -x "$CIRRUS_KV" ]` before use. When the binary is absent or unsigned, the system falls back to file-based coordination (lock files, local timestamps). No hard dependency on iCloud availability.

## License

Private.
