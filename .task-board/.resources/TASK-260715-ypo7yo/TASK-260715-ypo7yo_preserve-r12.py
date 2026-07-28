#!/usr/bin/env python3
"""r12 preservation assertions: everything r11 established is byte-for-byte unchanged.

r12 answers ONE blocking finding — reviewer verdict 10 F1, that `reviewedIn` was bounded to
membership in the issued revision set, so a register entry could name a revision that never
reviewed it — plus that verdict's required rework items 1-3. A revision that answers a GATE
finding gets to touch gates, and nothing else. "Nothing else" has to be proved rather than
promised, so this is the r10->r11 instrument one revision on.

r12 may add rule X1's `exceptionReviewProvenance`, an `id` on the ACTIVE register entry, an
`introduces` record on every revisionLog event, the reworked `reviewedIn` derivation entry,
one excluded phrase, the bumped R39 harness count, and the revision bookkeeping — and
NOTHING else.

The three properties that matter most, because they are what a reviewer would otherwise have
to take on trust:

  * both register ENTRIES still say exactly what r11 said, `reviewedIn` included. r12
    changes how the field is checked, not what it holds — if a value moved, the new
    derivation would be certifying something the last review never saw;
  * the Ceremony C1 authorization scope is byte-for-byte identical, so no portal mutation
    was smuggled in behind a gate change;
  * no entitlement entered or left an allowlist — the per-target, per-channel authored sets
    are identical, so no decision moved under cover of a validator rewrite.

Usage: python3 preserve-r12.py <r11.json> <r12.json>
"""

import json
import sys

r11 = json.loads(open(sys.argv[1]).read())
r12 = json.loads(open(sys.argv[2]).read())

fails = []
n = 0


def eq(label, a, b):
    global n
    n += 1
    if a != b:
        fails.append(f"{label}: r11 {json.dumps(a, ensure_ascii=False)[:200]} != "
                     f"r12 {json.dumps(b, ensure_ascii=False)[:200]}")


def ne(label, a, b):
    global n
    n += 1
    if a == b:
        fails.append(f"{label}: r12 did not change it "
                     f"({json.dumps(a, ensure_ascii=False)[:120]})")


def claim(label, ok):
    global n
    n += 1
    if not ok:
        fails.append(label)


def same(key):
    eq(key, r11.get(key), r12.get(key))


# 1. The top-level change set is exactly the rule this revision adds, plus bookkeeping.
#    Anything else drifting is caught here, before any assertion below runs.
ALLOWED_CHANGED = {
    "revision", "supersedes", "revisionLog",   # bookkeeping, and the introduction record
    "exceptionEntitlementRule",                # X1 gains X1-P and the reworked derivation
    "numericClaimContract",                    # N1's R39 count moves with the harness
}
changed = {k for k in set(r11) | set(r12) if r11.get(k) != r12.get(k)}
claim(f"r12 changed keys outside its remit: {sorted(changed - ALLOWED_CHANGED)}",
      not (changed - ALLOWED_CHANGED))
claim("r12 added or removed a top-level key", set(r11) == set(r12))

# 2. Bookkeeping moved, and moved correctly.
ne("revision", r11["revision"], r12["revision"])
eq("supersedes points at r11", r11["revision"], r12["supersedes"])
eq("revisionLog grew by exactly one", len(r11["revisionLog"]) + 1, len(r12["revisionLog"]))
eq("the new log entry is this revision", r12["revision"], r12["revisionLog"][0]["revision"])

# 2a. Every historical log entry survives verbatim EXCEPT for gaining `introduces`, which is
#     the one field r12 adds to them. A summary edited underneath an attestation is exactly
#     how the weaker evidence class would be laundered, so it is checked field by field.
old_log = {e["revision"]: e for e in r11["revisionLog"]}
new_log = {e["revision"]: e for e in r12["revisionLog"]}
eq("no historical revision left the log", sorted(old_log), sorted(set(new_log) - {r12["revision"]}))
for revision in sorted(old_log):
    before, after = old_log[revision], new_log[revision]
    eq(f"revisionLog {revision} gained exactly `introduces`",
       sorted(set(after) - set(before)), ["introduces"])
    eq(f"revisionLog {revision} lost no field", [], sorted(set(before) - set(after)))
    for field in sorted(before):
        eq(f"revisionLog {revision}.{field}", before[field], after[field])
    claim(f"revisionLog {revision}.introduces is a list",
          isinstance(after.get("introduces"), list))

