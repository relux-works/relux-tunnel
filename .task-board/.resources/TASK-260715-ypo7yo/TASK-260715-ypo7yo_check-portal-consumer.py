#!/usr/bin/env python3
"""Board-contract gate for the live consumers this matrix pins (rules P1, A1 and D1).

A JSON validator cannot read the board, so every requirement that lives on a board record
is pinned in the matrix and checked here instead.

Rule P1 — TASK-260715-3jloqy, the unattended task that SPENDS the C1 authorization.
  Reviewer verdict 05 F2: the matrix and Ceremony C1 were corrected to the post-G4/K2
  scope while the task that actually performs the mutations still carried the pre-r5
  capability contract. The reviewer caught it with an ad-hoc query plus an eyeball
  comparison. This script is the durable form of that check.

Rule A1 — TASK-260728-q5kjta, the human ceremony that GRANTS the authorization.
  Reviewer verdict 06 F1: r6 superseded r5 without re-pointing the ceremony's scope, which
  went on naming revision r5 — the revision verdict 05 had REJECTED. The r6 gate checked
  only the P1 consumer, so the authorization edge itself was the one live consumer nothing
  checked. Correcting one consumer and leaving the other is the defect both findings share,
  which is why one harness now covers both.

P1 asserts:
  1. every requiredPhrase is present, matched with a right boundary so
     works.relux.tunnel.mac is not satisfied by works.relux.tunnel.mac.tunnel;
  2. every bannedContractPhrase — the exact pre-r5 wording — is absent;
  3. every C1-authorized App ID is named, and no unauthorized identifier is;
  4. no forbidden portal record identifier is named as something to create.

A1 asserts:
  5. every requiredPhrase is present, and every C1-authorized App ID is named;
  6. the CURRENT revision is named, rendered from revisionPhraseTemplate;
  7. no SUPERSEDED revision is named — the set derived from revisionLog, not hand-listed;
  8. every CLAUSE naming an identifier the ceremony must not touch carries a negation.
     Absence is the wrong test here: stating an exclusion means naming the thing excluded.

Rule D1 — every OTHER consumer, new in r9. Found by self-audit, reported by no verdict.
  A1 and P1 pin the two consumers that name a revision, because a label can go stale.
  Every other consumer names no revision, so the only thing ordering it after this
  contract is accepted is the dependency edge — and three declared consumers had no
  path to this task at all, so a max_parallel=1 scheduler was free to run them while
  the matrix sat in analysis under its eighth changes-requested verdict.

D1 asserts:
  9.  every declared consumer resolves to a live board element;
  10. every non-exempt declared consumer TRANSITIVELY depends on this task;
  11. every registered exemption is genuinely UPSTREAM — this task depends on it. The
      claim is verified, not accepted, and `done` is not a basis: having finished is not
      evidence a consumer ran with this contract in hand;
  12. the ids mentioned anywhere in the contract and the declared consumer set agree in
      BOTH directions, so an obligation assigned in a sentence cannot stay off the list.

Exit 0 on agreement, 1 on drift, 2 if the board cannot be read.

Usage:  python3 TASK-260715-ypo7yo_check-portal-consumer.py [--json PATH] [--repo DIR]
                                                            [--simulate-board FILE]
                                                            [--simulate-graph FILE]

--simulate-board reads {task_id: record} from a JSON file instead of shelling out to
task-board. It exists so the negative gates in TASK-260715-ypo7yo_mutate.py can prove that
a stale revision, a dropped App ID and a lost exclusion each fail CLOSED, without mutating
a live board record to do it. --simulate-graph does the same for D1's dependency graph,
reading {element_id: [blockedBy...]}, so a deleted edge can be proven to fail closed
without unlinking anything on the live board.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

BASENAME = "apple-identifier-entitlement-matrix.json"
ELEMENT_ID = re.compile(r"(?:TASK|BUG|STORY|EPIC)-\d{6}-[0-9a-z]{6}")


def locate_matrix(explicit):
    if explicit:
        return Path(explicit)
    here = Path(__file__).parent
    for candidate in (here / BASENAME, here / f"TASK-260715-ypo7yo_{BASENAME}"):
        if candidate.exists():
            return candidate
    matches = sorted(here.glob(f"*{BASENAME}"))
    if matches:
        return matches[0]
    sys.exit(f"cannot find {BASENAME} next to {__file__}")


def read_board(task_id, repo, simulated):
    """Read the task's contract fields. task-board must run from the repo root."""
    if simulated is not None:
        if task_id not in simulated:
            print(f"SIMULATED BOARD has no record for {task_id}")
            return None
        return simulated[task_id]
    query = f"get({task_id}) {{ id description scope ac checklist notes }}"
    proc = subprocess.run(["task-board", "q", query], cwd=repo,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"BOARD READ FAILED (exit {proc.returncode}): {proc.stderr.strip()}")
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        print(f"BOARD READ FAILED: not JSON ({exc})")
        return None


