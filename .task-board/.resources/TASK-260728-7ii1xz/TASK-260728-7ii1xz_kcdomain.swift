// TASK-260728-7ii1xz — system-domain keychain resolution probe (rework r2).
//
// Purpose: settle reviewer finding F2 physically. The r1 contract hard-coded
// "/Library/Keychains/System.keychain". Apple DTS says do not hard code that
// path and resolve the system-domain keychain instead. This probe proves the
// supported resolution works, prints the RESOLVED PATH ONLY, and demonstrates
// the correct SecItem key split:
//   - SecItemAdd            -> kSecUseKeychain      (a SecKeychainRef)
//   - SecItemCopyMatching   -> kSecMatchSearchList  (an array of SecKeychainRef)
//
// Privacy: the only value ever written is the fixed non-secret literal
// "PROBE-NOT-A-SECRET". The throwaway keychain's unlock password is random
// bytes that are never printed and never persisted. No user secret is read,
// written, or printed. No item is created in the real System keychain.

import Foundation
import Security

func line(_ s: String) { print(s) }

func msg(_ st: OSStatus) -> String {
    (SecCopyErrorMessageString(st, nil) as String?) ?? "?"
}

func report(_ label: String, _ st: OSStatus) {
    line("\(label): OSStatus=\(st) (\(msg(st)))")
}

/// Path of a keychain reference. A filesystem path is not a secret.
func path(of kc: SecKeychain) -> String {
    var len = UInt32(PATH_MAX)
    var buf = [Int8](repeating: 0, count: Int(PATH_MAX))
    let st = SecKeychainGetPath(kc, &len, &buf)
    guard st == errSecSuccess else { return "<SecKeychainGetPath OSStatus=\(st)>" }
    return String(cString: buf)
}

let domains: [(String, SecPreferencesDomain)] = [
    ("kSecPreferencesDomainUser", .user),
    ("kSecPreferencesDomainSystem", .system),
    ("kSecPreferencesDomainCommon", .common),
]

line("context: uid=\(getuid()) euid=\(geteuid())")
line("")

// ---- E8: SecKeychainCopyDomainDefault ---------------------------------------
line("== E8: SecKeychainCopyDomainDefault(domain) -> resolved path ==")
for (name, d) in domains {
    var kc: SecKeychain?
    let st = SecKeychainCopyDomainDefault(d, &kc)
    if st == errSecSuccess, let kc {
        line("E8 \(name): OSStatus=0 path=\(path(of: kc))")
    } else {
        report("E8 \(name)", st)
    }
}
line("")

// ---- E9: SecKeychainCopyDomainSearchList ------------------------------------
line("== E9: SecKeychainCopyDomainSearchList(domain) -> resolved paths ==")
for (name, d) in domains {
    var listRef: CFArray?
    let st = SecKeychainCopyDomainSearchList(d, &listRef)
    guard st == errSecSuccess, let list = listRef as? [SecKeychain] else {
        report("E9 \(name)", st)
        continue
    }
    line("E9 \(name): OSStatus=0 count=\(list.count)")
    for kc in list { line("E9 \(name):   \(path(of: kc))") }
}
line("")

// ---- E10: the contract shape, exercised against a throwaway keychain --------
// Proves the r2 contract (kSecUseKeychain on add, kSecMatchSearchList on
// query/delete, kSecUseDataProtectionKeychain:false) is a real, unit-testable
// seam that needs neither root nor the System keychain.
line("== E10: contract round-trip against a throwaway file-based keychain ==")

let tmpDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("TASK-260728-7ii1xz-\(getpid())", isDirectory: true)
try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
let kcPath = tmpDir.appendingPathComponent("probe.keychain-db").path
line("E10 throwaway keychain: \(kcPath)")

// Random unlock password: generated, used, never printed, never stored.
var pw = [UInt8](repeating: 0, count: 32)
guard SecRandomCopyBytes(kSecRandomDefault, pw.count, &pw) == errSecSuccess else {
    line("E10 FATAL: SecRandomCopyBytes failed"); exit(1)
}

var throwaway: SecKeychain?
let createSt = SecKeychainCreate(kcPath, UInt32(pw.count), pw, false, nil, &throwaway)
report("E10 SecKeychainCreate", createSt)
guard createSt == errSecSuccess, let throwaway else { exit(1) }

let service = "works.relux.tunnel.probe.7ii1xz"
let account = "credref-placeholder"
let placeholder = Data("PROBE-NOT-A-SECRET".utf8)

// add: kSecUseKeychain
var addQ: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecUseDataProtectionKeychain as String: false,
    kSecUseKeychain as String: throwaway,
    kSecValueData as String: placeholder,
]
report("E10 SecItemAdd (kSecUseKeychain)", SecItemAdd(addQ as CFDictionary, nil))

// query: kSecMatchSearchList
var readQ: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecUseDataProtectionKeychain as String: false,
    kSecMatchSearchList as String: [throwaway],
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne,
]
var out: CFTypeRef?
let readSt = SecItemCopyMatching(readQ as CFDictionary, &out)
report("E10 SecItemCopyMatching (kSecMatchSearchList)", readSt)
if readSt == errSecSuccess, let d = out as? Data {
    line("E10 value: bytes=\(d.count) matchesPlaceholder=\(d == placeholder)")
}

// negative control: same query, search list restricted to the OTHER keychain
// must NOT find it -- proves the search list actually scopes the query.
var otherList: [SecKeychain] = []
var userDefault: SecKeychain?
if SecKeychainCopyDomainDefault(.user, &userDefault) == errSecSuccess, let u = userDefault {
    otherList = [u]
}
if !otherList.isEmpty {
    var negQ = readQ
    negQ[kSecMatchSearchList as String] = otherList
    negQ.removeValue(forKey: kSecReturnData as String)
    report("E10 negative control (search list = user default)", SecItemCopyMatching(negQ as CFDictionary, nil))
}

// delete: kSecMatchSearchList
var delQ: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecUseDataProtectionKeychain as String: false,
    kSecMatchSearchList as String: [throwaway],
]
report("E10 SecItemDelete (kSecMatchSearchList)", SecItemDelete(delQ as CFDictionary))

report("E10 SecKeychainDelete", SecKeychainDelete(throwaway))
try? FileManager.default.removeItem(at: tmpDir)
line("E10 cleanup: throwaway keychain deleted")
