// TASK-260728-7ii1xz — keychain reachability probe.
// Privacy-safe: the stored value is a fixed non-secret literal. No real key,
// passphrase, or user secret is ever read, written, or printed.
import Foundation
import Security

let service = "works.relux.tunnel.probe.7ii1xz"
let placeholder = "PROBE-NOT-A-SECRET".data(using: .utf8)!

func base(_ account: String, dp: Bool, group: String?) -> [String: Any] {
    var q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
    ]
    if dp { q[kSecUseDataProtectionKeychain as String] = true }
    if let g = group { q[kSecAttrAccessGroup as String] = g }
    return q
}

func report(_ label: String, _ status: OSStatus) {
    let msg = SecCopyErrorMessageString(status, nil) as String? ?? "?"
    print("\(label): OSStatus=\(status) (\(msg))")
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: kcprobe <add|read|delete> <account> [--file] [--group G]\n".data(using: .utf8)!)
    exit(64)
}
let op = args[1]
let account = args[2]
let dp = !args.contains("--file")
var group: String? = nil
if let i = args.firstIndex(of: "--group"), i + 1 < args.count { group = args[i + 1] }

let ctx = "uid=\(getuid()) euid=\(geteuid()) keychain=\(dp ? "data-protection" : "file-based") group=\(group ?? "-")"
print("context: \(ctx)")

switch op {
case "add":
    var q = base(account, dp: dp, group: group)
    q[kSecValueData as String] = placeholder
    report("SecItemAdd", SecItemAdd(q as CFDictionary, nil))
case "read":
    var q = base(account, dp: dp, group: group)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: CFTypeRef?
    let st = SecItemCopyMatching(q as CFDictionary, &out)
    report("SecItemCopyMatching", st)
    if st == errSecSuccess, let d = out as? Data {
        // Print only length + whether it equals the known non-secret placeholder.
        print("value: bytes=\(d.count) matchesPlaceholder=\(d == placeholder)")
    }
case "delete":
    report("SecItemDelete", SecItemDelete(base(account, dp: dp, group: group) as CFDictionary))
default:
    exit(64)
}
