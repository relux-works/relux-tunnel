#!/bin/zsh
# Independent gates for this matrix, written so a reviewer can run them WITHOUT the
# project's own harnesses. Nothing here imports validate_matrix.py, mutate.py, or
# check-portal-consumer.py; the reachability math below is re-implemented from scratch on
# purpose, because a gate that shares code with the thing it checks proves less.
#
# Sections:
#   1. verdict 07's two gates (A5 target-consistency, A9 profile-device scope), structural
#      forms, still expected true — r9 preserved `verification` byte-for-byte.
#   2. r9's rule D1: every declared consumer must transitively depend on this task. Run
#      against the LIVE board, and again with the one edge r9 added removed, so the flip is
#      visible. The second run reproduces the r8 state.
#   3. r11's answer to verdict 09 F1, and r12's answer to verdict 10 F1. Every field of the
#      conditional exception entry is re-derived here from a source OTHER than the entry and
#      its copy on the target row - which is the pair r10 compared and verdict 09 moved
#      together - and each verdict's own mutations are replayed through that derivation.
#
#      r12: `reviewedIn` is derived too, for BOTH registers. This script used to check what
#      r11's gate checked - that the revision had been issued - so verdict 10's control
#      passed here as well as there. The snapshot chain is now loaded from disk, its digests
#      recomputed, and the introducing revision computed from where the entry first appears.
#      The chain is reloaded per contract, so a mutation that NARROWS it is visible.
#
# Usage: ./TASK-260715-ypo7yo_reviewer-gates.sh [BASELINE.json]
#        A baseline path is optional; without it, only the current contract is checked.
#        Passing a superseded baseline makes section 3 print the flip: the r10 baseline is
#        false on the r11 derivation, the r11 baseline is false on this one.

set -u
# r11: the script's own exit code used to be whatever the last printf returned, so it
# was 0 whatever the gates said - a harness that cannot fail, reporting on harnesses
# that must. Every gate now feeds this counter and the script exits on it.
GATE_FAILURES=0
note() {  # note <exit-code> <name>
  [[ $1 -eq 0 ]] || GATE_FAILURES=$((GATE_FAILURES + 1))
}
MATRIX='TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json'
GROUPS='com.apple.security.application-groups'
REPO="${0:A:h}"
while [[ "$REPO" != "/" && ! -d "$REPO/.task-board" ]]; do REPO="${REPO:h}"; done

gate_a5() {
  jq --arg k "$GROUPS" -e '
    ( [ .verification.assertions[] | .text ] | join(" ") )               as $all
    | ( [ .targets[] | select(.platform=="iOS") | .key ] | sort )        as $ios
    | ( [ .targets[]
          | select(.platform=="iOS")
          | select(.entitlements[$k].status
                   | . == "required" or . == "required-adjacent")
          | .key ] | sort )                                             as $granted
    # the defective shape: a universal iOS presence claim over rows that are not all granted
    | ( $all | test("is PRESENT on every iOS bundle") ) as $universal
    | ( $universal | not ) or ( $ios == $granted )
  ' "$1" >/dev/null 2>&1
}

gate_a9() {
  jq -e '
    ( [ .verification.assertions[] | .text ] | join(" ") )               as $all
    | ( [ .profiles[]
          | select( [ .development.devices[] | test("deferred") ] | any )
          | .target ] | sort )                                           as $deferred
    | ( $all | test("every development profile carries ProvisionedDevices") ) as $universal
    | ( $universal | not ) or ( ($deferred | length) == 0 )
  ' "$1" >/dev/null 2>&1
}