def read_graph(repo, simulated):
    """The whole blockedBy graph, for rule D1's transitive closure.

    Tasks AND bugs. A bug can carry a dependency edge, so reading tasks alone would take a
    closure over a subgraph and could call a consumer unreachable — or reachable — on
    incomplete data.
    """
    if simulated is not None:
        return simulated
    graph = {}
    for kind in ("task", "bug"):
        proc = subprocess.run(
            ["task-board", "q", f"list(type={kind}) {{ id blockedBy }}"],
            cwd=repo, capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"BOARD GRAPH READ FAILED for {kind} (exit {proc.returncode}): "
                  f"{proc.stderr.strip()}")
            return None
        try:
            for element in json.loads(proc.stdout):
                graph[element["id"]] = element.get("blockedBy") or []
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            print(f"BOARD GRAPH READ FAILED for {kind}: unusable payload ({exc})")
            return None
    return graph


def ancestors(graph, start):
    """Everything `start` transitively depends on, following blockedBy edges."""
    seen, stack = set(), [start]
    while stack:
        for parent in graph.get(stack.pop(), []):
            if parent not in seen:
                seen.add(parent)
                stack.append(parent)
    return seen


def declared_consumers(m):
    """Every element id named in the `consumers` list."""
    found = []
    for entry in m["consumers"]:
        for eid in ELEMENT_ID.findall(entry):
            if eid not in found:
                found.append(eid)
    return found


def mentioned_ids(m, skip=()):
    """Every element id anywhere in the contract, optionally skipping top-level keys.

    Deliberately not the three named lists. `legacy.migrationDecisionOwner` carried an
    obligation owner for eight revisions and two prose sentences carried another for five;
    both were absent from `consumers`, which is exactly what a scan of the named lists
    would have kept missing.

    `skip` exists for the reverse direction: asking whether a declared consumer is explained
    anywhere has to exclude the declaration itself, or the question answers itself.
    """
    subject = {k: v for k, v in m.items() if k not in skip} if skip else m
    return set(ELEMENT_ID.findall(json.dumps(subject, ensure_ascii=False)))


def check_d1(m, graph):
    """Rule D1 — a declared consumer must actually run after this contract (r9)."""
    d1 = m["consumerDependencyContract"]
    g = Gate("D1", f"{len(declared_consumers(m))} declared consumers")

    me = d1["selfReference"]
    exemptions = {e["element"]: e for e in d1["exemptions"]}
    consumers = declared_consumers(m)

    g.check(me in graph, f"this contract's own owner {me} is not a live board element")
    my_ancestors = ancestors(graph, me)

    for eid in consumers:
        if eid in exemptions:
            continue
        g.check(eid in graph, f"declared consumer {eid} is not a live board element")
        if eid in graph:
            g.check(me in ancestors(graph, eid),
                    f"declared consumer {eid} has NO dependency path to {me}, so the "
                    f"scheduler may run it before this contract is accepted and it would be "
                    f"authored against an unaccepted matrix")

    # an exemption is verified, not accepted. `done` is not a basis — see whyNotAStatusCheck.
    for eid, record in exemptions.items():
        g.check(record["basis"] in d1["exemptionBasisAllowed"],
                f"exemption {eid} claims basis {record['basis']!r}, which is not in "
                f"{d1['exemptionBasisAllowed']}")
        g.check(eid in my_ancestors,
                f"exemption {eid} claims to be UPSTREAM, but {me} does not transitively "
                f"depend on it; an exemption that is not upstream is a consumer with its "
                f"gate switched off")

    # The mention set and the declared set must agree in BOTH directions. The second
    # direction reads mentions from everywhere ELSE — the consumers list is itself a string
    # in the contract, so counting it would make "declared but explained nowhere"
    # unfailable. See the same fix in validate_matrix.py's R37.
    mentioned = mentioned_ids(m) - {me}
    elsewhere = mentioned_ids(m, skip=("consumers", "consumerDependencyContract")) - {me}
    declared = set(consumers) | set(exemptions)
    for eid in sorted(mentioned - declared):
        g.check(False, f"{eid} is named in this contract but is neither a declared consumer "
                       f"nor a registered exemption; an obligation assigned in a sentence is "
                       f"still an obligation")
    for eid in sorted(declared - elsewhere):
        g.check(False, f"{eid} is a declared consumer that this contract never mentions "
                       f"outside the consumer list, so nothing says what it consumes")

    return g, ["blockedBy (tasks and bugs)"]


