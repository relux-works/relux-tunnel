#!/usr/bin/env python3
"""r10 preservation assertions: everything r9 established is unchanged.

r10 answers ONE blocking finding — reviewer verdict 08 F1, the OS-version scope of the
macOS provider's keychain decision. A revision that answers one finding gets to touch the
surface that finding names and nothing else, and "nothing else" has to be proved rather
than promised. r8→r9 had `preserve.py`; this is the same instrument one revision on.

r10 may add rule K3 (`keychainSandboxFloorRule`), one `osFloorScope` clause on rule K1,
one `osVersionScope` block and one appended sentence on the `macos.provider`
`keychain-access-groups` row, one UNARMED conditional row and register entry, one status
term, OC-5, assertion A19 with its scope entry, one downstream consequence, one consumer,
and the revision bookkeeping — and NOTHING else.

Two properties matter most and are asserted hardest, because they are what a reviewer
would otherwise have to take on trust:

  * the Ceremony C1 authorization scope is byte-for-byte identical, so no portal mutation
    was smuggled in behind an entitlement argument (verdict 08, required rework item 4);
  * no entitlement ENTERED an allowlist — the per-target, per-channel authored sets are
    identical, so the new row is genuinely inert while unarmed.

Usage: python3 preserve-r10.py <r9.json> <r10.json>
"""

import json
import sys

r9 = json.loads(open(sys.argv[1]).read())
r10 = json.loads(open(sys.argv[2]).read())

fails = []
n = 0

TEMP_FILE = "com.apple.security.temporary-exception.files.absolute-path.read-write"
KEYCHAIN = "keychain-access-groups"
PROVIDER = "macos.provider"


def eq(label, a, b):
    global n
    n += 1
    if a != b:
        fails.append(f"{label}: r9 {json.dumps(a, ensure_ascii=False)[:200]} != "
                     f"r10 {json.dumps(b, ensure_ascii=False)[:200]}")


def ne(label, a, b):
    global n
    n += 1
    if a == b:
        fails.append(f"{label}: r10 did not change it "
                     f"({json.dumps(a, ensure_ascii=False)[:120]})")


def claim(label, ok):
    global n
    n += 1
    if not ok:
        fails.append(label)


def same(key):
    eq(key, r9.get(key), r10.get(key))


def targets(m):
    return {t["key"]: t for t in m["targets"]}


# 1. The top-level change set is exactly the keys this revision is allowed to touch.
#    Anything else drifting is caught here, before any individual assertion below runs.
ALLOWED_CHANGED = {
    "revision", "supersedes", "revisionLog",          # bookkeeping
    "keychainScopeRule",                              # K1 gains osFloorScope
    "keychainSandboxFloorRule",                       # K3, new
    "entitlementClassification",                      # one status term
    "exceptionEntitlementRule",                       # X1 conditional register
    "targets",                                        # the provider rows
    "openConstraints",                                # OC-5
    "verification",                                   # A19 + AS-11
    "downstreamConsequences",                         # the floor obligation
    "consumers", "consumerDependencyContract",        # the new consumer
}
changed = {k for k in set(r9) | set(r10) if r9.get(k) != r10.get(k)}
claim(f"r10 changed keys outside its remit: {sorted(changed - ALLOWED_CHANGED)}",
      not (changed - ALLOWED_CHANGED))
claim("keychainSandboxFloorRule is not new in r10",
      "keychainSandboxFloorRule" not in r9 and "keychainSandboxFloorRule" in r10)

# 2. Bookkeeping moved, and moved correctly.
ne("revision", r9["revision"], r10["revision"])
eq("supersedes points at r9", r9["revision"], r10["supersedes"])
eq("revisionLog grew by exactly one", len(r9["revisionLog"]) + 1, len(r10["revisionLog"]))
eq("the r9 log entry survives verbatim", r9["revisionLog"], r10["revisionLog"][1:])

