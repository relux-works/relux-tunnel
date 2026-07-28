#!/usr/bin/env python3
"""r9 preservation assertions: everything r8 established is unchanged.

r9 is a SELF-AUDIT, not a verdict response — there is no verdict 08. That makes the
preservation harness more important rather than less: a revision nobody asked for has no
reviewer-supplied boundary, so the boundary has to be stated and proved here.

r9 is a contract-versus-board revision. It may add rule D1 (`consumerDependencyContract`)
and rule N1 (`numericClaimContract`), extend the `consumers` list, record one previously
unexplained consumer's obligation in `downstreamConsequences`, and move the revision
bookkeeping — and NOTHING else. Every entitlement decision, target row, profile row,
record, assertion, assertion scope, cross-platform rule, and the whole C1 authorization
scope must survive byte-for-byte, because r9 questioned none of them.

The single board change (TASK-260715-29ws8l gains a blockedBy edge on this task) and the
revision re-point on TASK-260728-q5kjta.scope do not live in this file; they are checked by
TASK-260715-ypo7yo_check-portal-consumer.py.

Usage: python3 preserve.py <r8.json> <r9.json>
"""

import json
import sys

r8 = json.loads(open(sys.argv[1]).read())
r9 = json.loads(open(sys.argv[2]).read())

fails = []
n = 0


def eq(label, a, b):
    global n
    n += 1
    if a != b:
        fails.append(f"{label}: r8 {json.dumps(a, ensure_ascii=False)[:200]} != "
                     f"r9 {json.dumps(b, ensure_ascii=False)[:200]}")


def ne(label, a, b):
    global n
    n += 1
    if a == b:
        fails.append(f"{label}: r9 did not change it "
                     f"({json.dumps(a, ensure_ascii=False)[:120]})")


def claim(label, ok):
    global n
    n += 1
    if not ok:
        fails.append(label)


def same(key):
    eq(key, r8.get(key), r9.get(key))


# 1-3: the top-level change set is exactly the keys this revision is allowed to touch.
# Anything else drifting is caught here, before any individual assertion below runs.
ADDED = {"consumerDependencyContract", "numericClaimContract"}
CHANGED = {"revision", "supersedes", "revisionLog", "consumers", "downstreamConsequences"}
eq("top-level keys added", sorted(set(r9) - set(r8)), sorted(ADDED))
eq("top-level keys removed", sorted(set(r8) - set(r9)), [])
eq("top-level changed keys",
   sorted({k for k in r8 if r8[k] != r9.get(k)}), sorted(CHANGED))

# 4-12: the eight target rows, byte-for-byte. r9 questioned no entitlement.
t8 = {t["key"]: t for t in r8["targets"]}
t9 = {t["key"]: t for t in r9["targets"]}
eq("target key set", sorted(t8), sorted(t9))
for k in sorted(t8):
    eq(f"target row {k}", t8[k], t9.get(k))

# 13-21: the eight profile rows.
p8 = {p["target"]: p for p in r8["profiles"]}
p9 = {p["target"]: p for p in r9["profiles"]}
eq("profile key set", sorted(p8), sorted(p9))
for k in sorted(p8):
    eq(f"profile row {k}", p8[k], p9.get(k))

# 22-40: every decision surface. None of these was in question.
for key in ("team", "namespaces", "legacy", "signingChannels", "environmentRules",
            "allowedNetworkExtensionValues", "forbiddenNetworkExtensionValues",
            "networkExtensionRule", "entitlementClassification", "keychainScopeRule",
            "keychainLeastPrivilegeRule", "appGroups", "appGroupDisjointnessRule",
            "appGroupPurposeRule", "appGroupStyleRule", "appGroupLeastPrivilegeRule",
            "keychainAccessGroups", "exceptionEntitlementRule", "openConstraints"):
    same(key)

# 41-50: the authorization and portal surfaces. c1AuthorizationScope in particular must be
# byte-identical: r9 authorizes no new portal mutation, and the re-point changes only the
# revision LABEL on a board record, which does not live in this file.
for key in ("c1AuthorizationScope", "humanAuthorizationNode", "authorizesPortalMutationBy",
            "authorizationNodeContract", "portalMutationTaskContract", "amendmentRule",
            "contract", "owner", "status", "schemaVersion"):
    same(key)

