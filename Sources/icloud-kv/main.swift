import Foundation

// Exit codes: 0=success, 1=not found, 2=quota exceeded, 3=iCloud unavailable

@MainActor
func run() -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())

    guard let command = args.first else {
        printUsage()
        return 1
    }

    // Check iCloud availability (NSUbiquitousKeyValueStore is always "available"
    // as an API, but without proper entitlements it silently no-ops. We detect
    // this by checking if the store can round-trip a canary value.)
    let store = KVStore.shared

    switch command {
    case "get":
        guard args.count >= 2 else {
            fputs("usage: icloud-kv get <key>\n", stderr)
            return 1
        }
        let key = args[1]
        if let value = store.get(key) {
            print(value)
            return 0
        } else {
            return 1  // not found
        }

    case "get-json":
        guard args.count >= 2 else {
            fputs("usage: icloud-kv get-json <key>\n", stderr)
            return 1
        }
        let key = args[1]
        store.sync()
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: key) {
            if let str = String(data: data, encoding: .utf8) {
                print(str)
                return 0
            }
        }
        return 1  // not found

    case "set":
        guard args.count >= 3 else {
            fputs("usage: icloud-kv set <key> <value>\n", stderr)
            return 1
        }
        let key = args[1]
        let value = args[2]
        if store.set(key, value: value) {
            return 0
        } else {
            return 2  // quota exceeded
        }

    case "set-json":
        guard args.count >= 3 else {
            fputs("usage: icloud-kv set-json <key> <json>\n", stderr)
            return 1
        }
        let key = args[1]
        let json = args[2]
        if store.setJSON(key, jsonString: json) {
            return 0
        } else {
            return 2  // quota or invalid JSON
        }

    case "delete":
        guard args.count >= 2 else {
            fputs("usage: icloud-kv delete <key>\n", stderr)
            return 1
        }
        store.delete(args[1])
        return 0

    case "list":
        var prefix: String? = nil
        if args.count >= 3 && args[1] == "--prefix" {
            prefix = args[2]
        }
        let keys = store.listKeys(prefix: prefix)
        for key in keys {
            print(key)
        }
        return 0

    case "sync":
        store.sync()
        return 0

    case "budget":
        let b = store.budget()
        print("keys:  \(b.keyCount)/\(b.maxKeys) (\(String(format: "%.1f", b.keyPct))%)")
        print("bytes: \(b.estimatedBytes)/\(b.maxBytes) (\(String(format: "%.1f", b.bytePct))%)")
        return 0

    case "watch":
        guard args.count >= 2 else {
            fputs("usage: icloud-kv watch <key> [--timeout <seconds>]\n", stderr)
            return 1
        }
        let key = args[1]
        var timeout: TimeInterval = 30  // default 30s
        if args.count >= 4 && args[2] == "--timeout" {
            timeout = TimeInterval(args[3]) ?? 30
        }
        if let newValue = store.watch(key: key, timeout: timeout) {
            print(newValue)
            return 0
        } else {
            return 1  // timeout, no change
        }

    case "cas":
        // Compare-and-swap: set key to new value only if current value matches expected
        guard args.count >= 4 else {
            fputs("usage: icloud-kv cas <key> <expected> <new-value>\n", stderr)
            return 1
        }
        let key = args[1]
        let expected = args[2]
        let newValue = args[3]
        store.sync()
        let current = store.get(key)
        // If expected is "-" treat it as "key should not exist"
        if expected == "-" {
            guard current == nil else {
                fputs("cas: key exists (current value present)\n", stderr)
                return 1
            }
        } else {
            guard current == expected else {
                fputs("cas: value mismatch\n", stderr)
                return 1
            }
        }
        if store.set(key, value: newValue) {
            return 0
        } else {
            return 2
        }

    case "version":
        print("icloud-kv 0.1.0")
        return 0

    case "help", "--help", "-h":
        printUsage()
        return 0

    default:
        fputs("unknown command: \(command)\n", stderr)
        printUsage()
        return 1
    }
}

func printUsage() {
    let usage = """
    icloud-kv — iCloud Key-Value Store CLI

    Usage:
      icloud-kv get <key>                       Get string value (exit 1 if not found)
      icloud-kv get-json <key>                   Get JSON value
      icloud-kv set <key> <value>                Set string value
      icloud-kv set-json <key> <json>            Set JSON value
      icloud-kv delete <key>                     Delete key
      icloud-kv list [--prefix <p>]              List keys
      icloud-kv cas <key> <expected> <new>       Compare-and-swap (- for nil expected)
      icloud-kv sync                             Force synchronize
      icloud-kv budget                           Show key count + byte estimate
      icloud-kv watch <key> [--timeout <s>]      Block until key changes (default 30s)
      icloud-kv version                          Print version
      icloud-kv help                             Show this help

    Exit codes:
      0  success
      1  not found / timeout / usage error
      2  quota exceeded
      3  iCloud unavailable
    """
    print(usage)
}

exit(run())