def occurrences(phrase, text):
    """Every standalone occurrence of an identifier-like phrase.

    An identifier that is a prefix of a longer one must occur on its own, otherwise
    'works.relux.tunnel.mac' would be satisfied by every mention of
    'works.relux.tunnel.mac.tunnel' and the host App ID could go unnamed.

    The boundary rejects a following dot only when that dot CONTINUES the identifier.
    r6 rejected every following dot, which silently failed to see an identifier at the
    end of a sentence — 'Also create works.relux.tunnel.ios.' read as no mention at all,
    so the r6 absence checks could be defeated by a full stop. An r7 board negative gate
    found that; see §13.
    """
    return list(re.finditer(re.escape(phrase) + r"(?![\w-])(?!\.\w)", text))


def present(phrase, text):
    return bool(occurrences(phrase, text))


def clauses(text):
    """Split into clauses without splitting identifiers.

    A dot inside these identifiers is NEVER followed by whitespace, so '.' plus space is
    a safe sentence boundary even though 'works.relux.tunnel.mac' is full of dots. ', and'
    / ', but' / ', nor' are split too: a paragraph that states several exclusions in one
    sentence must not let one clause's negation cover a neighbouring clause that lost its
    own. That is not hypothetical — it is exactly what a 220-character symmetric window
    did before an r7 negative gate caught it (§13).
    """
    parts = re.split(r"(?:[.;:]\s+|,\s+(?:and|but|nor)\s+)", text)
    return [p for p in parts if p.strip()]


def negated(phrase, text, markers):
    """True if every clause mentioning `phrase` also carries a negation marker.

    Absence is the wrong test for an identifier the ceremony must NOT touch: stating the
    exclusion is exactly what puts the identifier in the text. Attribution is per clause
    rather than per character window, because AC4 states its exclusion AFTER the
    identifiers it excludes — a preceding-context check would miss the real text — while a
    window wide enough to reach backwards over a list of four App IDs is also wide enough
    to let an adjacent clause's 'NOT' cover an identifier that has been quietly authorized.
    An unnegated occurrence anywhere fails: one reads as an authorization.
    """
    marker_re = re.compile(r"\b(" + "|".join(re.escape(w) for w in markers) + r")\b", re.I)
    mentioning = [c for c in clauses(text) if occurrences(phrase, c)]
    if not mentioning:
        return True  # never mentioned is vacuously fine; presence is checked separately
    return all(marker_re.search(c) for c in mentioning)


class Gate:
    """One consumer's checks, accumulated so both consumers report in a single run."""

    def __init__(self, rule, task_id):
        self.rule = rule
        self.task_id = task_id
        self.checked = 0
        self.failures = []

    def check(self, ok, detail):
        self.checked += 1
        if not ok:
            self.failures.append(detail)

    def report(self, fields):
        print(f"\nrule {self.rule} — {self.task_id}")
        print(f"  fields checked: {', '.join(fields)}")
        print(f"  checks run: {self.checked}")
        if self.failures:
            print(f"  FAIL ({len(self.failures)})")
            for f in self.failures:
                print("    -", f)
        else:
            print(f"  PASS — the board contract matches rule {self.rule}")
        return not self.failures


def check_p1(m, record):
    """Rule P1 — the unattended task that spends the authorization."""
    p1 = m["portalMutationTaskContract"]
    c1 = m["c1AuthorizationScope"]
    g = Gate("P1", p1["task"])
    gate = p1["boardGate"]

    text = "\n".join(str(record.get(f) or "") for f in gate["fields"])
    checklist = " ".join(i.get("text", "") for i in (record.get("checklist") or []))
    full = text + "\n" + checklist

    for phrase in gate["requiredPhrases"]:
        g.check(present(phrase, text),
                f"required phrase absent from {'/'.join(gate['fields'])}: {phrase!r}")

    for phrase in p1["bannedContractPhrases"]:
        g.check(phrase.lower() not in full.lower(),
                f"pre-r5 phrase is back on the board: {phrase!r}")

    for app_id in c1["authorizedAppIds"]:
        g.check(present(app_id, text), f"C1-authorized App ID not named: {app_id}")

    # nothing outside the C1 scope may be named as a provisioning target
    authorized = set(c1["authorizedAppIds"])
    for t in m["targets"]:
        if t["bundleIdentifier"] in authorized:
            continue
        g.check(not present(t["bundleIdentifier"], text),
                f'unauthorized identifier named in the portal contract: '
                f'{t["bundleIdentifier"]}')
    g.check(not present(m["legacy"]["bundleIdentifier"], text),
            f'the legacy identity {m["legacy"]["bundleIdentifier"]} is named in the portal '
            f"contract; it must not be touched")

    # a forbidden App Group record may not be named as something to create
    for grp in m["appGroups"]:
        rec = grp["portalRecordIdentifier"]
        if present(rec, text):
            g.check(re.search(r"(no|not|never|without)[^.]{0,80}" + re.escape(rec),
                              text, re.I) is not None,
                    f"App Group record {rec} is named in the portal contract outside a "
                    f"negation")

    return g, gate["fields"]


