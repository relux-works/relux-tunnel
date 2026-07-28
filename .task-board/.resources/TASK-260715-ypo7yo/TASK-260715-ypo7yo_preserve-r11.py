#!/usr/bin/env python3
"""r11 preservation assertions: everything r10 established is byte-for-byte unchanged.

r11 answers ONE blocking finding — reviewer verdict 09 F1, that gate R39 established the
conditional exception register by comparing it to its own copy on the target row — plus
that verdict's required rework items 2-5. A revision that answers a GATE finding gets to
touch gates, and nothing else. "Nothing else" has to be proved rather than promised, so
this is the r9->r10 instrument one revision on.

r11 may add rule X1's `conditionalExceptionDerivation`, rule N1's `harnessCounts`, N1's
second and third scan shapes, three N1 claims, the preamble scan rule, four excluded
phrases, and the revision bookkeeping — and NOTHING else.

The three properties that matter most, because they are what a reviewer would otherwise
have to take on trust:

  * X1-C1 itself is byte-for-byte what r10 reviewed. r11 changes how the entry is
    CHECKED, not what it says — if the entry moved, the gate would be validating a
    different exception than the one the last review approved;
  * the Ceremony C1 authorization scope is byte-for-byte identical, so no portal mutation
    was smuggled in behind a gate change;
  * no entitlement entered or left an allowlist — the per-target, per-channel authored
    sets are identical, so no decision moved under cover of a validator rewrite.

Usage: python3 preserve-r11.py <r10.json> <r11.json>
"""

import json
import sys

r10 = json.loads(open(sys.argv[1]).read())
r11 = json.loads(open(sys.argv[2]).read())

fails = []
n = 0


def eq(label, a, b):
    global n
    n += 1
    if a != b:
        fails.append(f"{label}: r10 {json.dumps(a, ensure_ascii=False)[:200]} != "
                     f"r11 {json.dumps(b, ensure_ascii=False)[:200]}")


def ne(label, a, b):
    global n
    n += 1
    if a == b:
        fails.append(f"{label}: r11 did not change it "
                     f"({json.dumps(a, ensure_ascii=False)[:120]})")


def claim(label, ok):
    global n
    n += 1
    if not ok:
        fails.append(label)


def same(key):
    eq(key, r10.get(key), r11.get(key))


# 1. The top-level change set is exactly the two rules this revision hardens, plus
#    bookkeeping. Anything else drifting is caught here, before any assertion below runs.
ALLOWED_CHANGED = {
    "revision", "supersedes", "revisionLog",   # bookkeeping
    "exceptionEntitlementRule",                # X1 gains the derivation contract
    "numericClaimContract",                    # N1 gains shapes, harness counts, claims
}
changed = {k for k in set(r10) | set(r11) if r10.get(k) != r11.get(k)}
claim(f"r11 changed keys outside its remit: {sorted(changed - ALLOWED_CHANGED)}",
      not (changed - ALLOWED_CHANGED))
claim("r11 added or removed a top-level key", set(r10) == set(r11))

# 2. Bookkeeping moved, and moved correctly.
ne("revision", r10["revision"], r11["revision"])
eq("supersedes points at r10", r10["revision"], r11["supersedes"])
eq("revisionLog grew by exactly one", len(r10["revisionLog"]) + 1, len(r11["revisionLog"]))
eq("the r10 log entry survives verbatim", r10["revisionLog"], r11["revisionLog"][1:])
eq("the new log entry is this revision", r11["revision"], r11["revisionLog"][0]["revision"])

# 3. EVERY DECISION IS UNTOUCHED. r11 is a gate revision; if any of these moved, the
#    hardened gate would be certifying something the last review never saw.
for key in ("c1AuthorizationScope", "authorizationNodeContract", "portalMutationTaskContract",
            "targets", "profiles", "appGroups", "keychainAccessGroups", "team", "namespaces",
            "legacy", "signingChannels", "networkExtensionRule", "allowedNetworkExtensionValues",
            "forbiddenNetworkExtensionValues", "environmentRules", "crossPlatformRules",
            "crossPlatformSharingContract", "appGroupStyleRule", "appGroupPurposeRule",
            "appGroupDisjointnessRule", "appGroupLeastPrivilegeRule", "keychainScopeRule",
            "keychainLeastPrivilegeRule", "keychainSandboxFloorRule", "entitlementClassification",
            "verification", "openConstraints", "downstreamConsequences", "consumers",
            "consumerDependencyContract", "amendmentRule", "status", "owner",
            "humanAuthorizationNode", "authorizesPortalMutationBy", "schemaVersion", "contract"):
    same(key)

# 4. Rule X1 gained the derivation contract and NOTHING else — most of all, the reviewed
#    entry itself is unchanged. r11 changes how X1-C1 is checked, not what it says.
x10, x11 = r10["exceptionEntitlementRule"], r11["exceptionEntitlementRule"]
eq("X1 gained exactly conditionalExceptionDerivation",
   sorted(set(x11) - set(x10)), ["conditionalExceptionDerivation"])
eq("X1 lost no field", [], sorted(set(x10) - set(x11)))
for field in sorted(set(x10)):
    eq(f"X1.{field}", x10[field], x11[field])
eq("the conditional register is byte-for-byte r10's",
   x10["conditionalExceptions"], x11["conditionalExceptions"])
eq("the ACTIVE reviewed-exception register is byte-for-byte r10's",
   x10["reviewedExceptions"], x11["reviewedExceptions"])

# The derivation covers every field of the entry it governs, and declares no bound that
# is agreement with the target row — the check verdict 09 rejected, re-entering as data.
deriv = x11["conditionalExceptionDerivation"]
spec = {f["field"]: f for f in deriv["fields"]}
eq("the derivation covers every conditional-entry field",
   sorted(spec),
   sorted({"target", "key", "valuesIfArmed", "channelsIfArmed", "armedBy", "governedBy",
           "reviewedIn", "scopeIfArmed"}))