# 3. EVERY DECISION IS UNTOUCHED. r12 is a gate revision; if any of these moved, the
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

# 4. Rule X1 gained the provenance rule and NOTHING else, and BOTH registers still say what
#    r11 said. This is the property verdict 10 makes load-bearing: a derivation that arrived
#    together with a moved value would prove nothing about the value.
x11, x12 = r11["exceptionEntitlementRule"], r12["exceptionEntitlementRule"]
eq("X1 gained exactly exceptionReviewProvenance",
   sorted(set(x12) - set(x11)), ["exceptionReviewProvenance"])
eq("X1 lost no field", [], sorted(set(x11) - set(x12)))
for field in sorted(set(x11) - {"reviewedExceptions", "conditionalExceptionDerivation"}):
    eq(f"X1.{field}", x11[field], x12[field])

eq("the conditional register is byte-for-byte r11's",
   x11["conditionalExceptions"], x12["conditionalExceptions"])
eq("the conditional entry's reviewedIn did not move",
   "2026-07-28.r10", x12["conditionalExceptions"][0]["reviewedIn"])

# the ACTIVE register gains an id and nothing else — its reviewedIn especially
a11 = x11["reviewedExceptions"]
a12 = x12["reviewedExceptions"]
eq("the active register still holds one entry", len(a11), len(a12))
for before, after in zip(a11, a12):
    eq("the active entry gained exactly `id`", sorted(set(after) - set(before)), ["id"])
    eq("the active entry lost no field", [], sorted(set(before) - set(after)))
    for field in sorted(before):
        eq(f"active entry .{field}", before[field], after[field])
eq("the active entry's reviewedIn did not move", "2026-07-28.r3", a12[0]["reviewedIn"])

# 4a. The derivation contract changed ONLY in its reviewedIn entry and its two prose fields.
d11, d12 = x11["conditionalExceptionDerivation"], x12["conditionalExceptionDerivation"]
eq("the derivation contract gained no field", [], sorted(set(d12) - set(d11)))
eq("the derivation contract lost no field", [], sorted(set(d11) - set(d12)))
for field in sorted(set(d11) - {"fields", "why", "principle"}):
    eq(f"derivation.{field}", d11[field], d12[field])
claim("the derivation's `why` records verdict 10 rather than replacing verdict 09's account",
      d12["why"].startswith(d11["why"]))
ne("derivation.principle", d11["principle"], d12["principle"])

s11 = {f["field"]: f for f in d11["fields"]}
s12 = {f["field"]: f for f in d12["fields"]}
eq("the derivation still covers exactly the same fields", sorted(s11), sorted(s12))
for name in sorted(set(s11) - {"reviewedIn"}):
    eq(f"derivation of {name}", s11[name], s12[name])
eq("r11 bounded reviewedIn to a known revision", "known-revision", s11["reviewedIn"]["boundKind"])
eq("r12 derives the introducing revision instead",
   "derived-introducing-revision", s12["reviewedIn"]["boundKind"])
claim("the rejected bound is recorded rather than silently replaced",
      "known-revision" in s12["reviewedIn"].get("supersededBound", ""))

# 4b. Rule X1-P is well formed, and its snapshot chain is the evidence the derivation needs.
prov = x12["exceptionReviewProvenance"]
eq("rule X1-P's id", "X1-P", prov["id"])
eq("the chain ends at the revision this contract supersedes",
   r12["supersedes"], prov["snapshotChain"][-1]["revision"])
claim("a snapshot is declared without a content digest",
      all(len(c.get("sha256", "")) == 64 for c in prov["snapshotChain"]))
# ordered NUMERICALLY, not as strings: '2026-07-28.r10' sorts before '2026-07-28.r8'
chain_numbers = [int(c["revision"].rsplit(".r", 1)[1]) for c in prov["snapshotChain"]]
claim("the chain is not oldest-first", chain_numbers == sorted(chain_numbers))
declared = {e["entry"]: e for e in prov["entries"]}
eq("both registers' entries have provenance", ["X1-A1", "X1-C1"], sorted(declared))
eq("the conditional entry is snapshot-proven", "snapshot-proven",
   declared["X1-C1"]["evidenceClass"])
