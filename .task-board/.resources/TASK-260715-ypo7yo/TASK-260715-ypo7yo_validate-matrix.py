#!/usr/bin/env python3
"""Self-check for the TASK-260715-ypo7yo Apple identifier and entitlement matrix (r4).

Proves that the contract's own machine-checkable rules hold over its own data.
This does NOT inspect built bundles or downloaded profiles; those checks belong to
TASK-260715-3jloqy, TASK-260715-1r0fxv, TASK-260715-9yp8to and TASK-260715-uyju7n,
which consume the same JSON and apply the assertions in `verification.assertions`.

r2 adds gates for the four blocking findings of reviewer verdict 01:
  F1 -> R7, R19, R22, R23   Network Extension values modelled per signing channel
  F2 -> R9, R10, R18        App Group identifiers are iOS-style on both platforms
  F3 -> R20                 authored vs signing-generated entitlement allowlists
  F4 -> R21                 App Sandbox rationale attributed per requirement source

r3 adds gates for the blocking finding of reviewer verdict 02:
  F1 -> R25                 Sparkle Mach lookup exception on macos.host, and only there
     -> R26                 rule X1 reviewed-exception register and prohibited set
     -> R27                 the assertion set cannot silently shrink again

r4 adds gates for the blocking finding of reviewer verdict 03, and for the
TASK-260728-7ii1xz amendment packet:
  F1 -> R28                 rule G4 — an App Group is granted only where a currently
                            selected mechanism uses it, never on a future transport
     -> R30                 Ceremony C1 may not authorize a capability or record that
                            no C1-authorized App ID requires
  M1 -> R12, R29            keychain-access-groups on macos.provider is settled, and a
                            settled row may not keep the fields that held it open

r5 adds gates for the two architecture findings of reviewer verdict 04:
  F1 -> R31                 rule K2 — a keychain access group is granted only where a
                            NAMED second target reads the same group, so the macOS host
                            with no co-member falls back to its default access group
  F3 -> R28, R11, R30       an App Group is tested against the target's OWN contract, so
                            the iOS probe pair is withheld and the record that had no
                            consumer left is deleted rather than deferred

r6 adds gates for the blocking finding F1 of reviewer verdict 05, and closes the
defect class behind it rather than the one string that exposed it:
  F1 -> R32                 rule S1 — every cross-platform summary sentence is a checked
                            PROJECTION of the target rows and the record lists: the grant
                            set is derived, the grant clause must appear verbatim, the
                            names inside it must equal the derived set, every other target
                            named in the sentence must be a declared non-grantee mention,
                            and any App Group record-count claim must sit at a registered
                            path and agree with the record list
     -> R33                 the rationale document renders the same grant clauses, so the
                            prose artifact cannot drift from the JSON either

r7 adds a gate for the blocking finding F1 of reviewer verdict 06:
  F1 -> R34                 rule A1 — the human authorization node is pinned the way the
                            portal mutation task is: the pin names humanAuthorizationNode,
                            mirrors c1AuthorizationScope, renders a revision phrase from a
                            template rather than a frozen literal, derives its banned
                            superseded set from revisionLog, and the revision bookkeeping
                            itself (revision, supersedes, revisionLog ordering) is checked,
                            so a bump that leaves a consumer behind cannot pass

r8 adds gates for the two blocking findings of reviewer verdict 07, and closes the class
r6 left half-open — S1 made the cross-platform SUMMARY a checked projection of the rows
and left the ASSERTION LIST, the other prose projection of the same rows, unchecked:
  F1 -> R35                 rule S2 — every scope-bearing assertion declares its target
                            scope three ways (class predicates over the rows, an explicit
                            list, and the row statuses), all three must agree, the scope
                            clause must appear verbatim in the assertion and again in the
                            rationale document, and the present/absent scopes for each
                            entitlement key must PARTITION the eight rows — which A5 and
                            A18 did not, overlapping on the two iOS probe rows
  F2 -> R36                 the profile half of rule S2 — a profile assertion is scoped
                            over profiles[] the same way, deviceBinding says what the rows
                            must declare for the scope to be honest, the development
                            scopes partition the profile rows, and the concrete-device set
                            must equal the set Ceremony C1 authorizes

Verdict 05's F2 and verdict 06's F1 are BOARD contract defects — on TASK-260715-3jloqy
and TASK-260728-q5kjta respectively — which this validator cannot see. They are pinned
here as portalMutationTaskContract (P1) and authorizationNodeContract (A1) and gated
separately by TASK-260715-ypo7yo_check-portal-consumer.py, which reads both pins and both
live board records; R32 and R34 only check that the pins are well formed.
"""

import hashlib
import json
import re
import sys
from pathlib import Path

BASENAME = "apple-identifier-entitlement-matrix.json"
RATIONALE_BASENAME = "apple-identifier-entitlement-matrix.md"


def locate(basename, required=True):
    """Find a sibling artifact next to this script.

    Board resources are stored TASK-ID-prefixed, working copies are not, so accept
    either spelling rather than forcing the reviewer to rename anything.
    """
    here = Path(__file__).parent
    for candidate in (here / basename, here / f"TASK-260715-ypo7yo_{basename}"):
        if candidate.exists():
            return candidate
    matches = sorted(here.glob(f"*{basename}"))
    if matches:
        return matches[0]
    if required:
        sys.exit(f"cannot find {basename} next to {__file__}")
    return None


MATRIX = locate(BASENAME)
# r6: R33 compares the rendered grant clauses against the rationale document, so a
# missing document is a reported failure rather than a silent skip.
RATIONALE = locate(RATIONALE_BASENAME, required=False)

NE_KEY = "com.apple.developer.networking.networkextension"
SYSEX_KEY = "com.apple.developer.system-extension.install"
GROUPS_KEY = "com.apple.security.application-groups"
KEYCHAIN_KEY = "keychain-access-groups"
SANDBOX_KEY = "com.apple.security.app-sandbox"
MACH_LOOKUP_KEY = "com.apple.security.temporary-exception.mach-lookup.global-name"
TEMP_FILE_KEY = "com.apple.security.temporary-exception.files.absolute-path.read-write"
TEMP_EXCEPTION_PREFIX = "com.apple.security.temporary-exception."
BUNDLE_ID_VAR = "$(PRODUCT_BUNDLE_IDENTIFIER)"
SPARKLE_SUFFIXES = ["-spks", "-spki"]
SPARKLE_HOST = "macos.host"
EXPECTED_ASSERTIONS = [
    # r8: A9 split into A9a/A9b/A9c. One assertion cannot be simultaneously true of the
    # four macOS development profiles and the four iOS ones whose devices are deferred.
    "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9a", "A9b", "A9c",
    "A10a", "A10b", "A10c", "A10d", "A10e",
    "A14", "A15", "A16", "A17", "A18", "A11", "A12", "A13",
    # r10, verdict 08 F1: the unarmed conditional floor exception.
    "A19",
]

# r5: com.apple.security.application-groups is granted on the two PRODUCTION iOS targets
# only (rule G4). The probe pair is tested against the probe task's own contract, which
# names no shared container, not against the production shape it rehearses.
GROUPS_GRANTED_TARGETS = {"ios.host", "ios.provider"}
# Wording that makes a grant conditional on something undecided. A granted row whose
# rationale reads like this is the verdict-03 defect, whatever its status says.
CONDITIONAL_MARKERS = (
    "will use", "will select", "pending the", "once a transport", "if that channel",
    "not have to be repeated", "need not be repeated", "so that ceremony",
)

# r9: rules D1 and N1.
ELEMENT_ID = re.compile(r"(?:TASK|BUG|STORY|EPIC)-\d{6}-[0-9a-z]{6}")
NUMBER_WORDS = {
    0: "zero", 1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six",
    7: "seven", 8: "eight", 9: "nine", 10: "ten", 11: "eleven", 12: "twelve",
    13: "thirteen", 14: "fourteen", 15: "fifteen", 16: "sixteen", 17: "seventeen",
    18: "eighteen", 19: "nineteen", 20: "twenty",
}
# The blunt shape rule N1's coverage scan looks for. Deliberately blunt: a narrow pattern
# that only matched the sentences already registered would prove nothing.
NUMBER_WORD_ALTERNATION = "|".join(NUMBER_WORDS.values())
COUNT_CLAIM = re.compile(
    r"\*{0,2}(" + NUMBER_WORD_ALTERNATION + r"|\d+)\*{0,2}\s+"
    r"(?:\*{0,2}authored\*{0,2}\s+)?keys?\b", re.I)
# r11, verdict 09 required rework 4. The second shape: how many negative mutations stand
# behind a named gate. It did not exist, which is half of why the r10 preamble could say
# nine while the harness held seventeen; the other half was that the preamble was not
# scanned at all.
MUTATION_COUNT_CLAIM = re.compile(
    r"\*{0,2}(" + NUMBER_WORD_ALTERNATION + r"|\d+)\*{0,2}\s+"
    r"negative\s+(?:mutations?|gates?)\b", re.I)
# The third shape, found while closing the second: §9.2 opened by claiming this file
# applies "36 internal consistency rules (R1–R36)" while it gates R2–R39. Same class as
# the mutation count — a hand-written number about the harness, in the section that
# describes the harness — so it is derived from this file's own gate calls rather than
# corrected by hand for the fourth time.
RULE_COUNT_CLAIM = re.compile(
    r"\*{0,2}(" + NUMBER_WORD_ALTERNATION + r"|\d+)\*{0,2}\s+"
    r"internal\s+consistency\s+rules\b", re.I)
COUNT_SHAPES = {
    "allowlist-size": COUNT_CLAIM,
    "harness-count": MUTATION_COUNT_CLAIM,
    "rule-count": RULE_COUNT_CLAIM,
}
# The placeholder rule N1 writes its declared regexes with, so the declaration stays
# readable while still being comparable to the pattern this gate actually compiles.
NUMBER_WORD_PLACEHOLDER = "<number-word>"

# r11, verdict 09 F1. The reviewed least-privilege path for the conditional floor
# exception, held HERE rather than only in the register the gate is checking. A bound
# that lives only in the data it bounds is not a bound: verdict 09 moved both copies at
# once and r10 exited 0. Widening this is a reviewed amendment to the gate, visible in a
# diff a reviewer reads.
FLOOR_EXCEPTION_PATH = "/Library/Keychains/"

failures = []
checks = 0


def check(rule, ok, detail):
    global checks
    checks += 1
    if not ok:
        failures.append(f"{rule}: {detail}")


def norm(text):
    """Whitespace-normalised, so a hard-wrapped clause still compares equal."""
    return re.sub(r"\s+", " ", text)


def walk_strings(node, path=""):
    """Every string in the contract, with its dotted path. Used by rules D1 and N1."""
    if isinstance(node, dict):
        for key, value in node.items():
            yield from walk_strings(value, f"{path}.{key}" if path else key)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from walk_strings(value, f"{path}[{index}]")
    elif isinstance(node, str):
        yield path, node


def derive_allowlist(m, target_key, channel):
    """The exact expression §9.1 renders and assertions A10a-A10d apply.

    Rule N1 exists so the prose numbers are THIS set's size rather than arithmetic somebody
    did by hand three revisions ago.
    """
    target = next(t for t in m["targets"] if t["key"] == target_key)
    authored_ok = set(m["entitlementClassification"]["authoredStatuses"])
    keys = {k for k, v in target["entitlements"].items() if v["status"] in authored_ok}
    platform = target["platform"]
    generated = m["entitlementClassification"]["signingGenerated"][platform]
    injected = set(generated["always"])
    if channel == "development":
        injected |= set(generated["developmentChannelOnly"])
    return keys, injected


def gated_rule_ids():
    """Every rule id this file actually gates, read out of its own gate calls.

    r11. §9.2 opened by stating a rule count and a rule range, both by hand and both wrong.
    A number about the harness belongs to the harness.
    """
    source = Path(__file__).read_text()
    return sorted({int(n) for n in re.findall(r'check\("R(\d+)"', source)})


def rendered_count_claim(m, claim, rendered):
    """The rendered claim text, with every number RECOMPUTED from the rows."""
    kind = rendered["kind"]
    if kind == "harnessCount":
        # r11: not an allowlist projection — the size of a negative-gate set, declared by
        # rule N1 and checked against the harness by the harness itself. Rendered as a
        # digit because these counts run past the number-word table.
        counts = ((m["numericClaimContract"].get("harnessCounts") or {})
                  .get("declaredCounts") or {})
        # A missing register renders an impossible number rather than raising, so the
        # failure is reported by the rule that owns it instead of as a traceback.
        return rendered["template"].format(counts.get(rendered["rule"], "<undeclared>"))
    if kind == "gateCount":
        # r11: how many rules this file gates, read out of this file. Derived from the
        # source rather than from an executed-rule set so it does not depend on where in
        # the run the claim is rendered.
        ids = gated_rule_ids()
        return rendered["template"].format(len(ids), f"R{min(ids)}", f"R{max(ids)}")
    if kind == "totalPair":
        numbers = [len(set().union(*derive_allowlist(m, claim["target"], ch)))
                   for ch in rendered["channels"]]
    else:
        authored, injected = derive_allowlist(m, claim["target"], rendered["channel"])
        total = len(authored | injected)
        numbers = {
            "total": [total],
            "authored": [len(authored)],
            "authoredPlusInjected": [len(authored), len(injected)],
            "totalAuthoredInjected": [total, len(authored), len(injected)],
        }[kind]
    return rendered["template"].format(*[NUMBER_WORDS[n] for n in numbers])


def resolve_claim_path(m, path):
    """Resolve the one JSON path shape rule N1 registers: list[key=value].field.

    Returns (text, walk_path). The second value is the INDEXED path walk_strings() yields,
    which is what the coverage scan keys on — a registered claim written as
    `downstreamConsequences[owner=TASK-...]` has to be matched against
    `downstreamConsequences[2]`, or its own registration reads as an unregistered claim.
    """
    match = re.fullmatch(r"(\w+)\[(\w+)=([^\]]+)\]\.(\w+)", path)
    if not match:
        return None, None
    collection, key, value, field = match.groups()
    for index, entry in enumerate(m[collection]):
        if value in str(entry.get(key, "")):
            return entry.get(field), f"{collection}[{index}].{field}"
    return None, None


def doc_blocks(doc):
    """The rationale document split into ('preamble'|'N', text) blocks.

    Rule N1's coverage scan excludes §13 wholesale — it is history, and a past count in
    history is a true statement. Splitting at '## N.' keeps subsections (§9.4 lives in
    block 9) inside their parent, which is what the exclusion list means.

    r11: the PREAMBLE is no longer excluded. r9 excluded it as change history, which is
    half true — the older revision summaries are history, but the block for the current
    revision is the document's most-read live claim, and that is exactly where verdict 09
    found a stale count sitting invisibly. A historical number that must stay as it was is
    now handled the way §9.1's is, by a named excludedPhrases entry with a reason, rather
    than by switching off a region.
    """
    blocks, current, name = [], [], "preamble"
    for line in doc.split("\n"):
        heading = re.match(r"## (\d+)\.", line)
        if heading:
            blocks.append((name, "\n".join(current)))
            name, current = heading.group(1), [line]
        else:
            current.append(line)
    blocks.append((name, "\n".join(current)))
    return blocks


def revision_number(revision):
    """The ordinal of a '<date>.r<n>' revision label, or None if it is not one."""
    found = re.fullmatch(r"\d{4}-\d{2}-\d{2}\.r(\d+)", revision or "")
    return int(found.group(1)) if found else None


def canonical_digest(obj):
    """A digest over CONTENT, not bytes.

    r12, verdict 10. The snapshot chain is pinned so a baseline cannot be edited to
    manufacture an introduction, but a baseline that is merely re-indented is the same
    contract and must still verify — otherwise the pin would fail for a reason that has
    nothing to do with the property it protects, and would be relaxed.
    """
    return hashlib.sha256(json.dumps(obj, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False).encode("utf-8")).hexdigest()


def register_entries(contract, register):
    """Rule X1's register `register` in any revision of this contract, keyed by (key, target).

    Identity is (key, target) rather than the entry id: every revision of both registers has
    carried both fields, while the ACTIVE register's `id` is new in r12. A derivation that
    could only read the revisions that already agree with it would prove nothing.
    """
    entries = (contract.get("exceptionEntitlementRule") or {}).get(register) or []
    return {(e.get("key"), e.get("target")): e for e in entries}