# 51-52: the r6 cross-platform projection and the r8 assertion-scope contract are untouched —
# D1 and N1 are their siblings, not their successors.
same("crossPlatformRules")
same("crossPlatformSharingContract")

# 53-79: verification is byte-identical in FULL, including every assertion and every
# registered scope. r8's whole subject was the assertion list; r9 must not touch it.
same("verification")
a8 = {a["id"]: a["text"] for a in r8["verification"]["assertions"]}
a9 = {a["id"]: a["text"] for a in r9["verification"]["assertions"]}
eq("assertion id set", sorted(a8), sorted(a9))
for aid in sorted(a8):
    eq(f"assertion {aid}", a8[aid], a9.get(aid))

# 80-83: the consumers list GREW and lost nothing. A revision that renames or drops a
# consumer while claiming to complete the list is the defect one step on.
claim("the consumers list shrank", len(r9["consumers"]) > len(r8["consumers"]))
for entry in r8["consumers"]:
    claim(f"consumer entry dropped: {entry[:60]!r}", entry in r9["consumers"])
eq("consumer entries added", len(r9["consumers"]) - len(r8["consumers"]), 4)

# 84-95: downstreamConsequences gained exactly one entry and altered none. The new entry is
# the TASK-260715-33oofa obligation, which rule D1's own reverse check found missing — the
# contract declared it a consumer and never said what it consumes.
c8 = {d["owner"]: d["consequence"] for d in r8["downstreamConsequences"]}
c9 = {d["owner"]: d["consequence"] for d in r9["downstreamConsequences"]}
eq("downstream owners added", sorted(set(c9) - set(c8)), ["TASK-260715-33oofa"])
eq("downstream owners removed", sorted(set(c8) - set(c9)), [])
for owner in sorted(c8):
    eq(f"downstream consequence for {owner}", c8[owner], c9[owner])

# 96-99: revision bookkeeping moved exactly one step and lost no history
eq("supersedes", r9["supersedes"], r8["revision"])
ne("revision", r8["revision"], r9["revision"])
eq("revisionLog head", r9["revisionLog"][0]["revision"], r9["revision"])
eq("revisionLog tail preserved", r8["revisionLog"], r9["revisionLog"][1:])
claim("the r9 log entry does not say it answers no verdict, which is the one thing a "
      "reader needs to know about an unrequested revision",
      "none" in r9["revisionLog"][0]["verdict"].lower())

# 100-108: rule D1 is present and actually records what it found, rather than arriving as a
# clean rule over a contract that was silently corrected first.
d1 = r9["consumerDependencyContract"]
eq("rule D1 id", d1["id"], "D1")
eq("rule D1 selfReference", d1["selfReference"], r9["owner"])
eq("rule D1 exemption bases", d1["exemptionBasisAllowed"], ["upstream"])
for eid in ("TASK-260715-1o9wjz", "TASK-260715-3f4lxy", "TASK-260715-29ws8l"):
    claim(f"rule D1 does not record that {eid} had no path to this task",
          any(eid in s and "REACHABILITY" in s for s in d1["staleClaimsFound"]))
eq("rule D1 board change", sorted(d1["boardChange"]["closes"]),
   ["TASK-260715-1o9wjz", "TASK-260715-29ws8l", "TASK-260715-3f4lxy"])
claim("rule D1 records no cycle check for the edge it added",
      bool(d1["boardChange"]["cycleCheck"].strip()))

# 109-113: rule N1 is present, states its bound, and does not silently take over a count
# rule S1 already owns.
n1 = r9["numericClaimContract"]
eq("rule N1 id", n1["id"], "N1")
eq("rule N1 gate", n1["gate"], "R38")
claim("rule N1 states no bound, so it reads as a completeness claim",
      bool(n1["coverageScan"]["knownBound"].strip()))
claim("rule N1 excludes more than §13 from its document scan",
      n1["coverageScan"]["excludedDocSections"] == ["13"])
s1_paths = set(r9["crossPlatformSharingContract"]["recordCountClaimPaths"])
n1_paths = {c.get("path") for c in n1["claims"] if c.get("path")}
claim("rules S1 and N1 both own the same count path", not (s1_paths & n1_paths))

print(f"assertions run: {n}")
if fails:
    print(f"FAIL ({len(fails)})")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("PASS — everything r8 established is byte-for-byte unchanged")