eq("the pre-chain active entry is attested", "summary-attested",
   declared["X1-A1"]["evidenceClass"])
eq("the conditional entry's derived introduction", "2026-07-28.r10",
   declared["X1-C1"]["introducedIn"])
eq("the active entry's derived introduction", "2026-07-28.r3",
   declared["X1-A1"]["introducedIn"])
eq("the attesting literal is the entry's own key",
   declared["X1-A1"]["key"], declared["X1-A1"]["attestingLiteral"])
introduced = {i: e["revision"] for e in r12["revisionLog"] for i in e.get("introduces", [])}
eq("the introduction record agrees with the derivation",
   {"X1-A1": "2026-07-28.r3", "X1-C1": "2026-07-28.r10"}, introduced)

# 5. Rule N1 moved only the R39 harness count and one excluded phrase. Its DERIVATION of
#    allowlist counts, its claims and its shapes are untouched.
n11, n12 = r11["numericClaimContract"], r12["numericClaimContract"]
eq("N1 gained no field", [], sorted(set(n12) - set(n11)))
eq("N1 lost no field", [], sorted(set(n11) - set(n12)))
for field in ("id", "statement", "history", "derivation", "spelling", "relationToS1",
              "gate", "source", "claims"):
    eq(f"N1.{field}", n11.get(field), n12.get(field))

sc11, sc12 = n11["coverageScan"], n12["coverageScan"]
for field in ("artifacts", "requires", "excludedJsonPathPrefixes", "excludedJsonNote",
              "excludedDocSections", "excludedDocSectionNote", "shapes", "knownBound",
              "shapeSourceOfTruth", "preambleScanRule"):
    eq(f"N1.coverageScan.{field}", sc11.get(field), sc12.get(field))
eq("prior excluded phrases survive verbatim",
   sc11["excludedPhrases"], sc12["excludedPhrases"][:len(sc11["excludedPhrases"])])
eq("exactly one excluded phrase was added",
   len(sc11["excludedPhrases"]) + 1, len(sc12["excludedPhrases"]))
claim("the added exclusion carries no reason",
      all((p.get("reason") or "").strip()
          for p in sc12["excludedPhrases"][len(sc11["excludedPhrases"]):]))

hc11, hc12 = n11["harnessCounts"], n12["harnessCounts"]
for field in ("statement", "why", "scope"):
    eq(f"N1.harnessCounts.{field}", hc11.get(field), hc12.get(field))
eq("the declared harness counts still cover exactly R39",
   sorted(hc11["declaredCounts"]), sorted(hc12["declaredCounts"]))
claim("the R39 harness count did not grow with the new negative gates",
      hc12["declaredCounts"]["R39"] > hc11["declaredCounts"]["R39"])
claim("the harness count register stopped naming the harness that derives it",
      "mutate.py" in hc12["derivedBy"])

# 6. NOTHING ENTERED OR LEFT AN ALLOWLIST. r12 rewrote a gate; if a per-target, per-channel
#    authored set moved, a decision moved with it.
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


eq("the per-target, per-channel allowlists", allowlists(r11), allowlists(r12))

# 7. Every assertion, scope, profile row and open constraint survives verbatim. Covered by
#    the whole-key equality above; asserted individually so a failure names the surface.
as11 = {a["id"]: a for a in r11["verification"]["assertions"]}
as12 = {a["id"]: a for a in r12["verification"]["assertions"]}
eq("the assertion set", sorted(as11), sorted(as12))
for aid in sorted(as11):
    eq(f"assertion {aid}", as11[aid], as12[aid])
eq("open constraints", r11["openConstraints"], r12["openConstraints"])
eq("profiles", r11["profiles"], r12["profiles"])
t11 = {t["key"]: t for t in r11["targets"]}
t12 = {t["key"]: t for t in r12["targets"]}
eq("the target set", sorted(t11), sorted(t12))
for key in sorted(t11):
    eq(f"target {key}", t11[key], t12[key])

print(f"assertions run: {n}")
if fails:
    print(f"FAIL ({len(fails)})")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("PASS — everything r11 established is byte-for-byte unchanged")