for name, field_spec in sorted(spec.items()):
    claim(f"the derivation of {name} is a bound against the target row",
          "row" not in field_spec["boundKind"] or field_spec["boundKind"] == "derived-unique-row")
eq("the reviewed path is the one r10 reviewed",
   x10["conditionalExceptions"][0]["valuesIfArmed"], [spec["valuesIfArmed"]["reviewedPath"]])
eq("the reviewed exception is still one path", 1, spec["valuesIfArmed"]["maxValues"])

# 5. Rule N1 grew by exactly the register, the shapes and the three claims. Its DERIVATION
#    of allowlist counts — the r9 half — is untouched.
n10, n11 = r10["numericClaimContract"], r11["numericClaimContract"]
eq("N1 gained exactly harnessCounts", sorted(set(n11) - set(n10)), ["harnessCounts"])
eq("N1 lost no field", [], sorted(set(n10) - set(n11)))
for field in ("id", "statement", "history", "derivation", "spelling", "relationToS1",
              "gate", "source"):
    eq(f"N1.{field}", n10.get(field), n11.get(field))

c10 = {c["id"]: c for c in n10["claims"]}
c11 = {c["id"]: c for c in n11["claims"]}
eq("the claim set gained exactly N1-5, N1-6 and N1-7",
   sorted(set(c11) - set(c10)), ["N1-5", "N1-6", "N1-7"])
eq("no claim was removed", [], sorted(set(c10) - set(c11)))
for cid in sorted(c10):
    eq(f"claim {cid}", c10[cid], c11[cid])

s10, s11 = n10["coverageScan"], n11["coverageScan"]
for field in ("artifacts", "requires", "excludedJsonPathPrefixes", "excludedJsonNote",
              "excludedDocSections", "excludedDocSectionNote"):
    eq(f"N1.coverageScan.{field}", s10.get(field), s11.get(field))
eq("§13 is still the only excluded document section", ["13"], s11["excludedDocSections"])
claim("the singular `shape` field survives alongside `shapes`", "shape" not in s11)
claim("`shapes` is not new in r11", "shapes" not in s10 and "shapes" in s11)
claim("the preamble exclusion survives",
      "excludedDocPreamble" in s10 and "excludedDocPreamble" not in s11)
claim("the preamble scan rule is not new in r11",
      "preambleScanRule" not in s10 and "preambleScanRule" in s11)
claim("the preamble scan rule does not quote the exclusion it replaces",
      s10["excludedDocPreamble"] in s11["preambleScanRule"])
eq("prior excluded phrases survive verbatim",
   s10["excludedPhrases"], s11["excludedPhrases"][:len(s10["excludedPhrases"])])
eq("exactly four excluded phrases were added",
   len(s10["excludedPhrases"]) + 4, len(s11["excludedPhrases"]))
claim("an added exclusion is a whole section rather than a named phrase",
      all(p.get("section") in ("preamble", "9.2")
          for p in s11["excludedPhrases"][len(s10["excludedPhrases"]):]))
claim("an added exclusion carries no reason",
      all((p.get("reason") or "").strip()
          for p in s11["excludedPhrases"][len(s10["excludedPhrases"]):]))
claim("the stated bound was narrowed rather than extended",
      s11["knownBound"].startswith(s10["knownBound"]))

hc = n11["harnessCounts"]
claim("the harness count register names no gate", bool(hc["declaredCounts"]))
claim("a declared harness count is not a positive number",
      all(isinstance(v, int) and v > 0 for v in hc["declaredCounts"].values()))
claim("the harness count register does not name the harness that derives it",
      "mutate.py" in hc["derivedBy"])

# 6. NOTHING ENTERED OR LEFT AN ALLOWLIST. r11 rewrote gates; if a per-target,
#    per-channel authored set moved, a decision moved with it.
def allowlists(m):
    authored_ok = set(m["entitlementClassification"]["authoredStatuses"])
    out = {}
    for t in m["targets"]:
        for ch in t["channels"]:
            gen = m["entitlementClassification"]["signingGenerated"][t["platform"]]
            injected = set(gen["always"])
            if ch == "development":
                injected |= set(gen["developmentChannelOnly"])
            authored = {k for k, v in t["entitlements"].items() if v["status"] in authored_ok}
            out[f"{t['key']}/{ch}"] = sorted(authored | injected)
    return out


eq("the per-target, per-channel allowlists", allowlists(r10), allowlists(r11))

# 7. Every assertion, scope, profile row and open constraint survives verbatim. Covered by
#    the whole-key equality above; asserted individually so a failure names the surface.
a10 = {a["id"]: a for a in r10["verification"]["assertions"]}
a11 = {a["id"]: a for a in r11["verification"]["assertions"]}
eq("the assertion set", sorted(a10), sorted(a11))
for aid in sorted(a10):
    eq(f"assertion {aid}", a10[aid], a11[aid])
eq("open constraints", r10["openConstraints"], r11["openConstraints"])
eq("profiles", r10["profiles"], r11["profiles"])
t10 = {t["key"]: t for t in r10["targets"]}
t11 = {t["key"]: t for t in r11["targets"]}
eq("the target set", sorted(t10), sorted(t11))
for key in sorted(t10):
    eq(f"target {key}", t10[key], t11[key])

print(f"assertions run: {n}")
if fails:
    print(f"FAIL ({len(fails)})")
    for f in fails:
        print("  -", f)
    raise SystemExit(1)
print("PASS — everything r10 established is byte-for-byte unchanged")