def check_a1(m, record):
    """Rule A1 — the human ceremony that grants the authorization (r7, verdict 06 F1)."""
    a1 = m["authorizationNodeContract"]
    c1 = m["c1AuthorizationScope"]
    g = Gate("A1", a1["task"])
    gate = a1["boardGate"]

    # append-only history is excluded on purpose: a past revision label in `notes` is a
    # true historical statement, not drift. Same reason rule S1 excludes revisionLog.
    text = "\n".join(str(record.get(f) or "") for f in gate["fields"])

    for phrase in gate["requiredPhrases"]:
        g.check(present(phrase, text),
                f"required phrase absent from {'/'.join(gate['fields'])}: {phrase!r}")

    # derived, so a change to c1AuthorizationScope cannot leave the gate behind
    for app_id in c1["authorizedAppIds"]:
        g.check(present(app_id, text), f"C1-authorized App ID not named: {app_id}")

    # the verdict-06 defect: the node must name the CURRENT revision...
    phrase = a1["revisionPhraseTemplate"].format(revision=m["revision"])
    g.check(phrase in text,
            f"the authorization node does not name the current matrix revision "
            f"({phrase!r}); it would ask the operator to approve a revision other than the "
            f"one under review")

    # ...and no revision this contract has superseded. The banned set is DERIVED from
    # revisionLog, so it cannot fall behind a bump.
    for entry in m["revisionLog"]:
        stale = entry["revision"]
        if stale == m["revision"]:
            continue
        g.check(not present(stale, text),
                f"the authorization node names superseded revision {stale}; a revision this "
                f"contract has replaced authorizes nothing, and r5 was rejected outright")

    # every identifier the ceremony must NOT touch may appear only inside a negation
    markers = gate["negationMarkers"]
    target_ids = {t["bundleIdentifier"] for t in m["targets"]}
    excluded = [i for i in c1["explicitlyNotAuthorized"] if i in target_ids]
    excluded += [grp["portalRecordIdentifier"] for grp in m["appGroups"]]
    excluded.append(m["legacy"]["bundleIdentifier"])
    for identifier in excluded:
        g.check(negated(identifier, text, markers),
                f"{identifier} is named in a clause of the authorization node that carries "
                f"no negation, so the operator could read it as authorized")

    return g, gate["fields"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="path to the matrix JSON")
    ap.add_argument("--repo", default=".", help="repo root the board lives in")
    ap.add_argument("--simulate-board",
                    help="JSON file of {task_id: record}; for negative gates only")
    ap.add_argument("--simulate-graph",
                    help="JSON file of {element_id: [blockedBy...]}; for negative gates only")
    args = ap.parse_args()

    m = json.loads(locate_matrix(args.json).read_text())
    simulated = None
    if args.simulate_board:
        simulated = json.loads(Path(args.simulate_board).read_text())
        print("SIMULATED BOARD — negative-gate mode, no live record was read")
    simulated_graph = None
    if args.simulate_graph:
        simulated_graph = json.loads(Path(args.simulate_graph).read_text())
        print("SIMULATED GRAPH — negative-gate mode, no live edge was changed")

    print(f"matrix revision: {m['revision']}")

    ok = True
    for builder, pin in ((check_a1, "authorizationNodeContract"),
                         (check_p1, "portalMutationTaskContract")):
        task_id = m[pin]["task"]
        record = read_board(task_id, args.repo, simulated)
        if record is None:
            return 2
        gate, fields = builder(m, record)
        ok = gate.report(fields) and ok

    graph = read_graph(args.repo, simulated_graph)
    if graph is None:
        return 2
    gate, fields = check_d1(m, graph)
    ok = gate.report(fields) and ok

    print()
    if not ok:
        print("FAIL — a pinned board consumer has drifted from this contract")
        return 1
    print("PASS — every pinned board consumer matches this contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