echo '=== 1. verdict 07 gates ==='
if [[ $# -ge 1 && -f "$1" ]]; then
  gate_a5 "$1"; a5=$?
  gate_a9 "$1"; a9=$?
  printf 'baseline  A5 target-consistency gate: %s exit=%d\n' \
    "$([ $a5 -eq 0 ] && echo true || echo false)" $a5
  printf 'baseline  A9 profile-device-scope gate: %s exit=%d\n' \
    "$([ $a9 -eq 0 ] && echo true || echo false)" $a9
fi
gate_a5 "$MATRIX"; a5=$?
gate_a9 "$MATRIX"; a9=$?
note $a5; note $a9
printf 'current   A5 target-consistency gate: %s exit=%d\n' \
  "$([ $a5 -eq 0 ] && echo true || echo false)" $a5
printf 'current   A9 profile-device-scope gate: %s exit=%d\n' \
  "$([ $a9 -eq 0 ] && echo true || echo false)" $a9

# structural forms: the scopes themselves, not the absence of a phrase
jq --arg k "$GROUPS" -e '
  .verification.assertionScopeContract as $s2
  | ( [ $s2.entitlementScopes[] | select(.entitlementKey==$k and .polarity!="absent")
        | .scopeTargets[] ] | sort | unique )                           as $present
  | ( [ $s2.entitlementScopes[] | select(.entitlementKey==$k and .polarity=="absent")
        | .scopeTargets[] ] | sort | unique )                           as $absent
  | ( [ .targets[] | select(.entitlements[$k].status
        | . == "required" or . == "required-adjacent") | .key ] | sort ) as $granted
  | ( $present == $granted )
    and ( [ $present[] | select( . as $t | $absent | index($t) ) ] | length ) == 0
    and ( ( $present + $absent ) | unique | length ) == ( .targets | length )
' "$MATRIX" >/dev/null 2>&1
rc=$?; note $rc
printf 'current   A5/A18 partition (structural): %s exit=%d\n' \
  "$([ $rc -eq 0 ] && echo true || echo false)" $rc

jq -e '
  .verification.assertionScopeContract as $s2
  | ( [ .profiles[] | select( [ .development.devices[] | test("deferred") ] | any )
        | .target ] | sort )                                            as $deferred
  | ( [ $s2.profileScopes[] | select(.deviceBinding=="deferred") | .scopeProfiles[] ]
      | sort | unique )                                                 as $scoped_deferred
  | ( [ $s2.profileScopes[] | select(.deviceBinding=="enumerated") | .scopeProfiles[] ]
      | sort | unique )                                                 as $scoped_concrete
  | ( $scoped_deferred == $deferred )
    and ( [ $scoped_concrete[] | select( . as $t | $deferred | index($t) ) ] | length ) == 0
' "$MATRIX" >/dev/null 2>&1
rc=$?; note $rc
printf 'current   A9 scope vs declared devices (structural): %s exit=%d\n' \
  "$([ $rc -eq 0 ] && echo true || echo false)" $rc

echo
echo '=== 2. rule D1 (r9): does every declared consumer run after this contract? ==='
# The graph is read straight from task-board and the closure is computed here, so this is an
# independent confirmation rather than a re-run of the project's own gate. The second pass
# deletes the edge r9 added, which reproduces the r8 board state.
MATRIX="$MATRIX" REPO="$REPO" python3 - <<'PY'
import json, os, re, subprocess, sys

repo = os.environ["REPO"]
m = json.loads(open(os.environ["MATRIX"]).read())
me = m["owner"]
exempt = {e["element"] for e in m["consumerDependencyContract"]["exemptions"]}
consumers = []
for entry in m["consumers"]:
    for eid in re.findall(r"TASK-\d{6}-[0-9a-z]{6}", entry):
        if eid not in consumers:
            consumers.append(eid)

graph = {}
for kind in ("task", "bug"):
    out = subprocess.run(["task-board", "q", f"list(type={kind}) {{ id blockedBy }}"],
                         cwd=repo, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"task-board read failed: {out.stderr.strip()}")
    for element in json.loads(out.stdout):
        graph[element["id"]] = element.get("blockedBy") or []


def unreachable(g):
    def ancestors(start):
        seen, stack = set(), [start]
        while stack:
            for parent in g.get(stack.pop(), []):
                if parent not in seen:
                    seen.add(parent)
                    stack.append(parent)
        return seen
    return sorted(c for c in consumers if c not in exempt and me not in ancestors(c))


live = unreachable(graph)
print(f"live board          : {len(consumers)} declared, {len(exempt)} exempt, "
      f"{len(live)} unreachable {live}")
print(f"                      exit={1 if live else 0} "
      f"{'false' if live else 'true'}")

edge = m["consumerDependencyContract"]["boardChange"]["edge"].split()
blocked, blocker = edge[0], edge[-1]
graph[blocked] = [b for b in graph[blocked] if b != blocker]
before = unreachable(graph)
print(f"r8 state (r9 edge removed): {len(before)} unreachable {before}")
print(f"                      exit={1 if before else 0} "
      f"{'false' if before else 'true'}")
sys.exit(0 if (not live and before) else 1)
PY
rc=$?; note $rc
printf 'rule D1 flips r8 false -> r9 true: %s exit=%d\n' \
  "$([ $rc -eq 0 ] && echo true || echo false)" $rc

echo
echo '=== 3. verdict 09 F1 (r11) + verdict 10 F1 (r12): is the register DERIVED, and is'
echo '        reviewedIn the revision the entry actually entered in? ==='
# Re-implemented from scratch, like section 2: nothing below reads validate_matrix.py. Each
# field is recomputed from a source other than the register entry and its mirror on the
# target row, then the four coordinated-drift mutations are replayed through it. A gate that
# only compared the entry to its mirror would pass every one of them, which is the finding.
MATRIX="$MATRIX" BASELINE="${1:-}" python3 - <<'PY'
import copy
import hashlib
import json
import os
import re
import sys

KEY = "com.apple.security.temporary-exception.files.absolute-path.read-write"
MACH = "com.apple.security.temporary-exception.mach-lookup.global-name"
PATH = "/Library/Keychains/"
HERE = os.path.dirname(os.path.abspath(os.environ["MATRIX"])) or "."


def introducing_revision(m, register, key, target, snapshots):
    """Re-derive, from scratch, the revision a register entry first appeared in.

    r12, verdict 10 F1. r11's gate accepted ANY issued revision here and this script's
    section 3 checked exactly that, so the reviewer's control - reviewedIn moved from r10
    to r2 - passed both. Nothing below reads validate_matrix.py: the chain is loaded from
    disk, the digests are recomputed, and presence is tested by (key, target), which every
    revision of both registers has carried.

    Returns (revision or None, why).
    """
    present = []
    for revision, snapshot in snapshots:
        entries = (snapshot.get("exceptionEntitlementRule") or {}).get(register) or []
        present.append((revision, any((e.get("key"), e.get("target")) == (key, target)
                                      for e in entries)))
    if not present:
        return None, "no snapshot chain to derive from"
    if not present[0][1]:
        # decidable: absent from the oldest snapshot, so the first snapshot holding it is
        # the revision it entered in.
        first = next((rev for rev, seen in present if seen), None)
        return first, f"snapshot-proven ({'absent at ' + present[0][0]})"
    # present in the oldest snapshot, so the chain cannot decide; fall back to the OLDEST
    # append-only revisionLog summary naming the key verbatim.
    naming = [e["revision"] for e in m["revisionLog"] if key in (e.get("summary") or "")]
    if not naming:
        return None, "no revisionLog summary names the key"
    oldest = min(naming, key=lambda r: int(re.search(r"\.r(\d+)$", r).group(1)))
    return oldest, "summary-attested"


def provenance_ok(m, snapshots):
    """True when BOTH registers' reviewedIn equals the independently derived revision."""
    for register, key, target in (("reviewedExceptions", MACH, "macos.host"),
                                  ("conditionalExceptions", KEY, "macos.provider")):
        entries = (m.get("exceptionEntitlementRule") or {}).get(register) or []
        entry = next((e for e in entries
                      if (e.get("key"), e.get("target")) == (key, target)), None)
        if entry is None:
            return False, f"{register} holds no entry for ({key}, {target})"
        want, why = introducing_revision(m, register, key, target, snapshots)
        if want is None:
            return False, f"{register}: {why}"
        if entry.get("reviewedIn") != want:
            return False, (f"{register} claims review in {entry.get('reviewedIn')!r}, but it "
                           f"entered in {want!r} ({why})")
        # the declared introduction record must agree with the derived revision
        claimed = [e["revision"] for e in m["revisionLog"]
                   if entry.get("id") in (e.get("introduces") or [])]
        if claimed != [want]:
            return False, (f"{register}: revisionLog records the introduction of "
                           f"{entry.get('id')} as {claimed}, derived {want!r}")
    return True, "both registers' reviewedIn is the derived introducing revision"


def load_chain(m):
    """The snapshot chain from disk, digests recomputed here rather than trusted."""
    chain = ((m.get("exceptionEntitlementRule") or {})
             .get("exceptionReviewProvenance") or {}).get("snapshotChain") or []
    loaded, bad = [], []
    for entry in chain:
        path = os.path.join(HERE, entry.get("resource", ""))
        if not os.path.isfile(path):
            bad.append(f"{entry.get('revision')}: {entry.get('resource')} is not on disk")
            continue
        snapshot = json.loads(open(path).read())
        digest = hashlib.sha256(json.dumps(snapshot, sort_keys=True, separators=(",", ":"),
                                           ensure_ascii=False).encode()).hexdigest()
        if digest != entry.get("sha256"):
            bad.append(f"{entry.get('revision')}: digest does not match the pin")
            continue
        loaded.append((entry.get("revision"), snapshot))
    return loaded, bad


def derived_ok(m):
    """True when every field of every conditional entry is recomputable elsewhere."""
    reg = (m.get("exceptionEntitlementRule") or {}).get("conditionalExceptions") or []
    if len(reg) != 1:
        return False, "the register does not hold exactly one entry"
    c = reg[0]
    targets = {t["key"]: t for t in m["targets"]}
    rule = c.get("governedBy")
    scoped = [t["key"] for t in m["targets"] for row in t["entitlements"].values()
              if (row.get("osVersionScope") or {}).get("rule") == rule]
    consumers = {i for entry in m["consumers"]
                 for i in re.findall(r"TASK-\d{6}-[0-9a-z]{6}", entry)}
    owner = re.search(r"TASK-\d{6}-[0-9a-z]{6}",
                      (m.get("keychainSandboxFloorRule") or {}).get("resolutionOwner", "") or "")
    owner = owner.group(0) if owner else None
    values = c.get("valuesIfArmed") or []
    revisions = {m["revision"]} | {e["revision"] for e in m["revisionLog"]}
    chain, chain_errors = load_chain(m)
    provenance = provenance_ok(m, chain)
    deriv = (m["exceptionEntitlementRule"].get("conditionalExceptionDerivation") or {})
    tests = [
        (len(scoped) == 1 and scoped[0] == c.get("target"),
         "target is not the unique row carrying the governing version scope"),
        (c.get("channelsIfArmed") == (targets.get(c.get("target"), {}).get("channels")),
         "armed channels are not the target's own channel set, in full"),
        (c.get("armedBy") == owner, "arming owner is not the governing rule's owner"),
        (c.get("armedBy") in consumers, "arming owner is not a declared consumer"),
        (len(values) == 1, "the entry does not declare exactly one path"),
        (all(v.startswith(PATH) for v in values), "a path lies outside the reviewed subtree"),
        (all(not (PATH.startswith(v) and v != PATH) for v in values),
         "a path is an ancestor of the reviewed path"),
        (c.get("key") == KEY, "the key is not the reviewed read-write file exception"),
        (KEY in ((m.get("keychainSandboxFloorRule") or {}).get("ifGrantAbsentAtFloor") or ""),
         "the governing rule does not name the key it authorises"),
        (c.get("reviewedIn") in revisions, "reviewedIn names a revision never issued"),
        (len(deriv.get("fields") or []) == 8, "the derivation does not cover all eight fields"),
        # r12, verdict 10 F1. The line above is r11's whole bound on reviewedIn and it is
        # kept only as a cheap first filter — it accepts every issued revision, which is the
        # defect. The real test is the derivation below, over BOTH registers. The chain is
        # reloaded per contract, so a mutation that NARROWS it is seen by this gate.
        (not chain_errors, "the snapshot chain does not verify: " + "; ".join(chain_errors)),
        (provenance[0], "reviewedIn is not the derived introducing revision: "
                        + provenance[1]),
    ]
    for ok, why in tests:
        if not ok:
            return False, why
    return True, "every field is derived"


def report(label, path):
    m = json.loads(open(path).read())
    ok, why = derived_ok(m)
    print(f"{label:9} X1-C1 derivable-not-mirrored: {str(ok).lower()} "
          f"exit={0 if ok else 1} - {why}")
    return ok, m


_chain, _errors = load_chain(json.loads(open(os.environ["MATRIX"]).read()))
print(f"snapshot chain      : {[rev for rev, _ in _chain]} "
      f"{'digests verify' if not _errors else _errors}")

baseline = os.environ.get("BASELINE") or ""
if baseline and os.path.isfile(baseline):
    report("baseline", baseline)
ok, current = report("current", os.environ["MATRIX"])


def row(m, target):
    return next(t for t in m["targets"] if t["key"] == target)["entitlements"]


def widen(m):
    c = m["exceptionEntitlementRule"]["conditionalExceptions"][0]
    c["valuesIfArmed"] = ["/"]
    row(m, c["target"])[KEY]["valuesIfArmed"] = ["/"]


def channel(m):
    c = m["exceptionEntitlementRule"]["conditionalExceptions"][0]
    c["channelsIfArmed"] = ["development"]
    row(m, c["target"])[KEY]["channelsIfArmed"] = ["development"]


def arming_owner(m):
    c = m["exceptionEntitlementRule"]["conditionalExceptions"][0]
    c["armedBy"] = "TASK-260715-9yp8to"
    row(m, c["target"])[KEY]["resolutionOwner"] = "TASK-260715-9yp8to"


def move(m):
    c = m["exceptionEntitlementRule"]["conditionalExceptions"][0]
    entry = row(m, c["target"]).pop(KEY)
    c["target"] = "macos.host"
    c["scopeIfArmed"] = c["scopeIfArmed"].replace("macos.provider", "macos.host")
    row(m, "macos.host")[KEY] = entry


def reviewed_in_r2(m):
    """Verdict 10's own control, verbatim: r11 accepted this and exited 0."""
    m["exceptionEntitlementRule"]["conditionalExceptions"][0]["reviewedIn"] = "2026-07-28.r2"


def reviewed_in_coordinated(m):
    """The label, the declared introduction and the introduction record, moved together."""
    reviewed_in_r2(m)
    entries = m["exceptionEntitlementRule"]["exceptionReviewProvenance"]["entries"]
    next(e for e in entries if e["entry"] == "X1-C1")["introducedIn"] = "2026-07-28.r2"
    for event in m["revisionLog"]:
        if event["revision"] == "2026-07-28.r10":
            event["introduces"] = []
        if event["revision"] == "2026-07-28.r2":
            event["introduces"] = ["X1-C1"]


def active_reviewed_in_r2(m):
    """The ACTIVE register — the half no verdict reported, which r11 left unbounded."""
    m["exceptionEntitlementRule"]["reviewedExceptions"][0]["reviewedIn"] = "2026-07-28.r2"


def chain_narrowed(m):
    """Drop the snapshots in which X1-C1 is absent, which would demote it to attestation."""
    prov = m["exceptionEntitlementRule"]["exceptionReviewProvenance"]
    prov["snapshotChain"] = [c for c in prov["snapshotChain"]
                             if c["revision"] not in ("2026-07-28.r8", "2026-07-28.r9")]


bad = 0
for label, mutate in (("path widened to /", widen),
                      ("developer-id channel dropped", channel),
                      ("arming owner moved to another real consumer", arming_owner),
                      ("entry and row moved to macos.host", move),
                      ("verdict 10's control: reviewedIn r10 -> r2", reviewed_in_r2),
                      ("reviewedIn r10 -> r2 with the introduction record moved too",
                       reviewed_in_coordinated),
                      ("ACTIVE register reviewedIn r3 -> r2", active_reviewed_in_r2),
                      ("the chain is narrowed past the absence that proves the introduction",
                       chain_narrowed)):
    m = copy.deepcopy(current)
    mutate(m)
    got, why = derived_ok(m)
    rejected = not got
    print(f"negative  {label}: gate={str(got).lower()} exit={0 if got else 1} "
          f"{'OK' if rejected else 'GATE FAILED'} - {why}")
    if not rejected:
        bad += 1
sys.exit(1 if (bad or not ok) else 0)
PY
rc=$?; note $rc
printf 'verdict 09 F1 derivation gate and its negative controls: %s exit=%d\n' \
  "$([ $rc -eq 0 ] && echo true || echo false)" $rc

echo
if [[ $GATE_FAILURES -eq 0 ]]; then
  echo 'ALL INDEPENDENT GATES HOLD'
else
  echo "$GATE_FAILURES INDEPENDENT GATE(S) FAILED"
fi
exit $((GATE_FAILURES > 0))