# 3. THE CEREMONY IS UNTOUCHED. Required rework item 4: a temporary file exception is not
#    a portal record, so no part of the human authorization scope may move for it.
same("c1AuthorizationScope")
same("authorizationNodeContract")
same("portalMutationTaskContract")
same("profiles")
same("appGroups")
same("keychainAccessGroups")
same("team")
same("namespaces")
same("legacy")
same("signingChannels")
same("networkExtensionRule")
same("allowedNetworkExtensionValues")
same("forbiddenNetworkExtensionValues")
same("environmentRules")
same("crossPlatformRules")
same("crossPlatformSharingContract")
same("appGroupStyleRule")
same("appGroupPurposeRule")
same("appGroupDisjointnessRule")
same("appGroupLeastPrivilegeRule")
same("keychainLeastPrivilegeRule")
same("numericClaimContract")
same("amendmentRule")
same("status")
same("owner")
same("humanAuthorizationNode")
same("authorizesPortalMutationBy")

# 4. Every target row survives, except the two the finding names — and those two survive
#    in their DECISION, which is the point: r10 rescopes the reasoning, it does not
#    re-decide the outcome.
t9, t10 = targets(r9), targets(r10)
eq("the target set", sorted(t9), sorted(t10))
for key in sorted(t9):
    a, b = t9[key], t10[key]
    for field in ("bundleId", "platform", "role", "family", "channels", "embeddedIn",
                  "profileClasses"):
        if field in a or field in b:
            eq(f"{key}.{field}", a.get(field), b.get(field))
    if key == PROVIDER:
        claim(f"{key} did not gain the conditional row",
              TEMP_FILE not in a["entitlements"] and TEMP_FILE in b["entitlements"])
        eq(f"{key} entitlement keys, ignoring the new conditional row",
           sorted(a["entitlements"]),
           sorted(k for k in b["entitlements"] if k != TEMP_FILE))
        for k in sorted(a["entitlements"]):
            if k == KEYCHAIN:
                continue
            eq(f"{key}/{k}", a["entitlements"][k], b["entitlements"][k])
    else:
        eq(f"{key}.entitlements", a["entitlements"], b["entitlements"])

# 5. The keychain DECISION is unchanged. Only its scope is now stated.
kc9 = t9[PROVIDER]["entitlements"][KEYCHAIN]
kc10 = t10[PROVIDER]["entitlements"][KEYCHAIN]
for field in ("status", "portalCapability", "rationale", "evidence", "decidedBy"):
    eq(f"{PROVIDER}/{KEYCHAIN}.{field}", kc9.get(field), kc10.get(field))
eq("the keychain row is still prohibited", "prohibited", kc10["status"])
claim("osVersionScope is not new in r10",
      "osVersionScope" not in kc9 and "osVersionScope" in kc10)
claim("the reopening condition was rewritten rather than extended",
      kc10["reopensOnly"].startswith(kc9["reopensOnly"]))
claim("the extended reopening condition does not name rule K3", "K3" in kc10["reopensOnly"])

# 6. NOTHING ENTERED AN ALLOWLIST. The conditional row is inert while unarmed, so every
#    per-target, per-channel authored set is identical to r9's — which is also why no
#    rule N1 count could have moved.
def allowlists(m):
    authored_ok = set(m["entitlementClassification"]["authoredStatuses"])
    out = {}
    for t in m["targets"]:
        for ch in t["channels"]:
            gen = m["entitlementClassification"]["signingGenerated"][t["platform"]]
            injected = set(gen["always"])
            if ch == "development":
                injected |= set(gen["developmentChannelOnly"])
            authored = {k for k, v in t["entitlements"].items()
                        if v["status"] in authored_ok}
            out[f"{t['key']}/{ch}"] = sorted(authored | injected)
    return out


eq("the per-target, per-channel allowlists", allowlists(r9), allowlists(r10))
eq("authoredStatuses", r9["entitlementClassification"]["authoredStatuses"],
   r10["entitlementClassification"]["authoredStatuses"])
eq("signingGenerated", r9["entitlementClassification"]["signingGenerated"],
   r10["entitlementClassification"]["signingGenerated"])
claim("the new status term is not additive to nonAuthoredStatuses",
      r10["entitlementClassification"]["nonAuthoredStatuses"][:len(
          r9["entitlementClassification"]["nonAuthoredStatuses"])]
      == r9["entitlementClassification"]["nonAuthoredStatuses"])