def exception_provenance(m):
    """Derive the revision each X1 register entry was introduced in (rule X1-P).

    Reviewer verdict 10 F1: r11 required `reviewedIn` to be SOME revision this contract had
    issued, so the reviewer moved X1-C1 from r10 to r2 — a revision predating the conditional
    register entirely — and the validator exited 0. Membership is not provenance.

    Returns (structural_failures, per_entry) where per_entry maps an entry id to a dict
    carrying the derived revision and the failures found deriving it. The caller reports each
    entry under the rule that owns its register, so the failure lands where a reader looks.
    """
    rule = (m.get("exceptionEntitlementRule") or {}).get("exceptionReviewProvenance") or {}
    structural, per_entry = [], {}
    if not rule:
        return (["rule X1 states no exceptionReviewProvenance, so `reviewedIn` is whatever an "
                 "entry says it is — the verdict-10 F1 defect exactly"], per_entry)

    for field in ("id", "statement", "why", "principle", "boundStated", "digestForm",
                  "snapshotChainRule", "monotonicityRule", "introductionRecord",
                  "gateAssignmentNote", "source"):
        if not (rule.get(field) or "").strip():
            structural.append(f"exceptionReviewProvenance has no {field}")
    if rule.get("id") != "X1-P":
        structural.append(f'exceptionReviewProvenance id {rule.get("id")!r} != X1-P')

    # ---- the chain itself, before anything is derived from it ----------------
    chain = rule.get("snapshotChain") or []
    if not chain:
        structural.append("the provenance rule declares no snapshot chain, so an introduction "
                          "could only ever be self-attested by the file making the claim")
    revisions = [c.get("revision") for c in chain]
    if len(set(revisions)) != len(revisions):
        structural.append(f"the snapshot chain repeats a revision: {revisions}")
    numbers = [revision_number(r) for r in revisions]
    if any(n is None for n in numbers):
        structural.append(f"the snapshot chain holds a malformed revision label: {revisions}")
    elif numbers != sorted(numbers):
        structural.append(f"the snapshot chain is not oldest-first: {revisions}")
    elif numbers and numbers != list(range(numbers[0], numbers[0] + len(numbers))):
        # A gap in the middle is how a chain gets narrowed without losing an endpoint: drop
        # the snapshot in which an entry is absent and the entry becomes undecidable, which
        # demotes it to the weaker attested class on evidence that is still sitting on disk.
        structural.append(f"the snapshot chain skips a revision: {revisions}")
    # and it may not be narrowed by simply not declaring a baseline that is right there.
    undeclared = sorted(p.name for p in MATRIX.parent.glob("*baseline.json")
                        if p.name not in {c.get("resource") for c in chain})
    if undeclared:
        structural.append(
            f"baselines {undeclared} sit beside this contract and are not in the snapshot "
            f"chain; evidence that exists and is not declared is evidence a narrower chain "
            f"can be built on")
    if revisions and revisions[-1] != m.get("supersedes"):
        structural.append(
            f"the newest snapshot is {revisions[-1]}, but this contract supersedes "
            f'{m.get("supersedes")}; a bump that does not attach the superseded revision as a '
            f"baseline shortens the evidence chain silently")

    snapshots = []
    for entry in chain:
        path = locate(entry.get("resource") or "", required=False)
        if path is None:
            structural.append(
                f'snapshot {entry.get("revision")} declares resource '
                f'{entry.get("resource")!r}, which is not beside this contract; a chain that '
                f"cannot be read proves nothing, so this is a failure and never a skip")
            continue
        try:
            snapshot = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            structural.append(f'snapshot {entry.get("revision")} could not be read ({exc})')
            continue
        if canonical_digest(snapshot) != entry.get("sha256"):
            structural.append(
                f'snapshot {entry.get("revision")} does not match its pinned digest, so it is '
                f"not the revision this contract claims it is — an edited baseline can "
                f"manufacture an introduction")
            continue
        if snapshot.get("revision") != entry.get("revision"):
            structural.append(
                f'snapshot file {entry.get("resource")} is revision '
                f'{snapshot.get("revision")}, not the declared {entry.get("revision")}')
            continue
        snapshots.append((entry.get("revision"), snapshot))

    # ---- the declared introduction record, cross-checked below ---------------
    introduced_by, claimed_twice = {}, []
    for event in m.get("revisionLog") or []:
        listed = event.get("introduces")
        if listed is None:
            structural.append(
                f'revisionLog entry {event.get("revision")} declares no `introduces`, so the '
                f"introduction record has a hole exactly where a drifted entry would hide")
            continue
        for entry_id in listed:
            if entry_id in introduced_by:
                claimed_twice.append(entry_id)
            introduced_by[entry_id] = event.get("revision")

    # A register entry with no id is a defect this rule must REPORT, not crash on: it is
    # exactly the shape that would leave an entry unnamed by any introduction record. The
    # sentinel keeps it in the derivation so the failure lands as a check.
    live = {}
    for register in ("reviewedExceptions", "conditionalExceptions"):
        for entry in (m["exceptionEntitlementRule"].get(register) or []):
            live[entry.get("id") or "<no id>"] = register
    for entry_id, revision in sorted(introduced_by.items(), key=lambda kv: str(kv)):
        if entry_id not in live:
            structural.append(
                f"revisionLog {revision} claims to introduce {entry_id}, which is in neither "
                f"register; an introduction record for nothing is a claim nothing checks")
    for entry_id in sorted(set(claimed_twice)):
        structural.append(f"{entry_id} is claimed by more than one revision's `introduces`")

    declared = {(e.get("entry") or "<no id>"): e for e in rule.get("entries") or []}
    for entry_id, register in sorted(live.items(), key=lambda kv: str(kv)):
        if entry_id not in declared:
            structural.append(
                f"register entry {entry_id} ({register}) has no provenance entry, so its "
                f"`reviewedIn` is unconstrained while the rule reads as covering both registers")

    classes = set(rule.get("evidenceClasses") or [])
    if classes != {"snapshot-proven", "summary-attested"}:
        structural.append(
            f"the provenance rule declares evidence classes {sorted(classes)}; this gate "
            f"implements snapshot-proven and summary-attested, and a class the gate does not "
            f"implement is a promise nothing keeps")

    # ---- derive each entry --------------------------------------------------
    for entry_id, spec in sorted(declared.items(), key=lambda kv: str(kv)):
        found = []
        register, key, target = spec.get("register"), spec.get("key"), spec.get("target")
        if entry_id not in live:
            found.append(f"provenance names {entry_id}, which is in no register")
        elif live[entry_id] != register:
            found.append(f"provenance puts {entry_id} in {register}, but it is in "
                         f"{live[entry_id]}")
        entry = register_entries(m, register).get((key, target))
        if entry is None:
            found.append(f"provenance for {entry_id} names ({key}, {target}), which is in no "
                         f"register of this contract")
        elif entry.get("id") != entry_id:
            found.append(f"the register entry at ({key}, {target}) is "
                         f"{entry.get('id')!r}, not {entry_id}")

        # presence across the chain, then this contract. Monotone or it has no single
        # introduction to derive.
        presence = [(rev, (key, target) in register_entries(snap, register))
                    for rev, snap in snapshots]
        if entry is not None:
            presence.append((m.get("revision"), True))
        seen = [p for _, p in presence]
        if True in seen and not all(seen[seen.index(True):]):
            found.append(f"{entry_id} disappears from the snapshot chain and returns, so no "
                         f"single revision introduced it")

        evidence = spec.get("evidenceClass")
        decidable = bool(snapshots) and not presence[0][1]
        derived = None
        if decidable:
            if evidence != "snapshot-proven":
                found.append(
                    f"{entry_id} is decidable from the snapshot chain — it is absent from "
                    f"{presence[0][0]} — but claims the weaker {evidence!r} class; the gate "
                    f"refuses attestation where the chain can decide")
            derived = next((rev for rev, present in presence if present), None)
            if derived is None:
                found.append(f"{entry_id} is in no snapshot and not in this contract")
        else:
            if evidence != "summary-attested":
                found.append(
                    f"{entry_id} claims {evidence!r}, but it is present in the oldest attached "
                    f"snapshot, so the chain cannot decide when it entered")
            literal = spec.get("attestingLiteral")
            if literal != key:
                found.append(
                    f"{entry_id} attests on {literal!r}, which is not its own key; a literal "
                    f"chosen freely can be chosen to match a convenient revision")
            naming = [e.get("revision") for e in m.get("revisionLog") or []
                      if literal and literal in (e.get("summary") or "")]
            if not naming:
                found.append(f"no revisionLog summary names {entry_id}'s key, so nothing "
                             f"attests when it entered")
            else:
                derived = min(naming, key=lambda r: (revision_number(r) if revision_number(r)
                                                     is not None else 1 << 30))

        if derived is not None and spec.get("introducedIn") != derived:
            found.append(
                f'{entry_id} declares introducedIn {spec.get("introducedIn")!r}, but the '
                f"evidence derives {derived!r}")
        if derived is not None and introduced_by.get(entry_id) != derived:
            found.append(
                f"the revision log records {entry_id} as introduced in "
                f"{introduced_by.get(entry_id)!r}, but the evidence derives {derived!r}")
        if not (spec.get("why") or "").strip():
            found.append(f"provenance entry {entry_id} does not say how its class was reached")

        per_entry[entry_id] = {"register": register, "derived": derived, "failures": found,
                               "declared": spec}
    return structural, per_entry