# 7. The ACTIVE exception register is untouched; only a disjoint conditional one appeared.
x9, x10 = r9["exceptionEntitlementRule"], r10["exceptionEntitlementRule"]
for field in ("id", "statement", "source", "reviewedExceptions", "prohibitedKeys",
              "prohibitedKeyPolicy", "getTaskAllowNote", "sparkleNestedCodeNote"):
    eq(f"X1.{field}", x9.get(field), x10.get(field))
claim("conditionalExceptions is not new in r10",
      "conditionalExceptions" not in x9 and "conditionalExceptions" in x10)
active = {(e["key"], e["target"]) for e in x10["reviewedExceptions"]}
for c in x10["conditionalExceptions"]:
    claim(f"conditional entry {c['id']} is armed", c["armed"] is False)
    claim(f"conditional entry {c['id']} is also in the active register",
          (c["key"], c["target"]) not in active)

# 8. Rule K1 keeps every clause it had; it only gained the floor scope.
k1_9, k1_10 = r9["keychainScopeRule"], r10["keychainScopeRule"]
for field in ("id", "statement", "replaces", "reopeningCondition",
              "shippingProductsAreNotEvidence", "source", "hostScope"):
    eq(f"K1.{field}", k1_9.get(field), k1_10.get(field))
claim("osFloorScope is not new in r10",
      "osFloorScope" not in k1_9 and "osFloorScope" in k1_10)

# 9. Assertions and scopes grew by exactly one each; every prior one survives verbatim.
a9 = {a["id"]: a for a in r9["verification"]["assertions"]}
a10 = {a["id"]: a for a in r10["verification"]["assertions"]}
eq("the assertion set gained exactly A19", sorted(set(a10) - set(a9)), ["A19"])
eq("no assertion was removed", [], sorted(set(a9) - set(a10)))
for aid in sorted(a9):
    eq(f"assertion {aid}", a9[aid], a10[aid])
s9 = r9["verification"]["assertionScopeContract"]
s10 = r10["verification"]["assertionScopeContract"]
for field in s9:
    if field != "entitlementScopes":
        eq(f"S2.{field}", s9[field], s10.get(field))
e9 = {e["id"]: e for e in s9["entitlementScopes"]}
e10 = {e["id"]: e for e in s10["entitlementScopes"]}
eq("the entitlement scopes gained exactly AS-11", sorted(set(e10) - set(e9)), ["AS-11"])
for eid in sorted(e9):
    eq(f"scope {eid}", e9[eid], e10[eid])
eq("profileScopes", s9["profileScopes"], s10["profileScopes"])
eq("A19 scopes every target row", sorted(t10), sorted(e10["AS-11"]["scopeTargets"]))
eq("A19 is an ABSENT claim", "absent", e10["AS-11"]["polarity"])

# 10. Open constraints, consequences and consumers grew; nothing was rewritten.
oc9 = {c["id"]: c for c in r9["openConstraints"]}
oc10 = {c["id"]: c for c in r10["openConstraints"]}
eq("the constraint set gained exactly OC-5", sorted(set(oc10) - set(oc9)), ["OC-5"])
for cid in sorted(oc9):
    eq(f"constraint {cid}", oc9[cid], oc10[cid])
eq("prior downstream consequences survive verbatim",
   r9["downstreamConsequences"],
   r10["downstreamConsequences"][:len(r9["downstreamConsequences"])])
eq("exactly one consequence was added",
   len(r9["downstreamConsequences"]) + 1, len(r10["downstreamConsequences"]))
eq("prior consumers survive verbatim", r9["consumers"],
   r10["consumers"][:len(r9["consumers"])])
eq("exactly one consumer was added", len(r9["consumers"]) + 1, len(r10["consumers"]))
d1_9, d1_10 = r9["consumerDependencyContract"], r10["consumerDependencyContract"]
for field in d1_9:
    if field != "reachabilityRule":
        eq(f"D1.{field}", d1_9[field], d1_10.get(field))
eq("rule D1's boardChange is untouched — r10 added no board edge",
   d1_9["boardChange"], d1_10["boardChange"])

print(f"assertions run: {n}")
if fails:
    print(f"FAIL ({len(fails)})")
    for f in fails:
        print("  -", f)
    raise SystemExit(1)
print("PASS — everything r9 established is byte-for-byte unchanged")