def main():
    m = json.loads(MATRIX.read_text())
    targets = {t["key"]: t for t in m["targets"]}
    prefix = m["namespaces"]["reserved"]
    team = m["team"]["teamIdentifier"]
    legacy = m["legacy"]["bundleIdentifier"]
    groups = {g["key"]: g for g in m["appGroups"]}
    kc = m["keychainAccessGroups"][0]
    allowed_ne = set(m["allowedNetworkExtensionValues"])
    forbidden_ne = set(m["forbiddenNetworkExtensionValues"])
    channels = m["signingChannels"]
    ne_rule = m["networkExtensionRule"]
    classification = m["entitlementClassification"]
    authored_statuses = set(classification["authoredStatuses"])
    non_authored_statuses = set(classification["nonAuthoredStatuses"])
    profiles = {p["target"]: p for p in m["profiles"]}

    # R1 provider identifier is host identifier + ".tunnel"
    for t in m["targets"]:
        if t["role"] != "provider":
            continue
        host = targets[t["embeddedIn"]]
        check(
            "R1",
            t["bundleIdentifier"] == host["bundleIdentifier"] + ".tunnel",
            f'{t["key"]} {t["bundleIdentifier"]} is not {host["bundleIdentifier"]}.tunnel',
        )

    # R2 embedding is a bijection between one host and one provider
    for t in m["targets"]:
        if t["role"] == "host":
            child = targets[t["embeds"]]
            check("R2", child["embeddedIn"] == t["key"], f'{t["key"]} embed link is not reciprocal')
        else:
            check("R2", t["embeds"] is None, f'{t["key"]} is a provider but declares embeds')

    # R3 every identifier lives under the reserved namespace
    for t in m["targets"]:
        check("R3", t["bundleIdentifier"].startswith(prefix + "."),
              f'{t["bundleIdentifier"]} is outside {prefix}')

    # R4 nothing collides with or extends the legacy identity
    legacy_re = re.compile(r"^" + re.escape(legacy) + r"(\.|$)")
    for t in m["targets"]:
        check("R4", not legacy_re.match(t["bundleIdentifier"]),
              f'{t["bundleIdentifier"]} claims legacy {legacy}')
    check("R4", not legacy_re.match(prefix), f"reserved namespace {prefix} claims legacy {legacy}")

    # R5 identifiers are unique
    ids = [t["bundleIdentifier"] for t in m["targets"]]
    check("R5", len(ids) == len(set(ids)), f"duplicate bundle identifiers: {ids}")

    # R6 no per-configuration identifier suffix
    for t in m["targets"]:
        for bad in m["environmentRules"]["forbiddenIdentifierSuffixes"]:
            check("R6", not t["bundleIdentifier"].endswith(bad), f'{t["bundleIdentifier"]} ends with {bad}')

    # ---- F1 gates -------------------------------------------------------
    # R7 the NE value is derived from rule NE1: base value, plus the
    #    '-systemextension' suffix if and only if the channel is Developer ID.
    base = ne_rule["baseValue"]
    suffix = ne_rule["suffix"]
    for t in m["targets"]:
        e = t["entitlements"][NE_KEY]
        check("R7", e["status"] == "required", f'{t["key"]} does not require {NE_KEY}')
        check("R7", "value" not in e,
              f'{t["key"]} carries a channel-independent NE value; NE values must be keyed by channel')
        vbc = e.get("valueByChannel", {})
        check("R7", sorted(vbc.keys()) == sorted(t["channels"]),
              f'{t["key"]} valueByChannel keys {sorted(vbc.keys())} != channels {sorted(t["channels"])}')
        for ch, value in vbc.items():
            want = [base + suffix] if channels[ch]["networkExtensionSuffix"] else [base]
            check("R7", value == want, f'{t["key"]}/{ch} NE value {value} != {want}')
            check("R7", set(value) <= allowed_ne, f'{t["key"]}/{ch} NE value outside allowlist')
            check("R7", not (set(value) & forbidden_ne), f'{t["key"]}/{ch} grants a forbidden NE value')
            has_suffix = value[0].endswith(suffix)
            check("R7", has_suffix == channels[ch]["networkExtensionSuffix"],
                  f'{t["key"]}/{ch} suffix presence {has_suffix} disagrees with channel rule')

    # R19 declared channels agree with the signing-channel table and the profile rows
    for t in m["targets"]:
        chans = t["channels"]
        check("R19", "development" in chans, f'{t["key"]} has no development channel')
        for ch in chans:
            check("R19", ch in channels, f'{t["key"]} names unknown channel {ch}')
            check("R19", t["platform"] in channels[ch]["platforms"],
                  f'{t["key"]} uses channel {ch}, which does not apply to {t["platform"]}')
        p = profiles[t["key"]]
        check("R19", p["development"]["channel"] == "development",
              f'{t["key"]} development profile is not on the development channel')
        dist = p["distribution"]
        dist_chans = [c for c in chans if c != "development"]
        if dist is None:
            check("R19", dist_chans == [],
                  f'{t["key"]} declares distribution channels {dist_chans} but has no distribution profile')
        else:
            check("R19", dist_chans == [dist["channel"]],
                  f'{t["key"]} distribution channels {dist_chans} != profile channel {dist["channel"]}')

    # R23 each profile row authorizes exactly the NE values its channel needs
    for t in m["targets"]:
        vbc = t["entitlements"][NE_KEY]["valueByChannel"]
        p = profiles[t["key"]]
        for row in (p["development"], p["distribution"]):
            if row is None:
                continue
            ch = row["channel"]
            check("R23", row["authorizesNetworkExtensionValues"] == vbc[ch],
                  f'{t["key"]}/{ch} profile authorizes {row["authorizesNetworkExtensionValues"]} '
                  f'but the entitlement needs {vbc[ch]}')

    # ---- F2 gates -------------------------------------------------------
    # R9 the App Group literal is the SAME iOS-style identifier on both platforms.
    # r4: the RECORD is still cross-platform and still iOS-style, because the macOS row
    # can reopen under G4 and the iOS row re-arms under ADR-024. What changed is that the
    # ENTITLEMENT is granted on iOS only — that split is R28's job, not this rule's.
    def group_literal_is_ios_style(rule, who, lit):
        check(rule, lit.startswith("group."), f"{who} group literal {lit} is not iOS-style")
        check(rule, "$(TeamIdentifierPrefix)" not in lit and not lit.startswith(team),
              f"{who} group literal {lit} is team-prefixed; the contract chose the iOS style")

    for g in m["appGroups"]:
        for platform in ("iOS", "macOS"):
            group_literal_is_ios_style("R9", f'{g["key"]}/{platform}',
                                       g["entitlementLiteral"][platform])
    # r5: the probe record was deleted when the iOS probe pair lost the entitlement, so a
    # target's record is resolved through the record's own consumer list rather than
    # guessed from the target's family. The mapping is checked in BOTH directions, so a
    # granted row with no record and a record naming an ungranted target both fail.
    group_of_target = {tk: g for g in m["appGroups"] for tk in g["consumedByTargets"]}
    for t in m["targets"]:
        e = t["entitlements"][GROUPS_KEY]
        if e["status"] in authored_statuses:
            g = group_of_target.get(t["key"])
            check("R9", g is not None,
                  f'{t["key"]} is granted an App Group but no record names it as a consumer')
            if g is not None:
                check("R9", e.get("value") == [g["entitlementLiteral"][t["platform"]]],
                      f'{t["key"]} group {e.get("value")} != '
                      f'{g["entitlementLiteral"][t["platform"]]}')
            if e.get("value"):
                group_literal_is_ios_style("R9", t["key"], e["value"][0])
        else:
            check("R9", "value" not in e,
                  f'{t["key"]} carries an App Group value while the row is not granted')
            check("R9", t["key"] not in group_of_target,
                  f'{t["key"]} is not granted an App Group, but a record still names it as a '
                  f"consumer; a record whose consumers all lost the grant is deleted, not kept")

    # R10 resolved literals expand the build variables with the recorded team
    for g in m["appGroups"]:
        for platform in ("iOS", "macOS"):
            check("R10", g["resolvedLiteral"][platform] == g["entitlementLiteral"][platform],
                  f'{g["key"]} {platform} resolvedLiteral mismatch')
        check("R10", g["entitlementLiteral"]["iOS"] == g["entitlementLiteral"]["macOS"],
              f'{g["key"]} entitlement literal differs between platforms')
    check("R10", kc["resolvedLiteral"] == kc["entitlementLiteral"].replace(
        "$(AppIdentifierPrefix)", team + "."), "keychain resolvedLiteral mismatch")

    # R18 the portal record identifier IS the entitlement literal on both platforms
    for g in m["appGroups"]:
        check("R18", g["style"] == m["appGroupStyleRule"]["chosenStyle"],
              f'{g["key"]} style {g["style"]} != contract style')
        check("R18", g["portalRecordIdentifier"].startswith("group."),
              f'{g["key"]} portalRecordIdentifier is not allocatable on the Developer website')
        for platform in ("iOS", "macOS"):
            check("R18", g["entitlementLiteral"][platform] == g["portalRecordIdentifier"],
                  f'{g["key"]} {platform} literal does not equal the portal record it claims')
    portal_records = [g["portalRecordIdentifier"] for g in m["appGroups"]]
    check("R18", len(portal_records) == len(set(portal_records)),
          f"duplicate App Group records: {portal_records}")
    # r4: C1 no longer mirrors the record list. Which records C1 creates is DERIVED from
    # which C1-authorized App IDs actually need the capability — see R30.
    check("R18", set(m["c1AuthorizationScope"]["authorizedAppGroups"]) <= set(portal_records),
          "C1 authorizes an App Group record this contract does not declare")

    # R11 rule G3. r5: no probe target carries an App Group at all, which is strictly
    # stronger than r4's disjointness over two records. Disjointness is still enforced
    # over whatever records exist, so a reintroduced probe record cannot collide.
    g3 = m["appGroupDisjointnessRule"]
    check("R11", g3["id"] == "G3", f'appGroupDisjointnessRule id {g3["id"]} != G3')
    for field in ("statement", "history", "ifReintroduced"):
        check("R11", (g3.get(field) or "").strip(), f"rule G3 has no {field}")
    check("R11", g3.get("recordCount") == len(m["appGroups"]),
          f'rule G3 claims {g3.get("recordCount")} App Group records but '
          f'{len(m["appGroups"])} are declared')
    for t in m["targets"]:
        if t["family"] == "probe":
            check("R11", t["entitlements"][GROUPS_KEY]["status"] not in authored_statuses,
                  f'{t["key"]} is a probe and carries an App Group; rule G3 keeps the probe '
                  f"family free of group state so it stays genuinely disposable")
    claimed = {}
    for g in m["appGroups"]:
        for lit in sorted(set(g["resolvedLiteral"].values())):
            check("R11", lit not in claimed,
                  f'App Group literal {lit} is claimed by both {claimed.get(lit)} and {g["key"]}')
            claimed[lit] = g["key"]

    # R8 system-extension.install only on macOS hosts
    for t in m["targets"]:
        st = t["entitlements"][SYSEX_KEY]["status"]
        want = "required" if (t["platform"] == "macOS" and t["role"] == "host") else (
            "not-applicable" if t["platform"] == "iOS" else "prohibited")
        check("R8", st == want, f'{t["key"]} {SYSEX_KEY} status {st} != {want}')

    # R12 keychain access group is granted only where it is functional
    expected_kc = {
        # r5, verdict 04 F1: withheld under rule K2 — no second macOS target reads it
        "macos.host": "prohibited",
        "macos.provider": "prohibited",
        "ios.host": "required",
        "ios.provider": "required",
        "macos.probe.host": "prohibited",
        "macos.probe.provider": "prohibited",
        "ios.probe.host": "prohibited",
        "ios.probe.provider": "prohibited",
    }
    for key, want in expected_kc.items():
        got = targets[key]["entitlements"][KEYCHAIN_KEY]["status"]
        check("R12", got == want, f"{key} {KEYCHAIN_KEY} status {got} != {want}")
        if got == "required":
            check("R12", targets[key]["entitlements"][KEYCHAIN_KEY].get("value") == [kc["entitlementLiteral"]],
                  f"{key} keychain literal mismatch")
        else:
            check("R12", "value" not in targets[key]["entitlements"][KEYCHAIN_KEY],
                  f"{key} carries a keychain value while not granted")

    # R13 every row states a reason; every pending row names a resolution owner
    for t in m["targets"]:
        for k, e in t["entitlements"].items():
            check("R13", e.get("rationale"), f'{t["key"]}/{k} has no rationale')
            check("R13", e["status"] in authored_statuses | non_authored_statuses,
                  f'{t["key"]}/{k} has unknown status {e["status"]}')
            if e["status"].endswith("pending-decision"):
                check("R13", e.get("resolutionOwner"), f'{t["key"]}/{k} pending without resolutionOwner')
            # r4: and the converse. A row that is settled must not keep the fields that
            # existed only to hold it open — that is the defect TASK-260728-7ii1xz M1 named.
            else:
                check("R13", "resolutionOwner" not in e,
                      f'{t["key"]}/{k} is settled ({e["status"]}) but still names a resolutionOwner')
                check("R13", "amendmentRule" not in e,
                      f'{t["key"]}/{k} is settled ({e["status"]}) but still carries a row-level '
                      f"amendmentRule; a settled row states a reopening condition, not an "
                      f"instruction to re-grant itself")

    # R14 iOS targets are defined but not provisioned; macOS targets are provisioned
    for t in m["targets"]:
        want = t["platform"] == "macOS"
        check("R14", t["provisioned"] == want, f'{t["key"]} provisioned={t["provisioned"]} for {t["platform"]}')
        if not t["provisioned"]:
            check("R14", t.get("deferral"), f'{t["key"]} is unprovisioned without a named deferral')

    # R15 the probe family never carries a distribution profile
    for t in m["targets"]:
        check("R15", t["key"] in profiles, f'{t["key"]} has no profile row')
        if t["family"] == "probe":
            check("R15", profiles[t["key"]]["distribution"] is None,
                  f'{t["key"]} probe has a distribution profile')

    # R16 C1 authorizes exactly the provisioned macOS identifiers, and no iOS identifier
    c1 = m["c1AuthorizationScope"]
    want_ids = sorted(t["bundleIdentifier"] for t in m["targets"] if t["provisioned"])
    check("R16", sorted(c1["authorizedAppIds"]) == want_ids,
          f'C1 authorizedAppIds {sorted(c1["authorizedAppIds"])} != provisioned {want_ids}')
    ios_ids = {t["bundleIdentifier"] for t in m["targets"] if t["platform"] == "iOS"}
    check("R16", ios_ids <= set(c1["explicitlyNotAuthorized"]),
          "an iOS identifier is not explicitly excluded from C1")
    check("R16", not (ios_ids & set(c1["authorizedAppIds"])), "an iOS identifier is authorized at C1")

    # R17 only development profiles are C1-authorized
    for p in m["profiles"]:
        if p["distribution"]:
            check("R17", p["distribution"]["c1Authorized"] is False,
                  f'{p["target"]} distribution profile is C1-authorized')
        check("R17", p["development"]["c1Authorized"] == (targets[p["target"]]["platform"] == "macOS"),
              f'{p["target"]} development c1Authorized does not match platform provisioning')

    # R22 the Ceremony C1 scope carries development-channel NE values only
    check("R22", c1["authorizedChannels"] == ["development"],
          f'C1 authorizedChannels {c1["authorizedChannels"]} is not development-only')
    c1_ne = set()
    for t in m["targets"]:
        if t["provisioned"]:
            c1_ne |= set(t["entitlements"][NE_KEY]["valueByChannel"]["development"])
    check("R22", set(c1["authorizedNetworkExtensionValues"]) == c1_ne,
          f'C1 NE values {sorted(c1["authorizedNetworkExtensionValues"])} != provisioned development values {sorted(c1_ne)}')
    check("R22", not any(v.endswith(suffix) for v in c1["authorizedNetworkExtensionValues"]),
          "C1 authorizes a -systemextension value, but C1 creates development profiles only")
    for cap in c1["authorizedCapabilities"]:
        check("R22", suffix not in cap,
              f'C1 capability line names an entitlement value instead of a capability name: {cap!r}')

    # ---- F3 gate --------------------------------------------------------
    # R20 per-target, per-channel entitlement allowlists are computable and coherent
    for t in m["targets"]:
        plat = t["platform"]
        gen = classification["signingGenerated"][plat]
        authored = {k for k, e in t["entitlements"].items() if e["status"] in authored_statuses}
        required = {k for k, e in t["entitlements"].items() if e["status"] == "required"}
        non_authored = {k for k, e in t["entitlements"].items() if e["status"] in non_authored_statuses}
        check("R20", authored and required,
              f'{t["key"]} authors no entitlements; the allowlist would be signing-generated only')
        check("R20", not (authored & non_authored), f'{t["key"]} classifies a key as both authored and not')
        overlap = authored & (set(gen["always"]) | set(gen["developmentChannelOnly"]))
        check("R20", not overlap,
              f'{t["key"]} authors a key the toolchain generates: {sorted(overlap)}')
        for ch in t["channels"]:
            allowlist = authored | set(gen["always"])
            if ch == "development":
                allowlist |= set(gen["developmentChannelOnly"])
            check("R20", required <= allowlist, f'{t["key"]}/{ch} allowlist misses required keys')
            check("R20", not (non_authored & allowlist),
                  f'{t["key"]}/{ch} allowlist contains a prohibited or not-applicable key')
            check("R20", set(gen["always"]) <= allowlist,
                  f'{t["key"]}/{ch} allowlist misses a signing-generated key')
            dev_only_in = set(gen["developmentChannelOnly"]) & allowlist
            check("R20", bool(dev_only_in) == (ch == "development"),
                  f'{t["key"]}/{ch} development-only signing keys present={bool(dev_only_in)}')
            check("R20", channels[ch]["getTaskAllow"] == (ch == "development"),
                  f'channel {ch} getTaskAllow disagrees with the development-only classification')
    for plat, gen in classification["signingGenerated"].items():
        check("R20", gen["always"] and gen["developmentChannelOnly"],
              f"{plat} signing-generated classification is empty")

    # ---- F4 gate --------------------------------------------------------
    # R21 App Sandbox is attributed to the correct requirement source
    for t in m["targets"]:
        e = t["entitlements"][SANDBOX_KEY]
        src = e.get("requirementSource")
        check("R21", src is not None, f'{t["key"]} {SANDBOX_KEY} has no requirementSource')
        check("R21", e.get("requirementBasis"), f'{t["key"]} {SANDBOX_KEY} has no requirementBasis')
        if t["platform"] == "iOS":
            want = "platform-inherent"
            check("R21", e["status"] == "not-applicable", f'{t["key"]} iOS sandbox status is not not-applicable')
        elif t["role"] == "provider":
            want = "apple-requirement"
        else:
            want = "project-architecture"
        check("R21", src == want, f'{t["key"]} {SANDBOX_KEY} requirementSource {src} != {want}')
        if t["platform"] == "macOS" and t["role"] == "host":
            check("R21", src != "apple-requirement",
                  f'{t["key"]} attributes host sandboxing to an Apple rule; Apple does not require it')
    # every sandbox-consequence row must sit on a target that is actually sandboxed
    for t in m["targets"]:
        sandboxed = t["entitlements"][SANDBOX_KEY]["status"] in authored_statuses
        for k, e in t["entitlements"].items():
            if e.get("requirementSource") == "sandbox-consequence":
                check("R21", sandboxed,
                      f'{t["key"]}/{k} claims sandbox-consequence but the target is not sandboxed')

    # R24 no forbidden Network Extension value is granted by any target or profile.
    #     Scoped to the granting sites on purpose: the forbidden list itself, and the
    #     prose that explains it, legitimately name these values.
    granted = set()
    for t in m["targets"]:
        for value in t["entitlements"][NE_KEY]["valueByChannel"].values():
            granted |= set(value)
    for p in m["profiles"]:
        for row in (p["development"], p["distribution"]):
            if row:
                granted |= set(row["authorizesNetworkExtensionValues"])
    granted |= set(m["c1AuthorizationScope"]["authorizedNetworkExtensionValues"])
    check("R24", not (granted & forbidden_ne),
          f"forbidden NE values are granted: {sorted(granted & forbidden_ne)}")
    check("R24", granted <= allowed_ne,
          f"NE values granted outside the allowlist: {sorted(granted - allowed_ne)}")
    check("R24", not (allowed_ne & forbidden_ne),
          f"a value is both allowed and forbidden: {sorted(allowed_ne & forbidden_ne)}")

    # ---- verdict-02 F1 gates --------------------------------------------
    # R25 the Sparkle Mach lookup exception sits on the macOS host, and only there
    host = targets[SPARKLE_HOST]
    e = host["entitlements"].get(MACH_LOOKUP_KEY)
    check("R25", e is not None,
          f"{SPARKLE_HOST} does not declare {MACH_LOOKUP_KEY}; the sandboxed Sparkle host "
          f"requires it (.spec/platform-distribution.md)")
    if e is not None:
        check("R25", e["status"] == "required-adjacent",
              f'{SPARKLE_HOST} {MACH_LOOKUP_KEY} status {e["status"]} != required-adjacent')
        want_authored = [BUNDLE_ID_VAR + s for s in SPARKLE_SUFFIXES]
        check("R25", e.get("value") == want_authored,
              f'{SPARKLE_HOST} {MACH_LOOKUP_KEY} value {e.get("value")} != {want_authored}')
        # the signed bundle carries the expanded form, so the resolved values must be
        # derivable from the authored ones and the target's own bundle identifier
        want_resolved = [v.replace(BUNDLE_ID_VAR, host["bundleIdentifier"]) for v in want_authored]
        check("R25", e.get("resolvedValue") == want_resolved,
              f'{SPARKLE_HOST} {MACH_LOOKUP_KEY} resolvedValue {e.get("resolvedValue")} != {want_resolved}')
        check("R25", e.get("portalCapability") is False,
              f"{MACH_LOOKUP_KEY} is not a portal capability and must not claim one")
        check("R25", e.get("owner"), f"{MACH_LOOKUP_KEY} has no owner")
        check("R25", e.get("requirementSource") == "project-architecture",
              f'{MACH_LOOKUP_KEY} requirementSource {e.get("requirementSource")} != project-architecture')
        check("R25", ".spec/platform-distribution.md" in (e.get("requirementBasis") or ""),
              f"{MACH_LOOKUP_KEY} requirementBasis does not cite the spec clause that mandates it")
        check("R25", e.get("attributionNote"),
              f"{MACH_LOOKUP_KEY} does not say why it is project-architecture rather than "
              f"sandbox-consequence")
        check("R25", host["entitlements"][SANDBOX_KEY]["status"] in authored_statuses,
              f"{SPARKLE_HOST} carries a sandbox temporary exception but is not sandboxed")
    for t in m["targets"]:
        if t["key"] == SPARKLE_HOST:
            continue
        check("R25", MACH_LOOKUP_KEY not in t["entitlements"],
              f'{t["key"]} is granted {MACH_LOOKUP_KEY}; only {SPARKLE_HOST} links Sparkle')

    # R26 rule X1 — every temporary exception is registered, every relaxation is banned
    x1 = m["exceptionEntitlementRule"]
    check("R26", x1["id"] == "X1", f'exceptionEntitlementRule id {x1["id"]} != X1')
    check("R26", ".spec/platform-distribution.md" in x1["source"],
          "rule X1 does not cite the spec clause it enforces")
    registered = {(r["key"], r["target"]): r for r in x1["reviewedExceptions"]}
    authored_exceptions = set()
    for t in m["targets"]:
        for k, row in t["entitlements"].items():
            if k.startswith(TEMP_EXCEPTION_PREFIX) and row["status"] in authored_statuses:
                authored_exceptions.add((k, t["key"]))
    check("R26", authored_exceptions == set(registered),
          f"authored temporary exceptions {sorted(authored_exceptions)} do not match the X1 "
          f"register {sorted(registered)}")
    # r12, verdict 10: the provenance derivation is computed once and reported under the
    # rule that owns each register, so a drifted reviewedIn fails where a reader looks it up.
    provenance_structural, provenance = exception_provenance(m)
    for (k, tkey), r in registered.items():
        row = targets[tkey]["entitlements"].get(k, {})
        check("R26", r["values"] == row.get("value"),
              f"X1 register values for {tkey}/{k} disagree with the entitlement row")
        check("R26", r.get("reason") and r.get("reviewedIn") and r.get("scope"),
              f"X1 register entry for {tkey}/{k} is missing reason, reviewedIn, or scope")
        # r12: the ACTIVE register was the worse half of the verdict-10 class and no verdict
        # reported it. reviewedIn here was checked for non-emptiness alone, so it accepted
        # 2026-07-28.r99 — a revision this contract has never issued — while the conditional
        # register had rejected exactly that since r11. These are the entries authorising an
        # exception that IS in a signed bundle.
        check("R26", r.get("id"),
              f"X1 active register entry for {tkey}/{k} has no id, so no introduction record "
              f"can name it and its reviewedIn is derived from nothing")
        derived = provenance.get(r.get("id")) or {}
        check("R26", derived.get("register") == "reviewedExceptions",
              f'X1 active register entry {r.get("id")!r} has no provenance entry under rule '
              f"X1-P, so its reviewedIn is whatever it says it is")
        for failure in derived.get("failures") or []:
            check("R26", False, f"X1-P: {failure}")
        if derived.get("derived"):
            check("R26", r.get("reviewedIn") == derived["derived"],
                  f'X1 active register entry {r.get("id")} claims review in '
                  f'{r.get("reviewedIn")!r}, but it first entered this contract in '
                  f'{derived["derived"]!r}; naming an older revision implies a review that '
                  f"did not happen")
    banned = x1["prohibitedKeys"]
    check("R26", banned, "rule X1 bans nothing, so it constrains nothing")
    check("R26", len(banned) == len(set(banned)), f"duplicate prohibited keys: {banned}")
    for t in m["targets"]:
        clash = set(banned) & set(t["entitlements"])
        check("R26", not clash, f'{t["key"]} authors a prohibited relaxation: {sorted(clash)}')
    for plat, gen in classification["signingGenerated"].items():
        clash = set(banned) & (set(gen["always"]) | set(gen["developmentChannelOnly"]))
        check("R26", not clash,
              f"{plat} classifies a prohibited key as signing-generated: {sorted(clash)}")
    # get-task-allow is governed by the classification and A10d, never by X1; banning it
    # in both places would make the two mechanisms disagree about the development channel
    all_generated = {k for gen in classification["signingGenerated"].values()
                     for k in gen["always"] + gen["developmentChannelOnly"]}
    check("R26", not (set(banned) & all_generated),
          "rule X1 bans a key the toolchain injects; that belongs to A10d, not X1")

    # R27 the assertion set is exactly the expected one and every assertion says something
    ids = [a["id"] for a in m["verification"]["assertions"]]
    check("R27", sorted(ids) == sorted(EXPECTED_ASSERTIONS),
          f"assertion ids {sorted(ids)} != expected {sorted(EXPECTED_ASSERTIONS)}")
    check("R27", len(ids) == len(set(ids)), f"duplicate assertion ids: {ids}")
    for a in m["verification"]["assertions"]:
        check("R27", a.get("text", "").strip(), f'assertion {a["id"]} has no text')
    joined = " ".join(a["text"] for a in m["verification"]["assertions"])
    check("R27", MACH_LOOKUP_KEY in joined,
          "no assertion mentions the Sparkle Mach lookup exception, so nothing checks it")
    check("R27", "required-adjacent" in joined,
          "no assertion requires required-adjacent keys to be present in the signed bundle")
    check("R27", "prohibitedKeys" in joined, "no assertion enforces the X1 prohibited set")
    check("R27", "ABSENT from every macOS bundle" in joined,
          "no assertion enforces rule G4's macOS App Group absence, so a generated target could "
          "declare the capability and nothing at build time would notice")
    check("R27", "keychain-access-groups is ABSENT from every macOS bundle" in joined,
          "no assertion enforces rule K2's macOS keychain-access-groups absence, so a generated "
          "macOS target could re-declare the shared group and nothing at build time would notice")
    check("R27", "ABSENT from both iOS probe bundles" in joined,
          "no assertion enforces rule G4's iOS probe App Group absence, so the probe could carry "
          "an entitlement its own task never exercises and nothing at archive time would notice")
    # r8, verdict 07: the two corrected scopes are pinned as text the way r3 pinned the
    # assertion SET, so a later edit cannot quietly widen either one back out again.
    check("R27", "PRESENT on the two PRODUCTION iOS bundles" in joined,
          "no assertion restricts the iOS App Group grant to the two production rows, so the "
          "verdict-07 F1 over-entitlement of both disposable probes could return")
    check("R27", "deferred under ADR-024" in joined,
          "no assertion records that the iOS development profiles have no declared device set, "
          "so the verdict-07 F2 claim that every development profile carries this Mac could "
          "return")
    # the banned phrase is the defective SHAPE, not the words: A14 legitimately says a key is
    # absent from every iOS bundle, and only a PRESENCE claim over all four iOS rows is wrong
    check("R27", "is PRESENT on every iOS bundle" not in joined,
          "an assertion claims an entitlement is present on every iOS bundle; the iOS probe "
          "pair is prohibited under rule G4, which is exactly what verdict 07 F1 reported")
    check("R27", "every development profile carries ProvisionedDevices" not in joined,
          "an assertion claims every development profile carries ProvisionedDevices; the four "
          "iOS development profiles have no declared device set — verdict 07 F2")

    # ------------------------------------------------------------------ r4 gates
    # R28 rule G4 — an App Group is granted only where a currently selected mechanism
    # uses it. This is the gate for reviewer verdict 03's blocking finding: the r3
    # contract granted the capability on macOS for a transport that had not been chosen.
    g4 = m["appGroupLeastPrivilegeRule"]
    check("R28", g4["id"] == "G4", f'appGroupLeastPrivilegeRule id {g4["id"]} != G4')
    for field in ("statement", "surveyBasis", "privateContainerFinding", "selectedTransport",
                  "reopensOnly", "ceremonyCostIsZero", "source"):
        check("R28", (g4.get(field) or "").strip(), f"rule G4 has no {field}")
    check("R28", "application.sb" in g4["source"],
          "rule G4 does not cite the sandbox profile its survey was read from")
    survey = g4["survey"]
    check("R28", len(survey) >= 6,
          f"rule G4 surveys only {len(survey)} grants; the macOS entitlement confers six")
    for row in survey:
        for field in ("grant", "sandboxProfileLines", "namespace", "note"):
            check("R28", (row.get(field) or "").strip(), f"a G4 survey row has no {field}")
        check("R28", row["namespace"] in ("home-relative", "system-wide"),
              f'G4 survey row namespace {row["namespace"]} is neither home-relative nor system-wide')
        check("R28", isinstance(row.get("worksAcrossRootAndUserContexts"), bool),
              "a G4 survey row does not say whether the grant crosses the root/user boundary")
        check("R28", isinstance(row.get("usedBySelectedDesign"), bool),
              "a G4 survey row does not say whether the selected design uses the grant")
    # the whole verdict rests on this: nothing surveyed is actually used
    check("R28", not any(r["usedBySelectedDesign"] for r in survey),
          "a G4 survey row says the selected design DOES use an App Group grant on macOS, so the "
          "macOS rows cannot be withheld on least-privilege grounds — grant them or fix the survey")
    check("R28", any(r["namespace"] == "system-wide" for r in survey),
          "the G4 survey records no system-wide grant, so it has not looked past the group "
          "container and cannot support a least-privilege verdict")

    # r5, verdict 04 F3: G4 gained an explicit probe rule. A probe inherits identifiers and
    # profile classes from the shape it rehearses, never entitlements — each probe row is
    # tested against its own probe task's scope and acceptance criteria.
    check("R28", (g4.get("probeRule") or "").strip(),
          "rule G4 does not say how a probe row is tested, which is what let the iOS probe "
          "pair inherit a grant from the production rows it resembles")
    for t in m["targets"]:
        if t["family"] == "probe":
            check("R28", t["key"] not in GROUPS_GRANTED_TARGETS,
                  f'{t["key"]} is a probe and appears in the granted set; under G4 probeRule a '
                  f"probe grant needs its own acceptance criterion in its own probe task first")

    for t in m["targets"]:
        e = t["entitlements"][GROUPS_KEY]
        want_granted = t["key"] in GROUPS_GRANTED_TARGETS
        granted = e["status"] in authored_statuses
        check("R28", granted == want_granted,
              f'{t["key"]} ({t["platform"]}, {t["family"]}) {GROUPS_KEY} status {e["status"]}: '
              f'granted={granted} but rule G4 requires granted={want_granted}')
        if granted:
            check("R28", e["status"] == "required", f'{t["key"]} {GROUPS_KEY} is not required')
            check("R28", (e.get("functionOnThisPlatform") or "").strip(),
                  f'{t["key"]} is granted {GROUPS_KEY} without naming the function it serves')
            lowered = (e.get("rationale") or "").lower()
            hit = [mk for mk in CONDITIONAL_MARKERS if mk in lowered]
            check("R28", not hit,
                  f'{t["key"]} is granted {GROUPS_KEY} on a conditional or future rationale '
                  f'{hit}; rule G4 requires a currently selected mechanism')
        else:
            check("R28", e["status"] == "prohibited",
                  f'{t["key"]} {GROUPS_KEY} status {e["status"]} != prohibited; a withheld App '
                  f"Group is settled by G4, never left pending")
            check("R28", (e.get("reopensOnly") or "").strip(),
                  f'{t["key"]} withholds {GROUPS_KEY} without stating what would reopen it')
            check("R28", e.get("portalCapability") is False,
                  f'{t["key"]} withholds {GROUPS_KEY} but still claims a portal capability')
            check("R28", "portalCapabilityName" not in e,
                  f'{t["key"]} withholds {GROUPS_KEY} but still names a portal capability')
    # G2 must not describe the macOS group as something a future decision will use
    macos_purpose = (m["appGroupPurposeRule"]["macOS"] or "").lower()
    hit = [mk for mk in CONDITIONAL_MARKERS if mk in macos_purpose]
    check("R28", not hit,
          f"rule G2's macOS purpose is still conditional {hit}; verdict 03 rejected exactly that")

    # R29 settled rows, closed constraints, and rule K1 — the TASK-260728-7ii1xz packet
    k1 = m["keychainScopeRule"]
    check("R29", k1["id"] == "K1", f'keychainScopeRule id {k1["id"]} != K1')
    # r10: osFloorScope joins the required set. K1's supporting clause — "the sandbox
    # already grants what it needs" — was read on ONE OS version and stated as though it
    # were an invariant. Requiring the field here is what stops the scope being deleted
    # again by a revision that only reads K1 and never reads rule K3.
    for field in ("statement", "replaces", "reopeningCondition",
                  "shippingProductsAreNotEvidence", "source", "hostScope", "osFloorScope"):
        check("R29", (k1.get(field) or "").strip(), f"rule K1 has no {field}")
    # .get, not []: a DELETED clause must be reported by the field check above, not raise
    # and take the whole run's output with it — the same lesson rule S2 already learned.
    check("R29", "K3" in (k1.get("osFloorScope") or ""),
          "rule K1's osFloorScope does not point at the rule that owns the version scope, "
          "so the clause records a gap with no owner")
    check("R29", "TN3137" in k1["source"],
          "rule K1 does not cite the Apple note that distinguishes the two keychain "
          "implementations, which is the whole basis of the rule")
    prov_kc = targets["macos.provider"]["entitlements"][KEYCHAIN_KEY]
    check("R29", (prov_kc.get("reopensOnly") or "").strip(),
          "the settled macos.provider keychain row states no reopening condition")
    check("R29", "TASK-260728-7ii1xz" in (prov_kc.get("rationale") or ""),
          "the settled macos.provider keychain row does not name the task that settled it")
    constraints = {c["id"]: c for c in m["openConstraints"]}
    for cid, c in constraints.items():
        if c.get("status") == "closed":
            check("R29", c.get("resolvedBy"), f"{cid} is closed without naming a resolver")
            check("R29", (c.get("resolution") or "").strip(), f"{cid} is closed with no resolution")
            check("R29", "resolutionOwner" not in c,
                  f"{cid} is closed but still names a pending resolutionOwner")
            check("R29", c["matrixEffect"].startswith("closed"),
                  f'{cid} is closed but its matrixEffect still reads as open: {c["matrixEffect"]}')
        else:
            check("R29", c.get("resolutionOwner"), f"{cid} is open without a resolution owner")
    check("R29", constraints["OC-1"].get("status") == "closed",
          "OC-1 is still open, but the transport decision that owned it is done")
    check("R29", constraints["OC-1"].get("resolvedBy") == "TASK-260728-7ii1xz",
          "OC-1 is closed by the wrong task")

    # R30 Ceremony C1 may not authorize a capability or a record nothing needs.
    # Derived from the target rows, so shrinking or growing C1 by hand cannot pass.
    c1_ids = set(c1["authorizedAppIds"])
    c1_targets = [t for t in m["targets"] if t["bundleIdentifier"] in c1_ids]
    check("R30", len(c1_targets) == len(c1_ids), "a C1-authorized App ID has no target row")
    needs_groups = [t for t in c1_targets
                    if t["entitlements"][GROUPS_KEY]["status"] in authored_statuses]
    c1_mentions_groups = [cap for cap in c1["authorizedCapabilities"] if "App Group" in cap]
    check("R30", bool(needs_groups) == bool(c1_mentions_groups),
          f"C1 capability list {'omits' if needs_groups else 'still carries'} App Groups while "
          f"{len(needs_groups)} C1-authorized targets require the entitlement")
    # r5: derived through each record's own consumer list, because the probe record no
    # longer exists and family is no longer a reliable key into m["appGroups"].
    needs_keys = {t["key"] for t in needs_groups}
    want_records = sorted({g["portalRecordIdentifier"] for g in m["appGroups"]
                           if needs_keys & set(g["consumedByTargets"])})
    check("R30", sorted(c1["authorizedAppGroups"]) == want_records,
          f'C1 authorizes App Group records {sorted(c1["authorizedAppGroups"])} but its App IDs '
          f"require {want_records}")
    for g in m["appGroups"]:
        want_c1 = g["portalRecordIdentifier"] in want_records
        check("R30", g["c1Authorized"] == want_c1,
              f'{g["key"]} c1Authorized={g["c1Authorized"]} but C1 requirement is {want_c1}')
        if not want_c1:
            check("R30", (g.get("allocationOwner") or "").strip() and
                  (g.get("allocationTiming") or "").strip(),
                  f'{g["key"]} is not created at C1 and does not say who creates it, or when')
            check("R30", g.get("consumedByTargets"),
                  f'{g["key"]} is deferred past C1 without naming the targets that consume it')
            for tk in g["consumedByTargets"]:
                st = targets[tk]["entitlements"][GROUPS_KEY]["status"]
                check("R30", st in authored_statuses,
                      f'{g["key"]} names {tk} as a consumer, but {tk} is not granted the group')
    # and the capability may not sneak back in through the not-authorized list going stale
    if not needs_groups:
        joined_not = " ".join(c1["explicitlyNotAuthorized"])
        check("R30", "App Group" in joined_not,
              "C1 grants no App Groups capability but never says so explicitly, so an operator "
              "reading only the scope list cannot tell it was a decision")

    # ------------------------------------------------------------------ r5 gates
    # R31 rule K2 — a keychain access group is granted only where a NAMED second target
    # reads the same group. This is the gate for reviewer verdict 04's F1: r4 applied the
    # least-privilege test to the macOS provider row and never to the macOS host row, so a
    # shared group survived on a target that had nobody to share it with.
    k2 = m["keychainLeastPrivilegeRule"]
    check("R31", k2["id"] == "K2", f'keychainLeastPrivilegeRule id {k2["id"]} != K2')
    for field in ("statement", "defaultAccessGroupLaw", "sharingIsTheOnlyFunction",
                  "relationToK1", "reopeningCondition", "source"):
        check("R31", (k2.get(field) or "").strip(), f"rule K2 has no {field}")
    check("R31", "TN3137" in k2["source"] and "sharing-access-to-keychain-items" in k2["source"],
          "rule K2 does not cite both Apple sources it rests on: the note that the app "
          "identifier IS the default access group, and the note that macOS builds the access "
          "group list from profile-authorized entitlements")
    check("R31", (k1.get("hostScope") or "").strip(),
          "rule K1 does not record that it governs the provider only, which is the gap that let "
          "the macOS host keep a shared group with no co-member")

    granted_kc = sorted(t["key"] for t in m["targets"]
                        if t["entitlements"][KEYCHAIN_KEY]["status"] in authored_statuses)
    kc_consumers = sorted(kc.get("consumedByTargets") or [])
    check("R31", kc_consumers, "the keychain access group record names no consumers")
    check("R31", kc_consumers == granted_kc,
          f"keychain record consumers {kc_consumers} != the targets actually granted the group "
          f"{granted_kc}; the record and the rows must agree in both directions")
    # sharing needs two members. One member means the default access group would have done.
    check("R31", len(granted_kc) >= 2,
          f"keychain-access-groups is granted to {len(granted_kc)} target(s), so nothing shares "
          f"it and the default access group would serve the single member — that is exactly the "
          f"r4 defect on macos.host")
    check("R31", kc.get("platforms") == ["iOS"],
          f'the keychain record claims platforms {kc.get("platforms")}; after rule K2 the group '
          f"is consumed on iOS only")
    for tk in kc_consumers:
        check("R31", targets[tk]["platform"] == "iOS",
              f"{tk} consumes the keychain access group but is not an iOS target; rule K1 "
              f"excludes the root/system-domain macOS provider and rule K2 leaves the macOS host "
              f"with no co-member to share with")

    check("R31", (k2.get("settledByDecisionNotOmission") or "").strip(),
          "rule K2 does not require a withheld keychain row to say what would reopen it, so a "
          "row could stay prohibited by silence rather than by decision")
    for t in m["targets"]:
        e = t["entitlements"][KEYCHAIN_KEY]
        if t["platform"] == "macOS":
            check("R31", e["status"] == "prohibited",
                  f'{t["key"]} {KEYCHAIN_KEY} status {e["status"]} != prohibited; rule K2 leaves '
                  f"no macOS target a co-member")
        # every withheld row, on either platform and in either family, is settled by an
        # explicit decision rather than by omission
        if e["status"] not in authored_statuses:
            check("R31", (e.get("reopensOnly") or "").strip(),
                  f'{t["key"]} withholds {KEYCHAIN_KEY} without stating what would reopen it')
            check("R31", e.get("portalCapability") is False,
                  f'{t["key"]} withholds {KEYCHAIN_KEY} but still claims a portal capability')
        # a recorded default access group must obey K2's ordering law rather than assert
        # whatever the author expected: granted rows default to their first group, withheld
        # rows default to the injected app identifier.
        dag = e.get("defaultAccessGroup")
        if dag is not None:
            granted_value = e.get("value") or []
            if e["status"] in authored_statuses and granted_value:
                want = granted_value[0].replace("$(AppIdentifierPrefix)", team + ".")
            else:
                # a granted row with no literal is already an R12 failure; fall back to the
                # app identifier so this rule reports rather than raising
                want = f'{team}.{t["bundleIdentifier"]}'
            check("R31", dag == want,
                  f'{t["key"]} records default access group {dag}, but K2\'s ordering law gives '
                  f"{want}")
    check("R31", targets["macos.host"]["entitlements"][KEYCHAIN_KEY].get("defaultAccessGroup"),
          "the macos.host keychain row does not record the default access group it falls back "
          "to, which is the whole reason withholding the entitlement costs the host nothing")

    # ------------------------------------------------------------------ r6 gates
    # R32 rule S1 — the cross-platform summary is a DERIVED projection of the rows, not a
    # second statement of them. Reviewer verdict 05 F1: r5 moved eight target rows, two
    # rules, two assertions and the C1 scope, and left crossPlatformRules[2] asserting the
    # r4 contract. 846 checks passed because nothing looked at the summary.
    s1 = m["crossPlatformSharingContract"]
    rendered = m["crossPlatformRules"]
    check("R32", s1["id"] == "S1", f'crossPlatformSharingContract id {s1["id"]} != S1')
    for field in ("statement", "history", "mechanism", "displayNameDerivation",
                  "authorityNote", "recordCountClaimRule", "source"):
        check("R32", (s1.get(field) or "").strip(), f"rule S1 has no {field}")

    def display_name(t):
        family = " probe" if t["family"] == "probe" else ""
        return f'{t["platform"]}{family} {t["role"]}'

    names = {tk: display_name(t) for tk, t in targets.items()}
    collisions = sorted((a, b) for a in names for b in names
                        if a != b and names[a] in names[b])
    check("R32", not collisions,
          f"target display names overlap {collisions}, so a mention scan could attribute a "
          f"grant to the wrong target")

    def mentioned(text):
        """Targets named in a sentence, by display name or by raw key."""
        return {tk for tk in targets if names[tk] in text or tk in text}

    rules = s1["rules"]
    check("R32", len(rules) == len(rendered),
          f"{len(rules)} structured cross-platform rules for {len(rendered)} rendered "
          f"sentences; every sentence needs exactly one, or an unchecked sentence exists")
    check("R32", sorted(r["renderedIndex"] for r in rules) == list(range(len(rendered))),
          "renderedIndex is not a bijection onto the rendered sentences")
    rule_ids = [r["id"] for r in rules]
    check("R32", len(set(rule_ids)) == len(rule_ids), f"duplicate S1 rule ids: {rule_ids}")

    for r in rules:
        rid = r["id"]
        check("R32", re.match(r"^XP-\d+$", rid), f"S1 rule id {rid} is not XP-<n>")
        idx = r["renderedIndex"]
        stmt = rendered[idx] if 0 <= idx < len(rendered) else ""
        check("R32", stmt.strip(), f"{rid} renders no sentence")
        check("R32", (r.get("derivation") or "").strip(),
              f"{rid} does not say how its claim is derived")
        key = r.get("entitlementKey")
        style = r.get("mentionStyle")
        check("R32", style in ("enumerated", "universal", "none"),
              f"{rid} mentionStyle {style} is not enumerated, universal, or none")
        derived = set()
        if key is None:
            check("R32", style == "none" and r.get("grantedTargets") is None
                  and r.get("grantClause") is None,
                  f"{rid} summarises no entitlement but still declares a grant")
        else:
            check("R32", style != "none",
                  f"{rid} names entitlement {key} but declares mentionStyle none, so its grant "
                  f"claim would go unchecked")
            derived = {tk for tk, t in targets.items()
                       if t["entitlements"].get(key, {}).get("status") in authored_statuses}
            check("R32", derived, f"{rid} names entitlement {key} that no target row grants")
            check("R32", sorted(r.get("grantedTargets") or []) == sorted(derived),
                  f'{rid} grantedTargets {sorted(r.get("grantedTargets") or [])} != the targets '
                  f"the rows actually grant {sorted(derived)}")
            clause = r.get("grantClause") or ""
            check("R32", clause and clause in stmt,
                  f"{rid} grantClause is not present verbatim in the sentence it claims to "
                  f"summarise, so the sentence states a grant nothing checks")
            named = mentioned(clause)
            if style == "enumerated":
                check("R32", named == derived,
                      f"{rid} grantClause names {sorted(named)} but the rows grant "
                      f"{sorted(derived)}")
            elif style == "universal":
                check("R32", derived == set(targets),
                      f"{rid} claims a universal grant but only {sorted(derived)} carry it")
                check("R32", not named,
                      f"{rid} is universal yet enumerates {sorted(named)}; an enumerating "
                      f"sentence must be declared enumerated so its list is checked")
        # a target may not be named at all unless it is a grantee or a declared contrast
        declared = set()
        for nm in r.get("nonGranteeMentions", []):
            tk = nm.get("target")
            check("R32", tk in targets, f"{rid} declares a mention of unknown target {tk}")
            check("R32", tk not in derived,
                  f"{rid} declares {tk} as a non-grantee, but the rows grant it")
            check("R32", (nm.get("clause") or "") and nm.get("clause") in stmt,
                  f"{rid} declares a mention of {tk} whose clause is not in the sentence")
            check("R32", (nm.get("role") or "").strip(),
                  f"{rid} declares a mention of {tk} without saying what the mention is for")
            declared.add(tk)
        undeclared = mentioned(stmt) - derived - declared
        check("R32", not undeclared,
              f"{rid} names {sorted(undeclared)} without granting them and without declaring "
              f"the mention; that is exactly how the r4 macOS host claim survived into r5")

        src = r.get("recordSource")
        check("R32", src in (None, "appGroups", "keychainAccessGroups"),
              f"{rid} recordSource {src} is not a record list in this contract")
        if r.get("records") is not None:
            check("R32", src is not None, f"{rid} declares records but names no record source")
            if src == "appGroups":
                want_records = sorted(g["portalRecordIdentifier"] for g in m["appGroups"])
            else:
                want_records = sorted(x["name"] for x in m["keychainAccessGroups"])
            check("R32", sorted(r["records"]) == want_records,
                  f'{rid} records {sorted(r["records"])} != the records this contract declares '
                  f"{want_records}")
        for lit in re.findall(r"group\.[A-Za-z0-9._-]+", stmt):
            check("R32", lit in (r.get("records") or []),
                  f"{rid} names App Group literal {lit}, which is not a record this contract "
                  f"declares; a deleted record may not survive in a summary")

    # the summary and the record's own consumer list must agree, in both directions
    group_consumers = sorted({tk for g in m["appGroups"] for tk in g["consumedByTargets"]})
    kc_consumers_now = sorted(kc.get("consumedByTargets") or [])
    by_key = {r.get("entitlementKey"): r for r in rules if r.get("entitlementKey")}
    check("R32", GROUPS_KEY in by_key and KEYCHAIN_KEY in by_key,
          "the cross-platform summary no longer covers App Groups or Keychain sharing, the two "
          "entitlements whose sharing story differs by platform")
    if GROUPS_KEY in by_key:
        check("R32", sorted(by_key[GROUPS_KEY].get("grantedTargets") or []) == group_consumers,
              f"the App Group summary grants {by_key[GROUPS_KEY].get('grantedTargets')} but the "
              f"records name consumers {group_consumers}")
    if KEYCHAIN_KEY in by_key:
        check("R32", sorted(by_key[KEYCHAIN_KEY].get("grantedTargets") or []) == kc_consumers_now,
              f"the Keychain summary grants {by_key[KEYCHAIN_KEY].get('grantedTargets')} but the "
              f"record names consumers {kc_consumers_now}")

    # the other half of the class: a stale record COUNT. r5 deleted the probe record and
    # left sentences still counting r4's two.
    historical = tuple(s1["historicalPaths"])
    count_paths = s1["recordCountClaimPaths"]
    check("R32", historical, "rule S1 excludes no historical paths, so pinned revision history "
                             "would be scanned as if it described the current data")
    number_words = {"one": 1, "two": 2, "three": 3, "four": 4}
    count_re = re.compile(r"\b(one|two|three|four|[1-9])\s+App Group\s+records?\b", re.I)
    found_counts = []
    visited = set()

    def scan(node, path):
        if path:
            visited.add(path)
        if isinstance(node, dict):
            for k, v in node.items():
                scan(v, f"{path}.{k}" if path else k)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                scan(v, f"{path}[{i}]")
        elif isinstance(node, str):
            if any(path == h or path.startswith(h + ".") or path.startswith(h + "[")
                   for h in historical):
                return
            for hit in count_re.finditer(node):
                found_counts.append((path, hit.group(1)))

    scan(m, "")
    # a dead exclusion is how an allowlist rots: the path stops existing, nobody notices,
    # and the next edit widens the list again to cover the same ground.
    for h in historical:
        check("R32", h in visited,
              f"rule S1 excludes path {h} from the count scan, but no such path exists")
    for path, word in found_counts:
        check("R32", path in count_paths,
              f"{path} states an App Group record count but is not a registered count claim; "
              f"register it so R32 checks the number, or drop the count")
        want = number_words.get(word.lower(), None)
        if want is None:
            want = int(word)
        check("R32", want == len(m["appGroups"]),
              f'{path} claims {word} App Group record(s) but {len(m["appGroups"])} are declared')
    for p in count_paths:
        check("R32", any(path == p for path, _ in found_counts),
              f"registered count-claim path {p} no longer states a count, so the register has "
              f"drifted from the prose it governs")

    # the verdict-05 F2 pin. This validator cannot read the board; it can only check that
    # the requirement the board gate enforces is stated here, completely.
    p1 = m["portalMutationTaskContract"]
    check("R32", p1["id"] == "P1", f'portalMutationTaskContract id {p1["id"]} != P1')
    check("R32", p1["task"] == m["authorizesPortalMutationBy"],
          f'portalMutationTaskContract pins {p1["task"]}, but this matrix authorizes portal '
          f'mutation by {m["authorizesPortalMutationBy"]}')
    for field in ("statement", "history", "bannedPhraseNote", "gate", "source"):
        check("R32", (p1.get(field) or "").strip(), f"rule P1 has no {field}")
    for field in ("requiredMutations", "forbiddenMutations", "requiredNegativeAssertions",
                  "bannedContractPhrases"):
        check("R32", p1.get(field), f"rule P1 has an empty {field}")
    gate = p1.get("boardGate") or {}
    check("R32", gate.get("fields") and gate.get("requiredPhrases")
          and (gate.get("requiredPhraseNote") or "").strip(),
          "rule P1's boardGate is incomplete, so the board-contract check has nothing to assert")
    for app_id in c1["authorizedAppIds"]:
        check("R32", app_id in (gate.get("requiredPhrases") or []),
              f"P1's boardGate does not require the portal task to name {app_id}")
    check("R32", "hosts included" in (gate.get("requiredPhrases") or []),
          "P1's boardGate does not require the phrase that negates the removed 'only on provider "
          "identifiers' clause, so the provider-only defect could return unnoticed")
    # the pin must not drift from the C1 scope it exists to mirror
    joined_required = " ".join(p1["requiredMutations"])
    for app_id in c1["authorizedAppIds"]:
        check("R32", app_id in joined_required,
              f"rule P1 does not name C1-authorized App ID {app_id}, so the unattended task "
              f"could provision a different set than the human authorized")
    joined_forbidden = " ".join(p1["forbiddenMutations"])
    for g in m["appGroups"]:
        check("R32", g["portalRecordIdentifier"] in joined_forbidden,
              f'rule P1 does not forbid creating {g["portalRecordIdentifier"]}, which is '
              f"allocated at the later iOS sitting, not at C1")
    if not needs_groups:
        check("R32", "App Groups capability" in joined_forbidden,
              "rule P1 does not forbid the App Groups capability while no C1-authorized target "
              "needs it, which is the over-provisioning verdict 05 F2 named")

    # R34 rule A1 — the verdict-06 F1 pin. The authorization NODE is a live board consumer
    # exactly as the mutation task is, so it gets the same treatment: a complete pin here,
    # a board gate over there. This validator cannot read the board either, so R34 checks
    # that the requirement the board gate enforces is stated here, completely, and that the
    # revision bookkeeping the pin depends on is internally sound.
    a1 = m["authorizationNodeContract"]
    check("R34", a1["id"] == "A1", f'authorizationNodeContract id {a1["id"]} != A1')
    check("R34", a1["task"] == m["humanAuthorizationNode"],
          f'rule A1 pins {a1["task"]}, but this matrix names {m["humanAuthorizationNode"]} '
          f"as its human authorization node")
    check("R34", a1["task"] != m["authorizesPortalMutationBy"],
          "rule A1 pins the same task as rule P1; the node that GRANTS the authorization "
          "and the task that SPENDS it are different board elements")
    for field in ("statement", "history", "revisionPinRule", "revisionPhraseTemplate",
                  "digestAlternativeRejected", "gate", "source"):
        check("R34", (a1.get(field) or "").strip(), f"rule A1 has no {field}")
    for field in ("requiredAuthorizations", "forbiddenAuthorizations"):
        check("R34", a1.get(field), f"rule A1 has an empty {field}")

    # the pin must not drift from the C1 scope it exists to mirror
    joined_authorized = " ".join(a1["requiredAuthorizations"])
    for app_id in c1["authorizedAppIds"]:
        check("R34", app_id in joined_authorized,
              f"rule A1 does not name C1-authorized App ID {app_id}, so the operator could "
              f"be asked to authorize a different set than this contract requires")
    joined_refused = " ".join(a1["forbiddenAuthorizations"])
    for g in m["appGroups"]:
        check("R34", g["portalRecordIdentifier"] in joined_refused,
              f'rule A1 does not refuse authorization for {g["portalRecordIdentifier"]}')
    check("R34", legacy in joined_refused,
          f"rule A1 does not refuse authorization for the legacy identity {legacy}")
    if not needs_groups:
        check("R34", "App Groups capability" in joined_refused,
              "rule A1 does not refuse the App Groups capability while no C1-authorized "
              "target needs it")

    a1_gate = a1.get("boardGate") or {}
    check("R34", a1_gate.get("fields") and a1_gate.get("requiredPhrases")
          and (a1_gate.get("requiredPhraseNote") or "").strip(),
          "rule A1's boardGate is incomplete, so the board-contract check has nothing to "
          "assert about the authorization node")
    for app_id in c1["authorizedAppIds"]:
        check("R34", app_id in (a1_gate.get("requiredPhrases") or []),
              f"A1's boardGate does not require the authorization node to name {app_id}")
    # the exclusion list is DERIVED, so it must not be frozen into the pin as a literal
    check("R34", (a1_gate.get("negatedPhraseSource") or "").startswith("DERIVED"),
          "A1's boardGate does not derive its negated-phrase set, so an identifier removed "
          "from c1AuthorizationScope.explicitlyNotAuthorized would stop being checked")
    check("R34", a1_gate.get("negationScope") == "clause",
          f'A1\'s boardGate attributes negation per {a1_gate.get("negationScope")!r}, not '
          f"per clause; a character window lets a neighbouring clause's negation cover an "
          f"identifier that has quietly become authorized")
    check("R34", (a1_gate.get("clauseBoundaries") or "").strip(),
          "A1's boardGate declares no clause boundaries, so the negation scope it claims "
          "to use is not specified anywhere")
    check("R34", a1_gate.get("negationMarkers"),
          "A1's boardGate declares no negation markers")
    check("R34", (a1_gate.get("negationNote") or "").strip(),
          "A1's boardGate does not say why absence is the wrong test for an excluded "
          "identifier, so a later editor would 'simplify' it back to an absence check")
    # append-only history must be excluded, or a true past statement reads as drift
    check("R34", "notes" in (a1_gate.get("excludedFields") or []),
          "A1's boardGate does not exclude the append-only notes field, so a revision "
          "label that is a true historical statement would be reported as staleness")
    for f in a1_gate.get("excludedFields") or []:
        check("R34", f not in (a1_gate.get("fields") or []),
              f"A1's boardGate both checks and excludes field {f}")

    # the revision phrase is rendered from the CURRENT revision, never frozen
    template = a1["revisionPhraseTemplate"]
    check("R34", "{revision}" in template,
          f"A1's revisionPhraseTemplate {template!r} does not interpolate {{revision}}, so "
          f"it would pin one literal revision forever")
    for r_field in ("statement", "revisionPinRule", "revisionPhraseTemplate"):
        check("R34", m["revision"] not in a1[r_field],
              f"rule A1's {r_field} hard-codes revision {m['revision']}; the pin must be "
              f"derived so a bump cannot leave it behind")

    # revision bookkeeping, which the whole pin rests on
    log_revisions = [e["revision"] for e in m["revisionLog"]]
    check("R34", log_revisions and log_revisions[0] == m["revision"],
          f'revisionLog starts at {log_revisions[:1]}, not the current revision '
          f'{m["revision"]}')
    check("R34", len(log_revisions) > 1 and m["supersedes"] == log_revisions[1],
          f'supersedes {m["supersedes"]} is not the previous revisionLog entry '
          f'{log_revisions[1] if len(log_revisions) > 1 else None}')
    check("R34", len(set(log_revisions)) == len(log_revisions),
          f"revisionLog repeats a revision: {log_revisions}")
    check("R34", m["revision"] != m["supersedes"],
          f'revision and supersedes are both {m["revision"]}')
    for e in m["revisionLog"]:
        check("R34", re.match(r"^\d{4}-\d{2}-\d{2}\.r\d+$", e["revision"]),
              f'revisionLog entry {e["revision"]} is not <date>.r<n>')
    ordinals = [int(r.rsplit(".r", 1)[1]) for r in log_revisions]
    check("R34", ordinals == sorted(ordinals, reverse=True),
          f"revisionLog is not newest-first: {log_revisions}")
    # amendmentRule is what makes the pin survive the NEXT bump rather than this one
    for needle in ("re-point", a1["task"], m["authorizesPortalMutationBy"]):
        check("R34", needle.lower() in m["amendmentRule"].lower(),
              f"the amendment rule does not mention {needle!r}, so a future amendment is "
              f"not required to re-point the board consumers this contract pins")

    # ------------------------------------------------------------------ r8 gates
    # R35 rule S2 — an assertion's TARGET SCOPE is a derived projection of the rows, not a
    # second statement of them. Reviewer verdict 07: r6 closed this class for the
    # cross-platform summary (rule S1) and left the assertion list — the OTHER prose
    # projection of the same rows — unchecked. A5 claimed every iOS bundle while both iOS
    # probe rows are prohibited and A18 required them absent. 1024 checks passed because
    # R27 compared assertion membership and substrings, never scope against the rows.
    s2 = m["verification"]["assertionScopeContract"]
    check("R35", s2["id"] == "S2", f'assertionScopeContract id {s2["id"]} != S2')
    for field in ("statement", "history", "mechanism", "polarityNote", "partitionRule",
                  "coverageRule", "profileScopeRule", "deferredDeviceMarker",
                  "deferralBasis", "deferredMarkerNote", "authorityNote", "source"):
        check("R35", (s2.get(field) or "").strip(), f"rule S2 has no {field}")
    check("R35", s2.get("staleClaimsFound"),
          "rule S2 records no stale claim, so the defect it exists to prevent is undocumented")
    for sc in s2.get("staleClaimsFound") or []:
        for field in ("where", "reportedBy", "wrongSince", "claim", "truth", "consequence"):
            check("R35", (sc.get(field) or "").strip(),
                  f"an S2 staleClaimsFound row has no {field}")

    assertion_text = {a["id"]: a["text"] for a in m["verification"]["assertions"]}
    declared_keys = {k for t in m["targets"] for k in t["entitlements"]}

    def rows_matching(predicates):
        """Target keys selected by the UNION of a list of row predicates."""
        out = set()
        for p in predicates:
            for tk, t in targets.items():
                if all(t.get(f) == v for f, v in p.items()):
                    out.add(tk)
        return out

    escopes = s2["entitlementScopes"]
    e_ids = [e["id"] for e in escopes]
    check("R35", len(set(e_ids)) == len(e_ids), f"duplicate S2 entitlement scope ids: {e_ids}")
    scope_union = {}
    for e in escopes:
        eid = e["id"]
        check("R35", re.match(r"^AS-\d+$", eid), f"S2 scope id {eid} is not AS-<n>")
        aid = e.get("assertion")
        check("R35", aid in assertion_text, f"{eid} scopes unknown assertion {aid}")
        key = e.get("entitlementKey")
        check("R35", key in declared_keys,
              f"{eid} scopes entitlement {key}, which no target row declares")
        pol = e.get("polarity")
        check("R35", pol in ("present", "present-exclusive", "absent"),
              f"{eid} polarity {pol} is not present, present-exclusive, or absent")
        check("R35", (e.get("derivation") or "").strip(),
              f"{eid} does not say how its scope is derived")

        # derivation 1: the class predicates, evaluated over the rows
        preds = e.get("classPredicates")
        check("R35", isinstance(preds, list) and preds,
              f"{eid} declares no classPredicates, so its scope is a hand-written list that "
              f"nothing derives")
        for p in preds or []:
            check("R35", set(p) <= {"platform", "role", "family"},
                  f"{eid} predicate {p} constrains a field that is not a target row class")
            for f, v in p.items():
                check("R35", any(t.get(f) == v for t in targets.values()),
                      f"{eid} predicate field {f}={v!r} matches no target row, so the predicate "
                      f"silently selects a smaller set than it reads as")
        derived_pred = rows_matching(preds or [])
        # derivation 2: the declared list
        declared_scope = sorted(e.get("scopeTargets") or [])
        check("R35", declared_scope == sorted(derived_pred),
              f"{eid} scopeTargets {declared_scope} != the rows its predicates select "
              f"{sorted(derived_pred)}")
        # derivation 3: the row statuses, which must agree with the polarity
        for tk in sorted(derived_pred):
            st = targets[tk]["entitlements"].get(key, {}).get("status")
            if pol == "absent":
                check("R35", st is None or st in non_authored_statuses,
                      f"{eid} claims {key} is absent from {tk}, but the row authors it with "
                      f"status {st}")
            else:
                check("R35", st in authored_statuses,
                      f"{eid} claims {key} is present on {tk}, but the row's status is {st}")

        text = assertion_text.get(aid, "")
        clause = e.get("scopeClause") or ""
        check("R35", clause and clause in text,
              f"{eid} scopeClause is not present verbatim in assertion {aid}, so the assertion "
              f"states a scope that nothing checks")
        if pol == "present-exclusive":
            marker = e.get("exclusivityMarker") or ""
            check("R35", marker and marker in text,
                  f"{eid} is present-exclusive but its exclusivityMarker {marker!r} is not in "
                  f"assertion {aid}; 'present on X' alone says nothing about the other rows")
        else:
            check("R35", not e.get("exclusivityMarker"),
                  f"{eid} is {pol} yet declares an exclusivityMarker")
        scope_union.setdefault(aid, set()).update(derived_pred)

    # declared contrast mentions, then the undeclared-mention scan
    for e in escopes:
        aid, eid = e["assertion"], e["id"]
        text = assertion_text.get(aid, "")
        for nm in e.get("nonScopeMentions") or []:
            tk = nm.get("target")
            check("R35", tk in targets, f"{eid} declares a mention of unknown target {tk}")
            check("R35", tk not in scope_union.get(aid, set()),
                  f"{eid} declares {tk} as out of scope, but assertion {aid} scopes it")
            check("R35", (nm.get("clause") or "") and nm.get("clause") in text,
                  f"{eid} declares a mention of {tk} whose clause is not in assertion {aid}")
            check("R35", (nm.get("role") or "").strip(),
                  f"{eid} declares a mention of {tk} without saying what the mention is for")
    for aid in sorted(scope_union):
        declared_mentions = {nm["target"] for e in escopes if e["assertion"] == aid
                             for nm in e.get("nonScopeMentions") or []}
        # .get, not []: a scope entry pointing at a DELETED assertion must be reported by
        # the unknown-assertion check above, not raise and take the whole run's output with it
        undeclared = mentioned(assertion_text.get(aid, "")) - scope_union[aid] - declared_mentions
        check("R35", not undeclared,
              f"assertion {aid} names {sorted(undeclared)} without scoping them and without "
              f"declaring the mention; that is how A5 went on claiming the iOS probe pair")

    # the PARTITION — the check A5 and A18 were failing — run for every registered key
    for key in sorted({e["entitlementKey"] for e in escopes}):
        entries = [e for e in escopes if e["entitlementKey"] == key]
        authored_rows = {tk for tk, t in targets.items()
                         if t["entitlements"].get(key, {}).get("status") in authored_statuses}
        present, absent, exclusive = set(), set(), False
        for e in entries:
            if e["polarity"] == "absent":
                absent |= set(e["scopeTargets"])
            else:
                present |= set(e["scopeTargets"])
                exclusive = exclusive or e["polarity"] == "present-exclusive"
        check("R35", present == authored_rows,
              f"the present scopes for {key} cover {sorted(present)}, but the rows author it on "
              f"{sorted(authored_rows)}")
        check("R35", not (present & absent),
              f"{key} is claimed both present and absent on {sorted(present & absent)}; that is "
              f"the verdict-07 F1 defect exactly")
        covered = present | absent | (set(targets) if exclusive else set())
        check("R35", covered == set(targets),
              f"the scopes for {key} say nothing about {sorted(set(targets) - covered)}, so an "
              f"entitlement check has no instruction for those rows")

    # coverage, in both directions: naming a key without registering its scope must fail
    for a in m["verification"]["assertions"]:
        for key in sorted(declared_keys):
            if key in a["text"]:
                check("R35", any(e["assertion"] == a["id"] and e["entitlementKey"] == key
                                 for e in escopes),
                      f'assertion {a["id"]} names entitlement {key} but registers no scope for '
                      f"it, so its target scope would go unchecked")
    for e in escopes:
        check("R35", e["entitlementKey"] in assertion_text.get(e["assertion"], ""),
              f'{e["id"]} scopes {e["entitlementKey"]} against assertion {e["assertion"]}, '
              f"which no longer names that key")

    # R36 rule S2, profile half — reviewer verdict 07 F2. A9 said every development profile
    # carries this Mac while four of the eight rows declare their devices deferred under
    # ADR-024, so the one assertion was simultaneously right for macOS and wrong for iOS.
    marker = s2["deferredDeviceMarker"]
    basis = s2["deferralBasis"]
    pscopes = s2["profileScopes"]
    p_ids = [p["id"] for p in pscopes]
    check("R36", len(set(p_ids)) == len(p_ids), f"duplicate S2 profile scope ids: {p_ids}")

    def profiles_matching(predicates):
        out = set()
        for p in predicates:
            for tk in profiles:
                if all(targets[tk].get(f) == v for f, v in p.items()):
                    out.add(tk)
        return out

    def is_deferred(devices):
        return bool(devices) and all(marker in d and basis in d for d in devices)

    for ps in pscopes:
        pid = ps["id"]
        check("R36", re.match(r"^PS-\d+$", pid), f"S2 profile scope id {pid} is not PS-<n>")
        aid = ps.get("assertion")
        check("R36", aid in assertion_text, f"{pid} scopes unknown assertion {aid}")
        check("R36", ps.get("channel") in channels,
              f'{pid} channel {ps.get("channel")} is not a declared signing channel')
        binding = ps.get("deviceBinding")
        check("R36", binding in ("enumerated", "deferred", "all-devices"),
              f"{pid} deviceBinding {binding} is not enumerated, deferred, or all-devices")
        check("R36", (ps.get("derivation") or "").strip(),
              f"{pid} does not say how its scope is derived")
        preds = ps.get("classPredicates")
        check("R36", isinstance(preds, list) and preds, f"{pid} declares no classPredicates")
        derived = profiles_matching(preds or [])
        check("R36", sorted(ps.get("scopeProfiles") or []) == sorted(derived),
              f'{pid} scopeProfiles {sorted(ps.get("scopeProfiles") or [])} != the profile rows '
              f"its predicates select {sorted(derived)}")
        clause = ps.get("scopeClause") or ""
        check("R36", clause and clause in assertion_text.get(aid, ""),
              f"{pid} scopeClause is not present verbatim in assertion {aid}")
        for tk in sorted(derived):
            devices = (profiles[tk].get("development") or {}).get("devices") or []
            if binding == "enumerated":
                check("R36", devices and not is_deferred(devices),
                      f"{pid} claims a concrete device list for {tk}, but the row declares "
                      f"{devices}")
            elif binding == "deferred":
                check("R36", is_deferred(devices),
                      f"{pid} claims {tk}'s devices are deferred, but the row declares "
                      f"{devices}; a deferred entry must name both {marker!r} and {basis!r}")
            else:
                dist = profiles[tk].get("distribution") or {}
                check("R36", dist.get("channel") == ps["channel"],
                      f'{pid} scopes {tk} on channel {ps["channel"]}, but its distribution '
                      f'channel is {dist.get("channel")}')

    # the development-channel scopes must PARTITION the profile rows, the way A9 did not
    dev = [p for p in pscopes if p["channel"] == "development"]
    check("R36", dev, "no profile scope covers the development channel, the one A9 got wrong")
    dev_enumerated = {tk for p in dev if p["deviceBinding"] == "enumerated"
                      for tk in p["scopeProfiles"]}
    dev_deferred = {tk for p in dev if p["deviceBinding"] == "deferred"
                    for tk in p["scopeProfiles"]}
    check("R36", not (dev_enumerated & dev_deferred),
          f"development profiles {sorted(dev_enumerated & dev_deferred)} are scoped as both "
          f"concrete and deferred")
    check("R36", dev_enumerated | dev_deferred == set(profiles),
          f"the development profile scopes say nothing about "
          f"{sorted(set(profiles) - dev_enumerated - dev_deferred)}")
    # ...and each half must equal what the profile rows actually declare
    rows_deferred = {tk for tk, p in profiles.items()
                     if is_deferred((p.get("development") or {}).get("devices") or [])}
    check("R36", dev_deferred == rows_deferred,
          f"the deferred profile scope covers {sorted(dev_deferred)}, but the rows defer "
          f"{sorted(rows_deferred)}")
    check("R36", dev_enumerated == set(profiles) - rows_deferred,
          f"the concrete profile scope covers {sorted(dev_enumerated)}, but the rows declare a "
          f"device set for {sorted(set(profiles) - rows_deferred)}")
    # the tie that keeps A9a and the C1 scope from drifting apart
    c1_profiles = {tk for tk, p in profiles.items()
                   if (p.get("development") or {}).get("c1Authorized")}
    check("R36", dev_enumerated == c1_profiles,
          f"the concrete development profiles {sorted(dev_enumerated)} are not the profiles "
          f"Ceremony C1 authorizes {sorted(c1_profiles)}")
    # a profile-device claim that registers no scope is the verdict-07 F2 shape
    for a in m["verification"]["assertions"]:
        if "ProvisionedDevices" in a["text"] or "ProvisionsAllDevices" in a["text"]:
            check("R36", any(p["assertion"] == a["id"] for p in pscopes),
                  f'assertion {a["id"]} makes a profile-device claim but registers no scope, so '
                  f"nothing checks which profiles it reaches")

    # R33 the rationale document renders the same grant clauses. Without this the JSON can
    # be corrected and the prose artifact left asserting the superseded contract — the same
    # defect one file over.
    check("R33", RATIONALE is not None,
          f"{RATIONALE_BASENAME} is not next to this contract, so the rendered grant clauses "
          f"cannot be checked against the rationale document")
    if RATIONALE is not None:
        # the document hard-wraps at ~80 columns, so compare on whitespace-normalised text:
        # a clause may be broken across lines, it may not be reworded.
        doc = re.sub(r"\s+", " ", RATIONALE.read_text())
        check("R33", m["revision"] in doc,
              f'the rationale document does not carry revision {m["revision"]}')
        for r in rules:
            clause = r.get("grantClause")
            if clause:
                check("R33", re.sub(r"\s+", " ", clause) in doc,
                      f'{r["id"]} grant clause is not rendered in the rationale document, so the '
                      f"prose and the contract can state different grants")

        # r8: the same treatment for every assertion SCOPE. R33 rendered grant clauses only,
        # which is why the document's own assertion table could go on saying the macOS host
        # holds a keychain group r5 removed — the verdict-05 F1 defect, one file over and one
        # revision later. See rule S2's staleClaimsFound.
        for e in escopes:
            check("R35", re.sub(r"\s+", " ", e["scopeClause"]) in doc,
                  f'{e["id"]} scope clause for assertion {e["assertion"]} is not rendered in '
                  f"the rationale document, so the prose can state a different scope than the "
                  f"contract")
        for ps in pscopes:
            check("R36", re.sub(r"\s+", " ", ps["scopeClause"]) in doc,
                  f'{ps["id"]} scope clause for assertion {ps["assertion"]} is not rendered in '
                  f"the rationale document, so the prose can state a different scope than the "
                  f"contract")

    # ---- r9 gates -------------------------------------------------------
    # R37 rule D1 — the declared-consumer pin is well formed and COMPLETE. This validator
    # cannot read the board, so reachability itself is check-portal-consumer.py's D1 block;
    # R37 checks the half that lives in the contract, which is the half that went wrong:
    # four obligation owners were assigned from inside prose fields and never reached the
    # consumers list at all.
    d1 = m["consumerDependencyContract"]
    check("R37", d1["id"] == "D1", f'consumerDependencyContract id {d1["id"]} != D1')
    for field in ("statement", "history", "mentionCoverageRule", "reachabilityRule",
                  "whyNotAStatusCheck", "selfReference", "gate", "source",
                  "whyBlockersAreNotNamed"):
        check("R37", (d1.get(field) or "").strip(), f"rule D1 has no {field}")
    check("R37", d1["selfReference"] == m["owner"],
          f'rule D1 selfReference {d1["selfReference"]} is not this contract\'s owner '
          f'{m["owner"]}')

    consumer_ids = []
    for entry in m["consumers"]:
        for eid in ELEMENT_ID.findall(entry):
            if eid not in consumer_ids:
                consumer_ids.append(eid)
    check("R37", consumer_ids, "the consumers list names no element ids")
    check("R37", len(consumer_ids) == len(set(consumer_ids)),
          "an element id is declared as a consumer more than once")

    exemptions = d1["exemptions"]
    allowed_bases = d1["exemptionBasisAllowed"]
    check("R37", allowed_bases == ["upstream"],
          f"rule D1 allows exemption bases {allowed_bases}; only 'upstream' is a basis, "
          f"because `done` is evidence a consumer RAN, which is the failure D1 catches")
    for e in exemptions:
        check("R37", e["basis"] in allowed_bases,
              f'exemption {e["element"]} claims basis {e["basis"]!r}, which is not allowed')
        for field in ("reason", "boardFact"):
            check("R37", (e.get(field) or "").strip(),
                  f'exemption {e["element"]} has no {field}')

    # The mention set and the declared set agree in BOTH directions. The second direction
    # must read mentions from EVERYWHERE ELSE, not from everywhere: the consumers list is
    # itself a string in the contract, so counting it made "declared but explained nowhere"
    # unfailable. An r9 negative gate appended a consumer id that appears nowhere else and
    # the check passed; that tautology is why `elsewhere` exists.
    all_mentions = {eid for _, text in walk_strings(m) for eid in ELEMENT_ID.findall(text)}
    elsewhere = {eid for path, text in walk_strings(m)
                 if not path.startswith(("consumers", "consumerDependencyContract"))
                 for eid in ELEMENT_ID.findall(text)}
    declared = set(consumer_ids) | {e["element"] for e in exemptions} | {m["owner"]}
    check("R37", not (all_mentions - declared),
          f"named in this contract but neither a declared consumer nor an exemption: "
          f"{sorted(all_mentions - declared)}")
    check("R37", not (declared - elsewhere - {m["owner"]}),
          f"declared as a consumer but named nowhere outside the consumer list and rule D1's "
          f"own register, so nothing says what it consumes: "
          f"{sorted(declared - elsewhere - {m['owner']})}")

    # the three reachability gaps must stay recorded: a fix with no record reads as a
    # contract that was always right, and the next revision re-derives the same hole.
    check("R37", len(d1["staleClaimsFound"]) >= 7,
          "rule D1 records fewer than the seven defects r9 found")
    for eid in ("TASK-260715-1o9wjz", "TASK-260715-3f4lxy", "TASK-260715-29ws8l"):
        check("R37", any(eid in s and "REACHABILITY" in s for s in d1["staleClaimsFound"]),
              f"rule D1 no longer records that {eid} had no dependency path to this task")
    board_change = d1["boardChange"]
    check("R37", board_change["revision"] == m["revision"] or
          any(e["revision"] == board_change["revision"] for e in m["revisionLog"]),
          f'rule D1 boardChange names revision {board_change["revision"]}, which is not a '
          f"revision of this contract")
    check("R37", sorted(board_change["closes"]) ==
          sorted(["TASK-260715-1o9wjz", "TASK-260715-3f4lxy", "TASK-260715-29ws8l"]),
          "rule D1 boardChange no longer closes exactly the three reachability gaps")
    for field in ("edge", "why", "cycleCheck", "footprint"):
        check("R37", (board_change.get(field) or "").strip(),
              f"rule D1 boardChange has no {field}")
    check("R37", "check-portal-consumer.py" in d1["gate"],
          "rule D1 does not name the gate that reads the board")
    for query in d1["boardGate"]["graphQueries"]:
        check("R37", "blockedBy" in query,
              f"rule D1 graph query {query!r} does not read blockedBy")
    check("R37", any("type=bug" in q for q in d1["boardGate"]["graphQueries"]),
          "rule D1 reads only tasks; a bug can carry an edge, so a closure over that "
          "subgraph is wrong in both directions")

    # R38 rule N1 — a count is DERIVED. r6 built a count scan for App Group record counts
    # and stopped there; the allowlist-size class went stale at r3, was hand-corrected at
    # r4 and moved again at r5, in both artifacts, with no gate.
    n1 = m["numericClaimContract"]
    check("R38", n1["id"] == "N1", f'numericClaimContract id {n1["id"]} != N1')
    for field in ("statement", "history", "derivation", "spelling", "relationToS1",
                  "gate", "source"):
        check("R38", (n1.get(field) or "").strip(), f"rule N1 has no {field}")
    check("R38", n1["gate"] == "R38", f'rule N1 names gate {n1["gate"]}, not R38')

    scan = n1["coverageScan"]
    check("R38", (scan.get("knownBound") or "").strip(),
          "rule N1's coverage scan states no bound, so it reads as a completeness claim")

    # r11, verdict 09 rework 4. The scan's SHAPES are declared here and compiled by this
    # gate, and the two must be the same pattern. r9 declared one shape whose spelling had
    # already diverged from the compiled one — harmless in that instance, but a declaration
    # nothing checks is how a shape gets quietly narrowed while the gate goes on passing.
    shapes = {s["id"]: s for s in scan["shapes"]}
    check("R38", set(shapes) == set(COUNT_SHAPES),
          f"rule N1 declares shapes {sorted(shapes)} but the gate scans for "
          f"{sorted(COUNT_SHAPES)}; a shape the gate does not run is documentation, and a "
          f"shape the rule does not declare is unreviewed")
    for sid, compiled in sorted(COUNT_SHAPES.items()):
        declared = (shapes.get(sid) or {}).get("regex", "")
        check("R38",
              declared.replace(NUMBER_WORD_PLACEHOLDER, NUMBER_WORD_ALTERNATION)
              == compiled.pattern,
              f"rule N1's declared {sid} shape is not the pattern the gate compiles; the "
              f"declaration would let a reader believe a narrower or wider scan runs")
        for field in ("what", "derivation"):
            check("R38", ((shapes.get(sid) or {}).get(field) or "").strip(),
                  f"rule N1 shape {sid} has no {field}")
    check("R38", (scan.get("shapeSourceOfTruth") or "").strip(),
          "rule N1 does not say which of the declared and compiled shapes is authoritative")
    check("R38", "shape" not in scan,
          "rule N1 still carries the singular `shape` field alongside `shapes`; two "
          "declarations of one thing is how they drift apart")

    # The exclusion lists are PINNED, because widening an exclusion is the quiet way to
    # neuter a scan: the gate goes on passing while it stops looking. §13 is excluded
    # because it is history; nothing else may join it without a reviewed change to this
    # rule. r11 removed the preamble from this list — see preambleScanRule.
    check("R38", scan["excludedDocSections"] == ["13"],
          f'rule N1 excludes document sections {scan["excludedDocSections"]}; only §13 is '
          f"history, and widening this list disables the scan rather than the section")
    check("R38", "excludedDocPreamble" not in scan,
          "rule N1 still excludes the rationale preamble; the current revision's summary "
          "block is a live claim about the contract as it stands, and excluding it "
          "wholesale is why the verdict-09 stale count was invisible")
    check("R38", (scan.get("preambleScanRule") or "").strip(),
          "rule N1 does not say why the preamble is scanned, so a later revision would "
          "read the removed exclusion as an oversight and restore it")

    # r11: a mutation count is derived from the harness, in both directions. Neither half
    # alone is enough — the harness check would let the prose go stale, and the prose check
    # would let the harness silently shrink underneath a number nobody re-derived.
    # `.get`, not `[...]`: a deleted register must be a REPORTED failure naming this rule,
    # not a traceback. A gate that crashes is a gate whose verdict nobody can read — the
    # same reason r9's R35 mention scan was fixed to fail closed rather than raise.
    hc = n1.get("harnessCounts") or {}
    check("R38", hc, "rule N1 carries no harnessCounts register, so a mutation count goes "
                     "back to being a number written by hand in a document")
    for field in ("statement", "why", "derivedBy", "scope"):
        check("R38", (hc.get(field) or "").strip(), f"rule N1's harnessCounts has no {field}")
    check("R38", "mutate.py" in (hc.get("derivedBy") or ""),
          "rule N1 does not name the harness that recomputes its declared counts, so the "
          "numbers are hand-written again with an extra step")
    check("R38", hc.get("declaredCounts"),
          "rule N1 declares no harness counts, so the rendered claims below have nothing "
          "to render")
    for rule_id, count in sorted((hc.get("declaredCounts") or {}).items()):
        check("R38", re.fullmatch(r"R\d+", rule_id),
              f"rule N1 declares a harness count for {rule_id!r}, which is not a gate id")
        check("R38", isinstance(count, int) and count > 0,
              f"rule N1 declares harness count {count!r} for {rule_id}, which is not a "
              f"positive number of mutations")
    for prefix in scan["excludedJsonPathPrefixes"]:
        check("R38",
              prefix.endswith(("history", "staleClaimsFound")) or prefix == "revisionLog"
              or prefix.startswith("numericClaimContract."),
              f"rule N1 excludes the contract path {prefix!r} from its scan, which is "
              f"neither append-only history nor this rule's own register; an exclusion "
              f"that broad stops the scan seeing live claims")

    # a count may not be owned twice with two derivations
    s1_count_paths = set(m["crossPlatformSharingContract"]["recordCountClaimPaths"])
    n1_paths = {c.get("path") for c in n1["claims"] if c.get("path")}
    check("R38", not (s1_count_paths & n1_paths),
          f"rules S1 and N1 both own the count at {sorted(s1_count_paths & n1_paths)}")

    doc_norm = norm(RATIONALE.read_text()) if RATIONALE is not None else ""
    check("R38", RATIONALE is not None,
          f"{RATIONALE_BASENAME} is not next to this contract, so the rendered counts "
          f"cannot be checked against the rationale document")

    claim_ids = [c["id"] for c in n1["claims"]]
    check("R38", len(claim_ids) == len(set(claim_ids)), f"duplicate N1 claim ids: {claim_ids}")
    rendered_by_path = {}
    for claim in n1["claims"]:
        check("R38", claim["artifact"] in ("json", "rationale"),
              f'N1 claim {claim["id"]} names unknown artifact {claim["artifact"]!r}')
        walk_path = None
        if claim["artifact"] == "json":
            text, walk_path = resolve_claim_path(m, claim["path"])
            check("R38", text is not None,
                  f'N1 claim {claim["id"]} path {claim["path"]} resolves to nothing')
            text = norm(text or "")
        else:
            text = doc_norm
        for rendered in claim["renderedClaims"]:
            want = norm(rendered_count_claim(m, claim, rendered))
            check("R38", want in text,
                  f'N1 claim {claim["id"]} ({claim["artifact"]}): the derived text '
                  f'{want!r} is not present, so the prose count disagrees with the rows')
            rendered_by_path.setdefault(walk_path, []).append(want)

        # the rendered key LIST, not only its size — this is the check that would have
        # caught the r3 defect at the time, where the number and the list disagreed.
        if "keyList" in claim:
            authored, injected = derive_allowlist(m, claim["target"], claim["keyList"]["channel"])
            want_keys = authored | injected
            anchor = norm(rendered_count_claim(m, claim, claim["renderedClaims"][0]))
            after = doc_norm.split(anchor, 1)[-1]
            fence = claim["keyList"]["openFence"]
            block = after.split(fence, 2)[1] if after.count(fence) >= 2 else ""
            found = set(re.findall(r"\b(?:com\.apple\.[\w.-]+|application-identifier|"
                                   r"get-task-allow|keychain-access-groups)\b", block))
            check("R38", found == want_keys,
                  f'N1 claim {claim["id"]} key list does not equal the derived allowlist; '
                  f"rendered-only {sorted(found - want_keys)}, missing "
                  f"{sorted(want_keys - found)}")

    # coverage: no unregistered count claim, in either artifact, in either shape
    def first_count_hit(text):
        for sid, compiled in COUNT_SHAPES.items():
            found = compiled.search(text)
            if found:
                return sid, found.group(0)
        return None, None

    excluded_prefixes = tuple(scan["excludedJsonPathPrefixes"])
    for path, text in walk_strings(m):
        if path.startswith(excluded_prefixes):
            continue
        stripped = norm(text)
        for want in rendered_by_path.get(path, []):
            stripped = stripped.replace(want, " ")
        sid, hit = first_count_hit(stripped)
        check("R38", hit is None,
              f"unregistered {sid} claim in the contract at {path}: {hit!r} — "
              f"register it under rule N1 or it is a number nothing checks"
              if hit else "")

    excluded_phrases = [norm(p["phrase"]) for p in scan["excludedPhrases"]]
    for phrase in excluded_phrases:
        check("R38", phrase in doc_norm,
              f"rule N1 excludes the phrase {phrase!r}, which is not in the rationale "
              f"document; a vestigial exclusion hides whatever replaced it")
    all_rendered = [w for group in rendered_by_path.values() for w in group]
    all_rendered += [norm(rendered_count_claim(m, c, r))
                     for c in n1["claims"] if c["artifact"] == "rationale"
                     for r in c["renderedClaims"]]
    if RATIONALE is not None:
        for name, body in doc_blocks(RATIONALE.read_text()):
            # r11: 'preamble' is no longer in this test. §13 remains excluded.
            if name in scan["excludedDocSections"]:
                continue
            stripped = norm(body)
            for want in all_rendered + excluded_phrases:
                stripped = stripped.replace(want, " ")
            sid, hit = first_count_hit(stripped)
            check("R38", hit is None,
                  f"unregistered {sid} claim in the rationale document, section {name}: "
                  f"{hit!r} — register it under rule N1 or exclude it with a "
                  f"reason" if hit else "")

    # ---- r10 gates ------------------------------------------------------
    # R39 rule K3 — the OS-version scope of the provider's keychain decision. Reviewer
    # verdict 08 F1: r4 settled `macos.provider` with no keychain row and no file exception
    # because application.sb grants /Library/Keychains to NE processes — read on macOS 26.5,
    # while the binding floor is macOS 15.0. The decision was right for the OS it was taken
    # on and silent about every other one. This gate holds three things together: the scope
    # is stated, the gap has an owner, and the exception a missing floor grant would require
    # is ALREADY reviewed, so it cannot be rejected as drift the day the evidence arrives.
    k3 = m["keychainSandboxFloorRule"]
    check("R39", k3["id"] == "K3", f'keychainSandboxFloorRule id {k3["id"]} != K3')
    for field in ("statement", "verifiedOn", "unverifiedAtFloor", "whyItMatters",
                  "resolutionOwner", "runtimeConsumer", "ifGrantAbsentAtFloor",
                  "ifGrantPresentAtFloor", "notAPortalCapability",
                  "productEvidenceIsNotProof", "source"):
        check("R39", (k3.get(field) or "").strip(), f"rule K3 has no {field}")

    # The two version numbers are the whole point of the rule: one is where the grant was
    # read, the other is where it must hold and has not been read. If they collapse to the
    # same value the rule stops saying anything.
    floor = "macOS 15.0"
    verified_os = "macOS 26.5"
    check("R39", verified_os in k3["verifiedOn"],
          f"rule K3 does not name {verified_os} as the version its evidence was read on")
    check("R39", floor in k3["unverifiedAtFloor"],
          f"rule K3 does not name the {floor} deployment floor its evidence does not cover")
    check("R39", verified_os not in k3["unverifiedAtFloor"],
          "rule K3 claims the floor is covered by the version it was actually read on, which "
          "is the verdict-08 F1 conflation exactly")
    check("R39", "application.sb" in k3["verifiedOn"] and "/Library/Keychains" in k3["verifiedOn"],
          "rule K3 does not cite the profile and path its conclusion rests on")
    check("R39", "verdict 08" in k3["whyItMatters"] or "verdict 08" in k3["source"],
          "rule K3 does not record the verdict that raised it")

    # An unresolved constraint with no owner is the failure mode OC-1 already demonstrated.
    k3_owner = ELEMENT_ID.search(k3["resolutionOwner"])
    check("R39", k3_owner is not None,
          "rule K3 states no resolution owner element, so the floor gap belongs to nobody")
    k3_owner = k3_owner.group(0) if k3_owner else None
    check("R39", ELEMENT_ID.search(k3["runtimeConsumer"]) is not None,
          "rule K3 names no runtime consumer, so an absent grant would surface only as a "
          "build finding and never at the place it actually fails")

    # Arming must be pre-authorized and evidence-bound, and must cost the ceremony nothing.
    check("R39", k3.get("ceremonyC1Impact") == "none",
          f'rule K3 claims Ceremony C1 impact {k3.get("ceremonyC1Impact")!r}; a temporary '
          f"file exception has no portal record, so arming it cannot move the ceremony")
    check("R39", "PRE-AUTHORIZED" in k3["ifGrantAbsentAtFloor"],
          "rule K3 does not pre-authorize the exception, so an absent floor grant would "
          "still be an unreviewed relaxation under rule X1 — the defect unchanged")

    conditional = x1.get("conditionalExceptions") or []
    conditional_ids = [c for c in conditional if c.get("id")]

    # The row states the same scope the rule does, and says what happens if the floor differs.
    prov_kc_scope = targets["macos.provider"]["entitlements"][KEYCHAIN_KEY].get("osVersionScope")
    check("R39", prov_kc_scope is not None,
          "the settled macos.provider keychain row states no OS-version scope, so its "
          "sandbox-grant reasoning reads as version-independent")
    if prov_kc_scope:
        check("R39", prov_kc_scope.get("rule") == "K3",
              "the macos.provider keychain row's version scope is not governed by rule K3")
        check("R39", verified_os in (prov_kc_scope.get("verifiedOn") or ""),
              f"the row's version scope does not name {verified_os}")
        check("R39", floor in (prov_kc_scope.get("unverifiedAtFloor") or ""),
              f"the row's version scope does not name the {floor} floor")
        check("R39", prov_kc_scope.get("resolutionOwner") == k3_owner,
              f'the row version scope owner {prov_kc_scope.get("resolutionOwner")} is not '
              f"rule K3's owner {k3_owner}")
        # An absent floor grant argues for a FILE exception. Re-granting the access group
        # would be the reasoning rule K1 exists to refute, arriving through the back door —
        # so the instruction must name the conditional entry and, if it mentions the access
        # group at all, must mention it under an explicit prohibition.
        if_absent = prov_kc_scope.get("ifAbsentAtFloor") or ""
        check("R39", any(c["id"] in if_absent for c in conditional_ids),
              "the row's floor instruction does not name the conditional register entry it "
              "arms, so the floor case has a rule but no mechanism")
        check("R39", KEYCHAIN_KEY not in if_absent or re.search(
                  r"do NOT re-grant|never by re-granting", if_absent),
              "the row's floor instruction mentions the access group without forbidding a "
              "re-grant; an absent sandbox grant argues for a file exception, never for the "
              "row rule K1 deleted")
    reopens = targets["macos.provider"]["entitlements"][KEYCHAIN_KEY].get("reopensOnly") or ""
    check("R39", "K3" in reopens,
          "the macos.provider keychain reopening condition does not mention rule K3, so the "
          "floor case reads as covered by a condition that excludes it")

    # ---- the conditional register ---------------------------------------
    check("R39", conditional, "rule X1 carries no conditional register, so a floor-required "
                              "exception has nowhere to be reviewed before it is needed")
    check("R39", (x1.get("conditionalExceptionPolicy") or "").strip(),
          "rule X1 has no conditionalExceptionPolicy, so nothing says what a conditional "
          "entry means or how it is armed")
    for c in conditional or []:
        cid = c.get("id")
        check("R39", cid, "a conditional exception entry has no id")
        for field in ("key", "target", "reason", "armingCondition", "armedBy",
                      "reviewedIn", "scopeIfArmed", "governedBy"):
            check("R39", (c.get(field) or "") if isinstance(c.get(field), str) else c.get(field),
                  f"conditional exception {cid} has no {field}")
        check("R39", c.get("armed") is False,
              f"conditional exception {cid} is armed in the contract; arming is an amendment "
              f"under section 11 carrying the owner's floor evidence, not a field edit")
        check("R39", c.get("portalCapability") is False,
              f"conditional exception {cid} claims a portal capability; a temporary exception "
              f"has no App ID record")
        check("R39", c["target"] in targets,
              f"conditional exception {cid} targets unknown row {c['target']}")
        check("R39", c["key"].startswith(TEMP_EXCEPTION_PREFIX),
              f"conditional exception {cid} registers {c['key']}, which is not a temporary "
              f"exception; the conditional register is not a general escape hatch")
        check("R39", c["governedBy"] == "K3",
              f"conditional exception {cid} is governed by {c['governedBy']}, not rule K3")
        check("R39", ELEMENT_ID.search(c["armedBy"] or "") is not None,
              f"conditional exception {cid} names no element that can arm it")
        # The arming condition is the whole safety property. If it is loose enough that a
        # shipping third-party bundle satisfies it, the entry arms itself on exactly the
        # reasoning rule K1 exists to refute — so it must say what does NOT arm it, and
        # must be bound to the base-profile observation rather than to a vague symptom.
        arming = c["armingCondition"]
        check("R39", "Nothing else arms it" in arming,
              f"conditional exception {cid} states no exclusion clause, so any evidence "
              f"loosely about keychains would arm it; rule K1 already ruled a key in a "
              f"shipping bundle out as evidence and this is the same argument")
        check("R39", "App Sandbox profile" in arming and "not" in arming.lower(),
              f"conditional exception {cid} does not bind arming to the ABSENCE of the base "
              f"App Sandbox grant, which is the only observation that makes it necessary")
        check("R39", c.get("valuesIfArmed"),
              f"conditional exception {cid} declares no values, so arming it would grant an "
              f"unbounded path exception")
        for ch in c.get("channelsIfArmed") or []:
            check("R39", ch in targets[c["target"]]["channels"],
                  f"conditional exception {cid} names channel {ch}, which {c['target']} does "
                  f"not sign on")
        # The row and the register must agree, the same way rule R26 makes the ACTIVE
        # register agree with the rows it mirrors.
        row = targets[c["target"]]["entitlements"].get(c["key"])
        check("R39", row is not None,
              f"conditional exception {cid} has no row on {c['target']}, so the generated "
              f"target has nothing to read")
        if row:
            check("R39", row["status"] not in authored_statuses,
                  f"conditional exception {cid} is unarmed but its row is authored with status "
                  f'{row["status"]}; an unarmed entry may not enter any allowlist')
            check("R39", row["status"] in non_authored_statuses,
                  f'conditional exception {cid} row status {row["status"]} is not a declared '
                  f"non-authored status")
            check("R39", row.get("valuesIfArmed") == c["valuesIfArmed"],
                  f"conditional exception {cid} values disagree with the row")
            check("R39", row.get("channelsIfArmed") == c.get("channelsIfArmed"),
                  f"conditional exception {cid} channels disagree with the row")
            check("R39", row.get("portalCapability") is False,
                  f"conditional exception {cid} row claims a portal capability")
        # Disjoint from the ACTIVE register, in both directions. An entry in both would be
        # simultaneously granted and pending, and rule R26's equality would start passing
        # for the wrong reason.
        check("R39", (c["key"], c["target"]) not in registered,
              f"conditional exception {cid} is also in the ACTIVE reviewedExceptions register; "
              f"an exception is either granted or pending, never both")

    # ---- r11: the register is DERIVED, not mirrored ---------------------
    # Verdict 09 F1. Every check above this line establishes that the register entry and
    # its copy on the target row agree. That is a consistency check, not a review: the
    # reviewer moved BOTH copies of three fields — the path to "/", the channel set down to
    # development, the arming owner to an unrelated task — and r10 exited 0 on all three.
    # What makes X1-C1 pre-authorized is that this contract reviewed ONE exact exception,
    # so a field that can move without failing a gate is not the field that was reviewed.
    # Each field below now bottoms out on something a coordinated edit cannot restate: a
    # semantic bound on the value, a set another rule owns, or the live board.
    deriv = x1.get("conditionalExceptionDerivation") or {}
    check("R39", deriv,
          "rule X1 states no derivation contract for its conditional register, so every "
          "field is established only by agreeing with its own mirror on the target row — "
          "the verdict-09 F1 defect exactly")
    for field in ("statement", "why", "principle", "appliesTo", "registerShape", "source"):
        check("R39", (deriv.get(field) or "").strip(),
              f"conditionalExceptionDerivation has no {field}")
    check("R39", deriv.get("gate") == "R39",
          f'the derivation contract names gate {deriv.get("gate")!r}, not R39')

    spec = {f["field"]: f for f in deriv.get("fields") or []}
    DERIVED_FIELDS = {"target", "key", "valuesIfArmed", "channelsIfArmed", "armedBy",
                      "governedBy", "reviewedIn", "scopeIfArmed"}
    check("R39", set(spec) == DERIVED_FIELDS,
          f"the derivation contract covers {sorted(spec)}; every field of a conditional "
          f"entry needs a derivation, and the set is {sorted(DERIVED_FIELDS)} — an "
          f"uncovered field is one nothing constrains")
    # The bound vocabulary is PINNED here, in the gate, because these are the bounds this
    # gate implements. A derivation declaring a bound the gate does not implement is a
    # promise nothing keeps — and "agrees with the target row", however it is spelled, is
    # exactly the check verdict 09 rejected.
    # r12: "known-revision" is REMOVED rather than merely superseded. It is the bound
    # verdict 10 rejected, and a vocabulary that still accepts it lets the closed defect
    # re-enter as a declaration the gate endorses.
    ALLOWED_BOUND_KINDS = {
        "derived-unique-row", "literal-and-cross-checked", "path-subtree",
        "equals-target-channels", "equals-rule-owner-and-declared-consumer",
        "literal", "derived-introducing-revision", "rendered-clause",
    }
    for name, field_spec in sorted(spec.items()):
        for required in ("boundKind", "derivedFrom", "whyNotACopy"):
            check("R39", (field_spec.get(required) or "").strip(),
                  f"derivation of {name} has no {required}")
        check("R39", field_spec.get("boundKind") in ALLOWED_BOUND_KINDS,
              f'the derivation of {name} declares bound {field_spec.get("boundKind")!r}, '
              f"which this gate does not implement; the implemented set is "
              f"{sorted(ALLOWED_BOUND_KINDS)}")

    # The reviewed path lives in the GATE. A bound that lives only inside the data it
    # bounds is not a bound.
    path_spec = spec.get("valuesIfArmed") or {}
    check("R39", path_spec.get("reviewedPath") == FLOOR_EXCEPTION_PATH,
          f'the derivation declares reviewed path {path_spec.get("reviewedPath")!r}, but '
          f"this gate reviewed {FLOOR_EXCEPTION_PATH!r}; widening the declaration alone "
          f"grants more filesystem access than was reviewed")
    check("R39", path_spec.get("maxValues") == 1,
          f'the derivation permits {path_spec.get("maxValues")!r} values; the reviewed '
          f"exception is one path, and a second value is a second review")
    check("R39", "/" in (path_spec.get("bannedValues") or []),
          "the derivation does not ban the filesystem root outright")

    # r12, verdict 10 F1: the provenance rule itself. Reported under R39 because that is
    # where the verdict required the conditional control to land; the per-entry derivations
    # are reported above under whichever register owns the entry.
    for failure in provenance_structural:
        check("R39", False, f"X1-P: {failure}")
    prov = x1.get("exceptionReviewProvenance") or {}
    check("R39", (prov.get("gates") or {}).get("conditionalExceptions") == "R39",
          "rule X1-P does not name R39 as the gate for the conditional register, so the "
          "control verdict 10 supplied would be reported under a rule nobody looks up")
    check("R39", (prov.get("gates") or {}).get("reviewedExceptions") == "R26",
          "rule X1-P does not name R26 as the gate for the active register")
    reviewed_spec = spec.get("reviewedIn") or {}
    check("R39", reviewed_spec.get("boundKind") == "derived-introducing-revision",
          f'the derivation of reviewedIn declares bound '
          f'{reviewed_spec.get("boundKind")!r}; verdict 10 rejected a bound that accepts '
          f"every issued revision, and the field must derive the revision that introduced "
          f"the entry")
    check("R39", "exceptionReviewProvenance" in (reviewed_spec.get("derivedFrom") or "")
          or "X1-P" in (reviewed_spec.get("derivedFrom") or ""),
          "the derivation of reviewedIn does not point at rule X1-P, so the prose and the "
          "gate would describe different bounds — the defect verdict 10's rework item 3 "
          "names")
    check("R39", (reviewed_spec.get("supersededBound") or "").strip(),
          "the derivation of reviewedIn does not record the bound r11 used and r12 rejected, "
          "so a reader who finds known-revision in a diff cannot tell it was refused")

    known_revisions = {m["revision"]} | {e["revision"] for e in m["revisionLog"]}
    declared_consumers = {i for entry in m["consumers"] for i in ELEMENT_ID.findall(entry)}
    seen_ids, seen_rows = set(), set()
    for c in conditional or []:
        cid = c.get("id")
        check("R39", cid not in seen_ids, f"duplicate conditional entry id {cid}")
        seen_ids.add(cid)
        check("R39", (c.get("target"), c.get("key")) not in seen_rows,
              f"conditional entry {cid} is the second entry on the same row; a second "
              f"entry can shadow the reviewed one on exactly the field under review")
        seen_rows.add((c.get("target"), c.get("key")))

        # target — the unique row carrying the version scope this entry answers. Not a
        # copy: R39's settled-row checks above fail closed if that scope block is missing
        # from macos.provider, so the entry cannot be relocated without breaking them first.
        scoped_rows = [t["key"] for t in m["targets"]
                       for row in t["entitlements"].values()
                       if (row.get("osVersionScope") or {}).get("rule") == c.get("governedBy")]
        check("R39", len(scoped_rows) == 1,
              f"conditional entry {cid} is governed by {c.get('governedBy')}, whose version "
              f"scope appears on {len(scoped_rows)} rows; the entry's target is derived from "
              f"that row and cannot be derived from none or from several")
        if len(scoped_rows) == 1:
            check("R39", c["target"] == scoped_rows[0],
                  f"conditional entry {cid} targets {c['target']}, but the {c['governedBy']} "
                  f"version scope it answers is on {scoped_rows[0]}; a coordinated move of "
                  f"the entry and its row would otherwise pre-authorize an exception on a "
                  f"target nobody reviewed")

        # key — pinned, and cross-checked against the rule that authorises arming, so
        # drifting it means drifting a sentence a reader sees.
        check("R39", c["key"] == TEMP_FILE_KEY,
              f"conditional entry {cid} registers {c['key']}; the reviewed exception is the "
              f"read-write absolute-path form, because the base grant it replaces is "
              f"file-read* AND file-write*")
        check("R39", c["key"] in k3["ifGrantAbsentAtFloor"],
              f"rule K3's arming instruction does not name {c['key']}, so the rule and the "
              f"register authorise different exceptions")

        # valuesIfArmed — a SEMANTIC bound. Widening fails however many copies agree.
        values = c.get("valuesIfArmed") or []
        check("R39", len(values) == path_spec.get("maxValues"),
              f"conditional entry {cid} declares {len(values)} values; the reviewed "
              f"exception is one path")
        for value in values:
            check("R39", value not in (path_spec.get("bannedValues") or []),
                  f"conditional entry {cid} declares banned path {value!r}")
            check("R39", value.startswith(FLOOR_EXCEPTION_PATH),
                  f"conditional entry {cid} declares path {value!r}, which is outside the "
                  f"reviewed subtree {FLOOR_EXCEPTION_PATH!r}")
            check("R39", not (FLOOR_EXCEPTION_PATH.startswith(value)
                              and value != FLOOR_EXCEPTION_PATH),
                  f"conditional entry {cid} declares path {value!r}, an ANCESTOR of the "
                  f"reviewed path — arming it would grant more of the filesystem than the "
                  f"review covers")
        check("R39", FLOOR_EXCEPTION_PATH.rstrip("/") in k3["ifGrantAbsentAtFloor"],
              "rule K3's arming instruction does not name the reviewed path, so the rule "
              "would authorise whatever the register happened to say")

        # channelsIfArmed — the target's OWN channel set, in full. A base sandbox profile
        # does not vary by signing channel, so a subset leaves one channel broken on the
        # same OS; dropping developer-id would break the shipping provider while the
        # development lane looked fine.
        target_channels = targets[c["target"]]["channels"] if c["target"] in targets else []
        check("R39", (c.get("channelsIfArmed") or []) == target_channels,
              f'conditional entry {cid} arms on {c.get("channelsIfArmed")} while '
              f"{c['target']} signs on {target_channels}; the floor question is about the "
              f"base OS profile, which is the same on every channel")

        # armedBy — the governing rule's own resolution owner, cross-checked against the
        # declared consumers, which rule D1 requires to exist on the live board. Verdict
        # 09's third mutation moved this to a REAL consumer, which is why a shape check on
        # the element id could not see it.
        rule_owner = ELEMENT_ID.search(k3["resolutionOwner"])
        rule_owner = rule_owner.group(0) if rule_owner else None
        check("R39", c.get("armedBy") == rule_owner,
              f'conditional entry {cid} is armed by {c.get("armedBy")}, but rule '
              f"{c['governedBy']}'s resolution owner is {rule_owner}; a different arming "
              f"owner severs the evidence chain from the task that produces the evidence")
        check("R39", c.get("armedBy") in declared_consumers,
              f'conditional entry {cid} is armed by {c.get("armedBy")}, which is not a '
              f"declared consumer, so rule D1 never checks that it exists on the board or "
              f"runs after this contract")

        # reviewedIn — the claim that makes the entry pre-authorized rather than merely
        # written down. r11 bounded it to membership in the issued revision set and RECORDED
        # that it could not tell WHICH revision reviewed an entry; verdict 10 F1 then moved
        # X1-C1 from r10 to r2 and the validator exited 0. r12 derives it from the
        # digest-pinned snapshot chain — files outside this contract, which a coordinated
        # edit of the contract cannot reach.
        check("R39", c.get("reviewedIn") in known_revisions,
              f'conditional entry {cid} claims review in revision {c.get("reviewedIn")!r}, '
              f"which this contract has never issued")
        derived = provenance.get(cid) or {}
        check("R39", derived.get("register") == "conditionalExceptions",
              f"conditional entry {cid} has no provenance entry under rule X1-P, so its "
              f"reviewedIn is self-attested by the entry making the claim")
        for failure in derived.get("failures") or []:
            check("R39", False, f"X1-P: {failure}")
        if derived.get("derived"):
            check("R39", c.get("reviewedIn") == derived["derived"],
                  f'conditional entry {cid} claims review in {c.get("reviewedIn")!r}, but it '
                  f'first entered this contract in {derived["derived"]!r}; pointing reviewedIn '
                  f"at an older revision attributes a review to a revision that never saw the "
                  f"exception, which is the evidence chain behind arming")

        # scopeIfArmed — a rendered projection of the derived target and channel set, the
        # same instrument rule S1 applies to the cross-platform summary.
        scope_spec = spec.get("scopeIfArmed") or {}
        platform = targets[c["target"]]["platform"] if c["target"] in targets else ""
        label = (scope_spec.get("platformLabels") or {}).get(platform, platform)
        want_scope = (scope_spec.get("template") or "").format(
            target=c["target"], count=NUMBER_WORDS[len(target_channels)], platformLabel=label)
        check("R39", norm(want_scope) in norm(c.get("scopeIfArmed") or ""),
              f"conditional entry {cid} does not state its derived scope {want_scope!r}; "
              f"the prose could otherwise describe a wider grant than the fields do")

        # the row mirrors the entry — kept from r10, and now the mirror of a DERIVED value
        row = targets[c["target"]]["entitlements"].get(c["key"]) if c["target"] in targets else None
        if row:
            check("R39", row.get("resolutionOwner") == c.get("armedBy"),
                  f"conditional entry {cid} and its row name different owners")
            check("R39", cid in (row.get("rationale") or ""),
                  f"the row for conditional entry {cid} does not name the register entry, "
                  f"so a reader of the row alone cannot find the review")

    # ---- and the assertion that makes the unarmed state checkable -------
    a19 = assertion_text.get("A19", "")
    check("R39", TEMP_FILE_KEY in a19,
          "assertion A19 does not name the conditional exception key, so nothing at build "
          "time checks that an unarmed exception stays out of the bundles")
    check("R39", floor in a19,
          f"assertion A19 does not name the {floor} floor whose uncertainty it exists to "
          f"record")
    for c in conditional or []:
        check("R39", c["id"] in a19,
              f'assertion A19 does not name register entry {c["id"]}, so the assertion and '
              f"the register could describe different exceptions")

    print(f"checks run: {checks}")
    if failures:
        print(f"FAIL ({len(failures)})")
        for f in failures:
            print("  -", f)
        return 1
    print("PASS — every rule holds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
