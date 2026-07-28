#!/usr/bin/env python3
"""Negative gates for the TASK-260715-ypo7yo matrix self-check (r7).

Each mutation deliberately re-introduces a defect and must make its gate exit 1 naming
the expected rule. A mutation that still passes means the rule is tautological and does
not actually constrain the contract.

Three harnesses, because the contract has three artifacts that can drift apart:

  MUTATIONS       parsed-JSON mutations -> validate_matrix.py
  DOC_MUTATIONS   rationale-document mutations -> validate_matrix.py (R33)
  BOARD_MUTATIONS simulated board-record mutations -> check-portal-consumer.py (r7)

The JSON and document mutations operate on parsed objects and whole strings, not on
regexes over text, so they cannot silently fail to apply.

BOARD_MUTATIONS is new in r7, for reviewer verdict 06 F1. The r6 board gate had no
negative gates at all: it was only ever run against the live board, so nothing proved it
would FAIL on a defect rather than pass vacuously. Each board mutation snapshots the live
records once, corrupts the snapshot, and feeds it back through
check-portal-consumer.py --simulate-board. No live board record is mutated to test a gate.
"""

import copy
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).parent


def locate(basename):
    """Find a sibling file.

    Board resources are TASK-ID-prefixed and use hyphens where the working copies
    use underscores, so accept any of those spellings rather than making the
    reviewer rename anything.
    """
    stem, _, ext = basename.rpartition(".")
    variants = {stem, stem.replace("_", "-"), stem.replace("-", "_")}
    for v in sorted(variants):
        for name in (f"{v}.{ext}", f"TASK-260715-ypo7yo_{v}.{ext}"):
            if (HERE / name).exists():
                return HERE / name
    for v in sorted(variants):
        matches = sorted(HERE.glob(f"*{v}.{ext}"))
        if matches:
            return matches[0]
    sys.exit(f"cannot find {basename} next to {__file__}")


MATRIX = locate("apple-identifier-entitlement-matrix.json")
# r10: read once, up here, because the DOCUMENT mutations below need the revision pair too
# and a hard-coded one goes stale on every bump.
CURRENT = json.loads(MATRIX.read_text())["revision"]
SUPERSEDED = json.loads(MATRIX.read_text())["supersedes"]
VALIDATOR = locate("validate_matrix.py")
# r6: R33 compares the rendered grant clauses against the rationale document, so the
# sandbox each mutation runs in needs the document too.
RATIONALE = locate("apple-identifier-entitlement-matrix.md")
# r7: the board gate is exercised as a third harness, against a simulated board record.
BOARD_GATE = locate("check-portal-consumer.py")
# r12: rule X1-P derives each register entry's introducing revision from the digest-pinned
# per-revision baselines, so every sandbox needs them. Read from the UNMUTATED contract, so
# the evidence on disk stays constant while the mutations move the claims about it.
BASELINES = [c["resource"] for c in json.loads(MATRIX.read_text())
             ["exceptionEntitlementRule"]["exceptionReviewProvenance"]["snapshotChain"]]


def locate_repo():
    """Walk up to the checkout that owns the board.

    Resolved rather than assumed by depth: this script runs both from the board resource
    directory and from a task-scoped working copy under .temp/, which sit at different
    depths.
    """
    for d in [HERE.resolve(), *HERE.resolve().parents]:
        if (d / ".task-board").is_dir():
            return d
    return None


REPO = locate_repo()

NE = "com.apple.developer.networking.networkextension"
SANDBOX = "com.apple.security.app-sandbox"
GROUPS = "com.apple.security.application-groups"
MACH = "com.apple.security.temporary-exception.mach-lookup.global-name"
TEMP_FILE = "com.apple.security.temporary-exception.files.absolute-path.read-write"
KEYCHAIN = "keychain-access-groups"


def conditional(m, cid="X1-C1"):
    """A conditional (reviewed, unarmed) exception register entry (r10, rule K3)."""
    return next(c for c in m["exceptionEntitlementRule"]["conditionalExceptions"]
                if c["id"] == cid)


def active(m, aid="X1-A1"):
    """An ACTIVE reviewed-exception register entry (rule X1)."""
    return next(e for e in m["exceptionEntitlementRule"]["reviewedExceptions"]
                if e.get("id") == aid)


def provenance_entry(m, entry_id):
    """A rule X1-P provenance entry — the declared introduction of a register entry (r12)."""
    return next(e for e in m["exceptionEntitlementRule"]["exceptionReviewProvenance"]["entries"]
                if e["entry"] == entry_id)


def revision_entry(m, revision):
    """A revisionLog event, which carries the declared introduction record (r12)."""
    return next(e for e in m["revisionLog"] if e["revision"] == revision)


def drop_assertion(m, aid):
    m["verification"]["assertions"] = [
        a for a in m["verification"]["assertions"] if a["id"] != aid
    ]


def target(m, key):
    return next(t for t in m["targets"] if t["key"] == key)


def group(m, key):
    return next(g for g in m["appGroups"] if g["key"] == key)


def profile(m, key):
    return next(p for p in m["profiles"] if p["target"] == key)


def rule(m, rid):
    """A structured cross-platform rule (r6, rule S1)."""
    return next(r for r in m["crossPlatformSharingContract"]["rules"] if r["id"] == rid)


def assertion(m, aid):
    return next(a for a in m["verification"]["assertions"] if a["id"] == aid)


def escope(m, sid):
    """A structured assertion entitlement scope (r8, rule S2)."""
    return next(e for e in m["verification"]["assertionScopeContract"]["entitlementScopes"]
                if e["id"] == sid)


def pscope(m, sid):
    """A structured assertion profile scope (r8, rule S2)."""
    return next(p for p in m["verification"]["assertionScopeContract"]["profileScopes"]
                if p["id"] == sid)


def drop_escope(m, sid):
    s2 = m["verification"]["assertionScopeContract"]
    s2["entitlementScopes"] = [e for e in s2["entitlementScopes"] if e["id"] != sid]


def drop_pscope(m, sid):
    s2 = m["verification"]["assertionScopeContract"]
    s2["profileScopes"] = [p for p in s2["profileScopes"] if p["id"] != sid]


def edit_consequence(m, owner_fragment, old, new):
    """Rewrite one downstreamConsequences entry's prose (r9, rule N1)."""
    entry = next(d for d in m["downstreamConsequences"] if owner_fragment in d["owner"])
    if old not in entry["consequence"]:
        raise ValueError(f"{old!r} is not in the {owner_fragment} consequence")
    entry["consequence"] = entry["consequence"].replace(old, new)


# The exact r7 texts, so the two verdict-07 findings can be replayed verbatim rather than
# approximated. A gate that only rejects a paraphrase has not proven it rejects the defect.
R7_A5_TEXT = (
    "com.apple.security.application-groups is PRESENT on every iOS bundle with exactly the "
    "matrix array and no team prefix; the App Group record literals are iOS-style on both "
    "platforms"
)
R7_A9_TEXT = (
    "every development profile carries ProvisionedDevices containing this Mac; every "
    "Developer ID profile carries ProvisionsAllDevices == true and no ProvisionedDevices key"
)


def restore_r7_a9(m):
    """Collapse A9a/A9b/A9c back into r7's single unscoped A9."""
    keep = [a for a in m["verification"]["assertions"]
            if a["id"] not in ("A9a", "A9b", "A9c")]
    idx = next(i for i, a in enumerate(m["verification"]["assertions"]) if a["id"] == "A9a")
    keep.insert(min(idx, len(keep)), {"id": "A9", "text": R7_A9_TEXT})
    m["verification"]["assertions"] = keep


# (finding, description, expected rule, mutation)
MUTATIONS = [
    ("F1", "macOS development channel gets the -systemextension value (the r1 defect)", "R7",
     lambda m: target(m, "macos.host")["entitlements"][NE]["valueByChannel"].__setitem__(
         "development", ["packet-tunnel-provider-systemextension"])),

    ("F1", "provider NE value collapses to a single channel-independent value (r1 shape)", "R7",
     lambda m: target(m, "macos.provider")["entitlements"][NE].update(
         {"value": ["packet-tunnel-provider-systemextension"]})),

    ("F1", "Developer ID channel drops the suffix", "R7",
     lambda m: target(m, "macos.provider")["entitlements"][NE]["valueByChannel"].__setitem__(
         "developer-id", ["packet-tunnel-provider"])),

    ("F1", "Mac Development profile authorizes the suffixed value", "R23",
     lambda m: profile(m, "macos.host")["development"].__setitem__(
         "authorizesNetworkExtensionValues", ["packet-tunnel-provider-systemextension"])),

    ("F1", "Ceremony C1 authorizes the -systemextension value", "R22",
     lambda m: m["c1AuthorizationScope"].__setitem__(
         "authorizedNetworkExtensionValues", ["packet-tunnel-provider-systemextension"])),

    ("F1", "the probe claims a Developer ID channel it has no profile for", "R19",
     lambda m: target(m, "macos.probe.host")["channels"].append("developer-id")),

    ("F2", "macOS App Group literal is team-prefixed (the r1 defect)", "R9",
     lambda m: group(m, "production")["entitlementLiteral"].__setitem__(
         "macOS", "$(TeamIdentifierPrefix)group.works.relux.tunnel")),

    ("F2", "macOS target claims a team-prefixed group literal directly", "R9",
     lambda m: target(m, "macos.provider")["entitlements"][GROUPS].__setitem__(
         "value", ["262RZ595FP.group.works.relux.tunnel"])),

    ("F2", "portal record no longer equals the entitlement literal", "R18",
     lambda m: group(m, "production").__setitem__(
         "portalRecordIdentifier", "group.works.relux.tunnel.other")),

    # r5: the probe record was deleted, so the collapse is staged by adding a second
    # record that duplicates production's identifier rather than by renaming the probe's.
    ("F2", "a second App Group record duplicates production's portal identifier", "R18",
     lambda m: m["appGroups"].append(
         dict(group(m, "production"), key="second", consumedByTargets=[]))),

    ("F3", "the macOS signing-generated allowlist is emptied", "R20",
     lambda m: m["entitlementClassification"]["signingGenerated"]["macOS"].__setitem__("always", [])),

    ("F3", "the project authors a key the toolchain generates", "R20",
     lambda m: target(m, "macos.host")["entitlements"].__setitem__(
         "com.apple.application-identifier", {"status": "required", "value": "x",
                                              "portalCapability": False, "rationale": "x"})),

    ("F3", "get-task-allow is reclassified as always-present", "R20",
     lambda m: m["entitlementClassification"]["signingGenerated"]["macOS"]["always"].append(
         "com.apple.security.get-task-allow")),

    ("F4", "host sandboxing is attributed to an Apple rule (the r1 defect)", "R21",
     lambda m: target(m, "macos.host")["entitlements"][SANDBOX].__setitem__(
         "requirementSource", "apple-requirement")),

    ("F4", "provider sandboxing is downgraded to a project choice", "R21",
     lambda m: target(m, "macos.provider")["entitlements"][SANDBOX].__setitem__(
         "requirementSource", "project-architecture")),

    ("F4", "a sandbox requirement loses its basis citation", "R21",
     lambda m: target(m, "macos.provider")["entitlements"][SANDBOX].pop("requirementBasis")),

    ("r1", "a bundle identifier drifts into the legacy namespace", "R4",
     lambda m: target(m, "macos.host").__setitem__("bundleIdentifier", "works.relux.proxy.mac")),

    ("r1", "provider identifier is no longer host + .tunnel", "R1",
     lambda m: target(m, "macos.provider").__setitem__(
         "bundleIdentifier", "works.relux.tunnel.mactunnel")),

    ("r1", "the withheld keychain group is silently granted", "R12",
     lambda m: target(m, "macos.provider")["entitlements"]["keychain-access-groups"].__setitem__(
         "status", "required")),

    ("r1", "an iOS target becomes provisioned", "R14",
     lambda m: target(m, "ios.host").__setitem__("provisioned", True)),

    ("r1", "a distribution profile becomes C1-authorized", "R17",
     lambda m: profile(m, "macos.host")["distribution"].__setitem__("c1Authorized", True)),

    ("r1", "system-extension.install is granted to a provider", "R8",
     lambda m: target(m, "macos.provider")["entitlements"][
         "com.apple.developer.system-extension.install"].__setitem__("status", "required")),

    ("r1", "a forbidden provider value is granted", "R24",
     lambda m: target(m, "macos.provider")["entitlements"][NE]["valueByChannel"].__setitem__(
         "development", ["dns-proxy-provider"])),

    ("F1-v02", "the Sparkle Mach lookup exception is missing entirely (the r2 defect)", "R25",
     lambda m: target(m, "macos.host")["entitlements"].pop(MACH)),

    ("F1-v02", "the exception drops -spki and keeps only -spks", "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "value", ["$(PRODUCT_BUNDLE_IDENTIFIER)-spks"])),

    ("F1-v02", "the exception names the wrong Sparkle endpoint suffix", "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "value", ["$(PRODUCT_BUNDLE_IDENTIFIER)-spkd",
                   "$(PRODUCT_BUNDLE_IDENTIFIER)-spkp"])),

    ("F1-v02", "resolvedValue does not expand the build variable, so no bundle check can use it",
     "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "resolvedValue", ["$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
                           "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"])),

    ("F1-v02", "resolvedValue is pinned to a different host identifier", "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "resolvedValue", ["works.relux.tunnel.mac.tunnel-spks",
                           "works.relux.tunnel.mac.tunnel-spki"])),

    ("F1-v02", "the exception is granted to the packet-tunnel provider as well", "R25",
     lambda m: target(m, "macos.provider")["entitlements"].__setitem__(
         MACH, copy.deepcopy(target(m, "macos.host")["entitlements"][MACH]))),

    ("F1-v02", "the exception is granted to an iOS target, which never links Sparkle", "R25",
     lambda m: target(m, "ios.host")["entitlements"].__setitem__(
         MACH, copy.deepcopy(target(m, "macos.host")["entitlements"][MACH]))),

    ("F1-v02", "the exception is downgraded to a generic sandbox consequence", "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "requirementSource", "sandbox-consequence")),

    ("F1-v02", "the exception claims a portal capability it does not have", "R25",
     lambda m: target(m, "macos.host")["entitlements"][MACH].__setitem__(
         "portalCapability", True)),

    ("X1", "the reviewed-exception register is emptied while the grant stays", "R26",
     lambda m: m["exceptionEntitlementRule"].__setitem__("reviewedExceptions", [])),

    ("X1", "the register disagrees with the entitlement row it claims to review", "R26",
     lambda m: m["exceptionEntitlementRule"]["reviewedExceptions"][0].__setitem__(
         "values", ["$(PRODUCT_BUNDLE_IDENTIFIER)-spks"])),

    ("X1", "a Hardened Runtime relaxation is authored on the host", "R26",
     lambda m: target(m, "macos.host")["entitlements"].__setitem__(
         "com.apple.security.cs.disable-library-validation",
         {"status": "required-adjacent", "value": True, "portalCapability": False,
          "requirementSource": "project-architecture", "requirementBasis": "x",
          "rationale": "x"})),

    ("X1", "the prohibited relaxation set is emptied", "R26",
     lambda m: m["exceptionEntitlementRule"].__setitem__("prohibitedKeys", [])),

    ("X1", "get-task-allow is banned by X1, contradicting the development channel", "R26",
     lambda m: m["exceptionEntitlementRule"]["prohibitedKeys"].append(
         "com.apple.security.get-task-allow")),

    ("A-set", "assertion A14 is deleted, so nothing checks the exception at build time", "R27",
     lambda m: drop_assertion(m, "A14")),

    ("A-set", "assertion A10e is deleted, so required-adjacent keys need not be present", "R27",
     lambda m: drop_assertion(m, "A10e")),

    ("A-set", "assertion A15 is deleted, so the X1 prohibited set is never enforced", "R27",
     lambda m: drop_assertion(m, "A15")),

    ("A-set", "an assertion is emptied instead of removed", "R27",
     lambda m: m["verification"]["assertions"][0].__setitem__("text", "   ")),

    # ---- r4: reviewer verdict 03 F1 — the macOS App Group least-privilege verdict ----

    ("F1-v03", "the macOS host App Group is re-granted (the r3 defect verdict 03 caught)", "R28",
     lambda m: target(m, "macos.host")["entitlements"][GROUPS].__setitem__("status", "required")),

    ("F1-v03", "the macOS provider App Group is re-granted", "R28",
     lambda m: target(m, "macos.provider")["entitlements"][GROUPS].__setitem__(
         "status", "required")),

    ("F1-v03", "the same defect one row over — the macOS probe host is re-granted", "R28",
     lambda m: target(m, "macos.probe.host")["entitlements"][GROUPS].__setitem__(
         "status", "required")),

    ("F1-v03", "the over-correction — an iOS row is withheld too, where the group does work",
     "R28",
     lambda m: target(m, "ios.host")["entitlements"][GROUPS].__setitem__("status", "prohibited")),

    ("F1-v03", "a withheld macOS row keeps the group literal it is not entitled to", "R9",
     lambda m: target(m, "macos.provider")["entitlements"][GROUPS].__setitem__(
         "value", ["group.works.relux.tunnel"])),

    ("F1-v03", "a withheld macOS row drops the condition that would reopen it", "R28",
     lambda m: target(m, "macos.host")["entitlements"][GROUPS].pop("reopensOnly")),

    ("F1-v03", "a withheld macOS row still claims the App Groups portal capability", "R28",
     lambda m: target(m, "macos.provider")["entitlements"][GROUPS].__setitem__(
         "portalCapability", True)),

    ("F1-v03", "a granted iOS row stops naming the function it serves", "R28",
     lambda m: target(m, "ios.provider")["entitlements"][GROUPS].pop("functionOnThisPlatform")),

    ("F1-v03", "rule G2 reverts to r3's future-conditional macOS purpose", "R28",
     lambda m: m["appGroupPurposeRule"].__setitem__(
         "macOS", "Retained as the sandbox-visible shared namespace for the host-to-provider "
                  "channel that TASK-260728-7ii1xz will use, so C1 need not be repeated.")),

    ("F1-v03", "the G4 survey concedes the selected design does use an App Group grant", "R28",
     lambda m: m["appGroupLeastPrivilegeRule"]["survey"][3].__setitem__(
         "usedBySelectedDesign", True)),

    ("F1-v03", "the G4 survey is trimmed to the group container, hiding the system-wide grants",
     "R28",
     lambda m: m["appGroupLeastPrivilegeRule"].__setitem__(
         "survey", [r for r in m["appGroupLeastPrivilegeRule"]["survey"]
                    if r["namespace"] == "home-relative"])),

    ("F1-v03", "Ceremony C1 re-enables the App Groups capability nothing needs", "R30",
     lambda m: m["c1AuthorizationScope"]["authorizedCapabilities"].append(
         "App Groups capability on the four macOS App IDs")),

    ("F1-v03", "Ceremony C1 re-authorizes an App Group record nothing consumes", "R30",
     lambda m: m["c1AuthorizationScope"].__setitem__(
         "authorizedAppGroups", ["group.works.relux.tunnel"])),

    ("F1-v03", "an App Group record claims C1 authorization it no longer has", "R30",
     lambda m: group(m, "production").__setitem__("c1Authorized", True)),

    ("F1-v03", "a deferred App Group record stops naming who allocates it and when", "R30",
     lambda m: group(m, "production").pop("allocationTiming")),

    ("A-set", "assertion A16 is deleted, so no build check enforces the macOS absence", "R27",
     lambda m: drop_assertion(m, "A16")),

    # ---- r4: the TASK-260728-7ii1xz amendment packet (M1, M2, M5) ----

    ("M1", "the settled keychain row keeps the resolutionOwner that held it open", "R13",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].__setitem__(
         "resolutionOwner", "TASK-260728-7ii1xz")),

    ("M1", "the settled keychain row keeps the amendmentRule that re-grants it on refuted "
           "reasoning", "R13",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].__setitem__(
         "amendmentRule", "If the resolved macOS credential transport gives the provider direct "
                          "keychain access, this row is amended to required with the same group "
                          "literal.")),

    ("M1", "the keychain row slides back to pending after the decision was made", "R12",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].__setitem__(
         "status", "prohibited-pending-decision")),

    ("M1", "the provider is granted a keychain group the file-based keychain cannot honour",
     "R12",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].__setitem__(
         "status", "required")),

    ("M1", "the settled keychain row stops saying what would reopen it", "R29",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].pop("reopensOnly")),

    ("M5", "rule K1 drops the Apple note that distinguishes the two keychain implementations",
     "R29",
     lambda m: m["keychainScopeRule"].__setitem__("source", "internal judgement")),

    ("M2", "OC-1 is reopened after its owning task delivered a decision", "R29",
     lambda m: next(c for c in m["openConstraints"] if c["id"] == "OC-1").pop("status")),

    ("M2", "OC-1 is closed without naming the task that resolved it", "R29",
     lambda m: next(c for c in m["openConstraints"] if c["id"] == "OC-1").pop("resolvedBy")),

    ("M2", "a closed constraint keeps a pending resolutionOwner, reading as still open", "R29",
     lambda m: next(c for c in m["openConstraints"] if c["id"] == "OC-1").__setitem__(
         "resolutionOwner", "TASK-260728-7ii1xz")),

    # ---------------------------------------------------------------- r5, verdict 04 F1
    # Rule K2. The r4 defect was a shared keychain access group on a macOS target with no
    # second member. These attack the correction from both sides: re-granting it, and
    # over-correcting by withdrawing it where the group genuinely is shared.
    ("F1-v04", "the r4 defect itself — the macOS host keychain group is re-granted", "R12",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].update(
         {"status": "required", "value": ["$(AppIdentifierPrefix)works.relux.tunnel.shared"]})),

    ("F1-v04", "the macOS host is re-granted the group without a matching record consumer",
     "R31",
     lambda m: (target(m, "macos.host")["entitlements"][KEYCHAIN].update({"status": "required"}),
                m["keychainAccessGroups"][0].__setitem__(
                    "consumedByTargets", ["ios.host", "ios.provider", "macos.host"]))),

    ("F1-v04", "a withheld keychain row keeps the group literal it is not entitled to", "R12",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].__setitem__(
         "value", ["$(AppIdentifierPrefix)works.relux.tunnel.shared"])),

    ("F1-v04", "the over-correction — an iOS row is withheld too, where the group IS shared",
     "R31",
     lambda m: target(m, "ios.provider")["entitlements"][KEYCHAIN].update(
         {"status": "prohibited", "reopensOnly": "x"}) or
     target(m, "ios.provider")["entitlements"][KEYCHAIN].pop("value")),

    ("F1-v04", "the keychain record stops naming the targets that consume it", "R31",
     lambda m: m["keychainAccessGroups"][0].pop("consumedByTargets")),

    ("F1-v04", "the keychain record names a consumer that is not granted the group", "R31",
     lambda m: m["keychainAccessGroups"][0]["consumedByTargets"].append("macos.probe.host")),

    ("F1-v04", "the keychain record silently re-widens to macOS", "R31",
     lambda m: m["keychainAccessGroups"][0].__setitem__("platforms", ["iOS", "macOS"])),

    ("F1-v04", "a withheld keychain row drops the condition that would reopen it", "R31",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].pop("reopensOnly")),

    ("F1-v04", "a probe keychain row goes back to being settled by silence", "R31",
     lambda m: target(m, "ios.probe.provider")["entitlements"][KEYCHAIN].pop("reopensOnly")),

    ("F1-v04", "the macOS host stops recording the default group it falls back to", "R31",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].pop("defaultAccessGroup")),

    ("F1-v04", "the recorded default group is the shared one, not the app identifier", "R31",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].__setitem__(
         "defaultAccessGroup", "262RZ595FP.works.relux.tunnel.shared")),

    ("F1-v04", "rule K2 loses the ordering law that makes withholding provably safe", "R31",
     lambda m: m["keychainLeastPrivilegeRule"].pop("defaultAccessGroupLaw")),

    ("F1-v04", "rule K2 drops its Apple basis and rests on internal judgement", "R31",
     lambda m: m["keychainLeastPrivilegeRule"].__setitem__("source", "internal judgement")),

    ("F1-v04", "rule K1 stops admitting that it never governed the host", "R31",
     lambda m: m["keychainScopeRule"].pop("hostScope")),

    ("A-set", "assertion A17 is deleted, so nothing enforces the macOS keychain absence", "R27",
     lambda m: drop_assertion(m, "A17")),

    # ---------------------------------------------------------------- r5, verdict 04 F3
    # Rule G4's probeRule. A probe inherits identifiers and profile classes, never
    # entitlements.
    ("F3-v04", "the r4 defect itself — the iOS probe host App Group is re-granted", "R28",
     lambda m: target(m, "ios.probe.host")["entitlements"][GROUPS].__setitem__(
         "status", "required")),

    ("F3-v04", "the same defect one row over — the iOS probe provider is re-granted", "R28",
     lambda m: target(m, "ios.probe.provider")["entitlements"][GROUPS].__setitem__(
         "status", "required")),

    ("F3-v04", "the deleted probe record is restored with no consumer to read it", "R11",
     lambda m: m["appGroups"].append({
         "key": "probe", "style": "iOS-style",
         "portalRecordIdentifier": "group.works.relux.tunnel.probe",
         "entitlementLiteral": {"iOS": "group.works.relux.tunnel.probe",
                                "macOS": "group.works.relux.tunnel.probe"},
         "resolvedLiteral": {"iOS": "group.works.relux.tunnel.probe",
                             "macOS": "group.works.relux.tunnel.probe"},
         "c1Authorized": False, "consumedByTargets": [],
         "allocationOwner": "x", "allocationTiming": "x"})),

    ("F3-v04", "a record is restored still naming the probe targets that lost the grant", "R9",
     lambda m: m["appGroups"].append({
         "key": "probe", "style": "iOS-style",
         "portalRecordIdentifier": "group.works.relux.tunnel.probe",
         "entitlementLiteral": {"iOS": "group.works.relux.tunnel.probe",
                                "macOS": "group.works.relux.tunnel.probe"},
         "resolvedLiteral": {"iOS": "group.works.relux.tunnel.probe",
                             "macOS": "group.works.relux.tunnel.probe"},
         "c1Authorized": False,
         "consumedByTargets": ["ios.probe.host", "ios.probe.provider"],
         "allocationOwner": "x", "allocationTiming": "x"})),

    ("F3-v04", "a withheld iOS probe row keeps the group literal it is not entitled to", "R9",
     lambda m: target(m, "ios.probe.host")["entitlements"][GROUPS].__setitem__(
         "value", ["group.works.relux.tunnel.probe"])),

    ("F3-v04", "a withheld iOS probe row still claims the App Groups portal capability", "R28",
     lambda m: target(m, "ios.probe.provider")["entitlements"][GROUPS].__setitem__(
         "portalCapability", True)),

    ("F3-v04", "a withheld iOS probe row drops the condition that would reopen it", "R28",
     lambda m: target(m, "ios.probe.host")["entitlements"][GROUPS].pop("reopensOnly")),

    ("F3-v04", "rule G4 loses the probe rule, so a probe can inherit a grant again", "R28",
     lambda m: m["appGroupLeastPrivilegeRule"].pop("probeRule")),

    ("F3-v04", "rule G3 miscounts the records it claims to govern", "R11",
     lambda m: m["appGroupDisjointnessRule"].__setitem__("recordCount", 2)),

    ("F3-v04", "rule G3 forgets that the probe family carried a record at all", "R11",
     lambda m: m["appGroupDisjointnessRule"].pop("history")),

    ("A-set", "assertion A18 is deleted, so nothing enforces the iOS probe absence", "R27",
     lambda m: drop_assertion(m, "A18")),

    # ---------------------------------------------------------------- r6, verdict 05 F1
    # Rule S1. The r5 defect was a cross-platform SUMMARY asserting a grant the rows had
    # already withdrawn. These attack the correction from every side the defect could
    # return: the sentence, the structured claim, the record list, and the count scan.
    ("F1-v05", "the r5 defect itself — the summary re-asserts the r4 macOS host Keychain grant",
     "R32",
     lambda m: m["crossPlatformRules"].__setitem__(
         2, "One Keychain access group NAME, granted only where it is functional (rule K1): "
            "the iOS host and appex, and the macOS host. Never the macOS provider, which reads "
            "the system-domain keychain, where access groups do not apply.")),

    ("F1-v05", "the grant clause survives but a stale grantee is appended after it", "R32",
     lambda m: m["crossPlatformRules"].__setitem__(
         2, m["crossPlatformRules"][2] + " The macOS host holds the group as well.")),

    ("F1-v05", "the structured claim is widened to a target the rows do not grant", "R32",
     lambda m: rule(m, "XP-3")["grantedTargets"].append("macos.host")),

    ("F1-v05", "the grant clause drops one of the two real grantees", "R32",
     lambda m: rule(m, "XP-3").__setitem__("grantClause", "granted to the iOS host")),

    ("F1-v05", "the App Group summary resurrects the record r5 deleted", "R32",
     lambda m: m["crossPlatformRules"].__setitem__(
         1, m["crossPlatformRules"][1] +
         " The probe record group.works.relux.tunnel.probe is allocated at the same sitting.")),

    ("F1-v05", "the record list in the summary drifts from the records declared", "R32",
     lambda m: rule(m, "XP-2").__setitem__("records", ["group.works.relux.tunnel.probe"])),

    ("F1-v05", "the Sparkle summary is widened to the packet-tunnel provider", "R32",
     lambda m: rule(m, "XP-5")["grantedTargets"].append("macos.provider")),

    ("F1-v05", "a universal grant is relabelled enumerated, so its target list goes unchecked",
     "R32",
     lambda m: rule(m, "XP-4").__setitem__("mentionStyle", "enumerated")),

    ("F1-v05", "an enumerated grant is relabelled universal, hiding which targets it names",
     "R32",
     lambda m: rule(m, "XP-2").__setitem__("mentionStyle", "universal")),

    ("F1-v05", "a rendered sentence loses its structured rule and becomes unchecked prose",
     "R32",
     lambda m: m["crossPlatformSharingContract"]["rules"].pop(2)),

    ("F1-v05", "two structured rules claim the same sentence, leaving another unchecked", "R32",
     lambda m: rule(m, "XP-3").__setitem__("renderedIndex", 1)),

    ("F1-v05", "a grantee is re-labelled as a non-grantee contrast mention", "R32",
     lambda m: rule(m, "XP-3")["nonGranteeMentions"].append(
         {"target": "ios.host", "role": "contrast",
          "clause": "Never the macOS provider, which reads the system-domain keychain, where "
                    "access groups do not apply (rule K1)."})),

    ("F1-v05", "a declared contrast clause is reworded in the register but not in the sentence",
     "R32",
     lambda m: rule(m, "XP-3")["nonGranteeMentions"][0].__setitem__(
         "clause", "Never the macOS provider.")),

    ("F1-v05", "the summary claims an entitlement key no target row grants", "R32",
     lambda m: rule(m, "XP-5").__setitem__(
         "entitlementKey", "com.apple.developer.associated-domains")),

    ("F1-v05", "an unregistered sentence starts counting App Group records again", "R32",
     lambda m: m["appGroupStyleRule"].__setitem__(
         "statement", "One App Group record per family, allocated on the Developer website, "
                      "claimed by the IDENTICAL literal on both platforms.")),

    ("F1-v05", "a registered count claim states r4's two records", "R32",
     lambda m: m["crossPlatformRules"].__setitem__(
         1, m["crossPlatformRules"][1].replace("ONE App Group record exists",
                                               "two App Group records exist"))),

    ("F1-v05", "a registered count-claim path stops stating a count, so the register rots",
     "R32",
     lambda m: m["crossPlatformRules"].__setitem__(
         1, m["crossPlatformRules"][1].replace("ONE App Group record exists in this contract, ",
                                               "The record is "))),

    ("F1-v05", "the historical exclusion list gains a path that does not exist", "R32",
     lambda m: m["crossPlatformSharingContract"]["historicalPaths"].append(
         "appGroupLeastPrivilegeRule.legacyNotes")),

    # ---------------------------------------------------------------- r6, verdict 05 F2
    # Rule P1. The pin the board gate reads must stay complete and must keep agreeing with
    # c1AuthorizationScope, or the board gate checks something weaker than C1 authorized.
    ("F2-v05", "the pin stops naming one of the four C1-authorized App IDs", "R32",
     lambda m: m["portalMutationTaskContract"].__setitem__(
         "requiredMutations", ["Create the macOS App IDs."])),

    ("F2-v05", "the board gate drops the phrase that negates the provider-only defect", "R32",
     lambda m: m["portalMutationTaskContract"]["boardGate"]["requiredPhrases"].remove(
         "hosts included")),

    ("F2-v05", "the banned pre-r5 wording register is emptied", "R32",
     lambda m: m["portalMutationTaskContract"].__setitem__("bannedContractPhrases", [])),

    ("F2-v05", "the pin points at a task this matrix does not authorize", "R32",
     lambda m: m["portalMutationTaskContract"].__setitem__("task", "TASK-260728-q5kjta")),

    ("F2-v05", "the pin stops forbidding the App Groups capability nothing needs", "R32",
     lambda m: m["portalMutationTaskContract"].__setitem__(
         "forbiddenMutations", ["Any of the four iOS App IDs.",
                                "Any App Group record, including group.works.relux.tunnel."])),

    # ------------------------------------------------------- r8, verdict 07 F1 (rule S2)
    # The defect itself, replayed verbatim, then every way the new gate could be dodged.
    ("F1-v07", "A5's r7 text is restored verbatim — the reported defect", "R35",
     lambda m: assertion(m, "A5").__setitem__("text", R7_A5_TEXT)),

    ("F1-v07", "an iOS probe row is granted the App Group, moving the derived present set",
     "R35",
     lambda m: target(m, "ios.probe.host")["entitlements"][GROUPS].__setitem__(
         "status", "required")),

    ("F1-v07", "A5's scope is widened to the probe pair by hand", "R35",
     lambda m: escope(m, "AS-3").__setitem__(
         "scopeTargets", ["ios.host", "ios.provider", "ios.probe.host", "ios.probe.provider"])),

    ("F1-v07", "A5's predicate is widened to every iOS row", "R35",
     lambda m: escope(m, "AS-3").__setitem__("classPredicates", [{"platform": "iOS"}])),

    ("F1-v07", "A5's predicate carries a typo that silently selects nothing", "R35",
     lambda m: escope(m, "AS-3").__setitem__(
         "classPredicates", [{"platform": "iOS", "family": "prod"}])),

    ("F1-v07", "the probe-absence scope is deleted, leaving the two rows unspoken for", "R35",
     lambda m: drop_escope(m, "AS-5")),

    ("F1-v07", "the probe-absence scope is flipped to present, contradicting the rows", "R35",
     lambda m: escope(m, "AS-5").__setitem__("polarity", "present")),

    ("F1-v07", "A18 is deleted while its scope entry still points at it", "R35",
     lambda m: drop_assertion(m, "A18")),

    ("F1-v07", "A5's scope clause is reworded, so the text states an unchecked scope", "R35",
     lambda m: escope(m, "AS-3").__setitem__(
         "scopeClause", "PRESENT on the production iOS bundles")),

    ("F1-v07", "the macOS App Group absence scope is dropped, breaking the partition", "R35",
     lambda m: drop_escope(m, "AS-4")),

    ("F1-v07", "A4 loses the 'only' that discharges its complement", "R35",
     lambda m: escope(m, "AS-2").__setitem__("exclusivityMarker", "exclusively")),

    ("F1-v07", "A4's exclusivity is demoted to a plain present claim", "R35",
     lambda m: escope(m, "AS-2").__setitem__("polarity", "present")),

    ("F1-v07", "the probe pair is named in A5 without being declared a contrast", "R35",
     lambda m: escope(m, "AS-3").__setitem__("nonScopeMentions", [])),

    ("F1-v07", "a target A5 actually scopes is declared out of scope", "R35",
     lambda m: escope(m, "AS-3")["nonScopeMentions"].append(
         {"target": "ios.host", "role": "contrast",
          "clause": "PRESENT on the two PRODUCTION iOS bundles"})),

    ("F1-v07", "a new assertion names an entitlement key and registers no scope", "R35",
     lambda m: m["verification"]["assertions"].append(
         {"id": "A13", "text": "keychain-access-groups is present on works.relux.tunnel.mac"})),

    ("F1-v07", "a scope is registered against an assertion that no longer names its key",
     "R35",
     lambda m: escope(m, "AS-9").__setitem__("entitlementKey", KEYCHAIN)),

    ("F1-v07", "rule S2 stops recording the stale claims it exists to prevent", "R35",
     lambda m: m["verification"]["assertionScopeContract"].__setitem__(
         "staleClaimsFound", [])),

    ("F1-v07", "rule S2 loses the partition rule that both findings turned on", "R35",
     lambda m: m["verification"]["assertionScopeContract"].__setitem__("partitionRule", "")),

    # ------------------------------------------------------- r8, verdict 07 F2 (rule S2)
    ("F2-v07", "A9's r7 text is restored verbatim — the reported defect", "R36",
     restore_r7_a9),

    ("F2-v07", "an iOS development profile is given a concrete device, moving the rows",
     "R36",
     lambda m: profile(m, "ios.host")["development"].__setitem__(
         "devices", ["this Apple-silicon Mac"])),

    ("F2-v07", "the deferred scope is widened over a macOS profile", "R36",
     lambda m: pscope(m, "PS-2").__setitem__("classPredicates", [{"family": "production"}])),

    ("F2-v07", "the macOS profile scope is widened to every profile row", "R36",
     lambda m: pscope(m, "PS-1").__setitem__("classPredicates", [{}])),

    ("F2-v07", "the iOS deferred scope is deleted, leaving four profiles unspoken for",
     "R36",
     lambda m: drop_pscope(m, "PS-2")),

    ("F2-v07", "the macOS profiles are relabelled deferred, contradicting their device list",
     "R36",
     lambda m: pscope(m, "PS-1").__setitem__("deviceBinding", "deferred")),

    ("F2-v07", "a C1-authorized profile is unmarked, splitting A9a from the ceremony scope",
     "R36",
     lambda m: profile(m, "macos.probe.host")["development"].__setitem__(
         "c1Authorized", False)),

    ("F2-v07", "the deferral basis is changed, so a parked device set names no decision",
     "R36",
     lambda m: m["verification"]["assertionScopeContract"].__setitem__(
         "deferralBasis", "ADR-999")),

    ("F2-v07", "the Developer ID scope is moved onto the development channel", "R36",
     lambda m: pscope(m, "PS-3").__setitem__("channel", "development")),

    ("F2-v07", "A9b's scope clause is reworded, so the text states an unchecked scope",
     "R36",
     lambda m: pscope(m, "PS-2").__setitem__(
         "scopeClause", "no iOS development profile is created at Ceremony C1")),

    ("F2-v07", "A9c is deleted while its profile scope still points at it", "R36",
     lambda m: drop_assertion(m, "A9c")),

    # -------------------------------------------------- r9, rule D1 (self-found, no verdict)
    # The list half of the defect. The reachability half needs the board and is exercised by
    # GRAPH_MUTATIONS below.
    ("D1-r9", "a consumer named in OC-1.affects is dropped back out of the consumers list — "
              "the r8 state for four elements", "R37",
     lambda m: m.__setitem__("consumers",
                             [c for c in m["consumers"] if "29ws8l" not in c])),

    ("D1-r9", "an obligation owner assigned only from a prose field is dropped, which is how "
              "TASK-260717-xempiv stayed off the list for five revisions", "R37",
     lambda m: m.__setitem__("consumers",
                             [c for c in m["consumers"] if "xempiv" not in c])),

    ("D1-r9", "a phantom consumer is declared that the contract never mentions, so nothing "
              "says what it consumes", "R37",
     lambda m: m["consumers"].append("TASK-260715-999999 — unexplained")),

    ("D1-r9", "`done` is admitted as an exemption basis, which would exempt any consumer "
              "that had already run against an unaccepted matrix", "R37",
     lambda m: m["consumerDependencyContract"].__setitem__(
         "exemptionBasisAllowed", ["upstream", "done"])),

    ("D1-r9", "an exemption keeps its element but loses the reason that justifies it", "R37",
     lambda m: m["consumerDependencyContract"]["exemptions"][0].__setitem__("reason", "")),

    ("D1-r9", "an exemption claims a basis the rule does not allow", "R37",
     lambda m: m["consumerDependencyContract"]["exemptions"][0].__setitem__(
         "basis", "already-done")),

    ("D1-r9", "the record that three consumers had no path here is quietly dropped, so the "
              "fix reads as a contract that was always right", "R37",
     lambda m: m["consumerDependencyContract"].__setitem__(
         "staleClaimsFound",
         [s for s in m["consumerDependencyContract"]["staleClaimsFound"]
          if "3f4lxy" not in s])),

    ("D1-r9", "the board change shrinks to two of the three gaps it closed", "R37",
     lambda m: m["consumerDependencyContract"]["boardChange"].__setitem__(
         "closes", ["TASK-260715-1o9wjz", "TASK-260715-3f4lxy"])),

    ("D1-r9", "the cycle check behind the new edge is dropped", "R37",
     lambda m: m["consumerDependencyContract"]["boardChange"].__setitem__("cycleCheck", "")),

    ("D1-r9", "selfReference stops naming this contract's owner, which would exempt an "
              "arbitrary element from reachability", "R37",
     lambda m: m["consumerDependencyContract"].__setitem__(
         "selfReference", "TASK-260715-3jloqy")),

    ("D1-r9", "the graph query stops reading bugs, so the closure runs over a subgraph",
     "R37",
     lambda m: m["consumerDependencyContract"]["boardGate"].__setitem__(
         "graphQueries", ["list(type=task) { id blockedBy }"])),

    ("D1-r9", "rule D1 stops naming the gate that reads the board", "R37",
     lambda m: m["consumerDependencyContract"].__setitem__(
         "gate", "checked by hand during review")),

    ("D1-r9", "the rule that a mention is an obligation is deleted", "R37",
     lambda m: m["consumerDependencyContract"].__setitem__("mentionCoverageRule", "")),

    # -------------------------------------------------- r9, rule N1 (self-found, no verdict)
    # The real class: a ROW moves and the prose counts do not. This is what r3 -> r4 -> r5
    # did three times by hand.
    ("N1-r9", "a macos.host row is withdrawn and every prose count in both artifacts is left "
              "where r8 put it — the r5 event replayed", "R38",
     lambda m: target(m, "macos.host")["entitlements"][SANDBOX].__setitem__(
         "status", "prohibited")),

    ("N1-r9", "a macos.host row is ADDED and nobody re-renders the counts", "R38",
     lambda m: target(m, "macos.host")["entitlements"].__setitem__(
         "com.apple.security.files.user-selected.read-only",
         {"status": "required-adjacent", "value": True, "portalCapability": False,
          "rationale": "invented by a negative gate"})),

    ("N1-r9", "the injected development-only key is dropped, which changes the development "
              "total but not the developer-id one", "R38",
     lambda m: m["entitlementClassification"]["signingGenerated"]["macOS"].__setitem__(
         "developmentChannelOnly", [])),

    ("N1-r9", "the JSON's own downstream count is hand-edited away from the rows", "R38",
     lambda m: edit_consequence(m, "uyju7n", "five authored keys plus three injected",
                                "six authored keys plus three injected")),

    ("N1-r9", "a registered claim is de-registered while its sentence stays in the prose",
     "R38",
     lambda m: m["numericClaimContract"].__setitem__(
         "claims", [c for c in m["numericClaimContract"]["claims"] if c["id"] != "N1-3"])),

    ("N1-r9", "an unregistered count claim is added to the contract", "R38",
     lambda m: m["namespaces"].__setitem__(
         "forbiddenReason",
         m["namespaces"]["forbiddenReason"] + " The iOS host authors three keys.")),

    ("N1-r9", "a registered N1 path is aimed at a count rule S1 already owns, so one number "
              "would have two derivations", "R38",
     lambda m: m["numericClaimContract"]["claims"][0].__setitem__(
         "path", m["crossPlatformSharingContract"]["recordCountClaimPaths"][0])),

    ("N1-r9", "the scan's stated bound is deleted, so it reads as a completeness claim",
     "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].__setitem__("knownBound", "")),

    ("N1-r9", "rule N1 points at the wrong gate", "R38",
     lambda m: m["numericClaimContract"].__setitem__("gate", "R37")),

    ("N1-r9", "an exclusion is retained for a phrase the document no longer contains", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"]["excludedPhrases"].append(
         {"phrase": "the allowlist holds four keys", "section": "9.1",
          "reason": "invented by a negative gate"})),

    ("N1-r9", "history is widened until a live section stops being scanned", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].__setitem__(
         "excludedDocSections", ["9", "10", "13"])),

    # ------------------------------------------------------------ r10, verdict 08 F1
    # Rule K3. The failure being gated is not "somebody grants an entitlement" — it is the
    # quieter one: a version-scoped fact restated as an invariant, so a required exception
    # is rejected as drift on a supported OS. Each mutation below is a way that could
    # happen again, and each must fail closed.

    ("F1-v08", "rule K1 loses the osFloorScope clause, so its sandbox-grant reasoning "
               "reads as version-independent again — the verdict-08 defect restored",
     "R29",
     lambda m: m["keychainScopeRule"].pop("osFloorScope")),

    ("F1-v08", "rule K1's floor clause stops pointing at the rule that owns the scope, "
               "leaving a recorded gap with no owner", "R29",
     lambda m: m["keychainScopeRule"].__setitem__(
         "osFloorScope", "The sandbox grant was read on one OS version. Noted.")),

    ("F1-v08", "the provider keychain row drops its osVersionScope, so the row and the "
               "rule disagree about whether the floor is covered", "R39",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].pop("osVersionScope")),

    ("F1-v08", "the floor is declared covered by the version the evidence was actually "
               "read on — the exact conflation verdict 08 named", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "unverifiedAtFloor", "macOS 26.5 (25F71) — read directly, so the floor is fine")),

    ("F1-v08", "rule K3 loses its resolution owner, so the floor gap belongs to nobody "
               "and reads as closed by having been written down", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "resolutionOwner", "the platform maintainer, at some point before release")),

    ("F1-v08", "the row's version scope is re-pointed at a different owner than the rule, "
               "so two artifacts name two owners and neither is accountable", "R39",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN]["osVersionScope"]
     .__setitem__("resolutionOwner", "TASK-260715-9yp8to")),

    ("F1-v08", "the keychain row's reopening condition drops rule K3, so the floor case "
               "reads as excluded by a condition that never considered it", "R39",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN].__setitem__(
         "reopensOnly", "Only if the macOS provider is ever moved out of root into a user "
                        "context, where the Data Protection Keychain exists.")),

    ("F1-v08", "the floor instruction re-grants the access group instead of arming the "
               "file exception — rule K1's deleted row returning through the back door",
     "R39",
     lambda m: target(m, "macos.provider")["entitlements"][KEYCHAIN]["osVersionScope"]
     .__setitem__("ifAbsentAtFloor",
                  f"Grant {KEYCHAIN} to macos.provider so it can reach the keychain.")),

    ("F1-v08", "the conditional register is deleted, so a floor-required exception has "
               "nowhere to be reviewed and arrives as unreviewed drift", "R39",
     lambda m: m["exceptionEntitlementRule"].pop("conditionalExceptions")),

    ("F1-v08", "the exception is armed in the contract instead of on the owner's floor "
               "evidence — least privilege lost to a field edit", "R39",
     lambda m: conditional(m).__setitem__("armed", True)),

    ("F1-v08", "the unarmed conditional row is quietly authored, so an exception nobody "
               "has justified enters the generated allowlist", "R39",
     lambda m: target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
         "status", "required-adjacent")),

    ("F1-v08", "the conditional entry is copied into the ACTIVE reviewed register, so the "
               "same exception is simultaneously granted and pending", "R39",
     # r12: the copy carries an `id` now, because an active entry without one is rejected by
     # R26 before the disjointness check is reached — and a mutation that fails for a shape
     # reason stops testing the rule it was written for.
     lambda m: m["exceptionEntitlementRule"]["reviewedExceptions"].append({
         "id": "X1-A2",
         "key": TEMP_FILE, "target": "macos.provider",
         "values": ["/Library/Keychains/"],
         "reason": "copied up by a negative gate",
         "reviewedIn": "2026-07-28.r10",
         "scope": "macos.provider only"})),

    ("F1-v08", "the arming condition is widened until a shipping third-party bundle would "
               "arm it — the reasoning rule K1 exists to refute", "R39",
     lambda m: conditional(m).__setitem__(
         "armingCondition", "Any evidence that a provider somewhere reaches "
                            "/Library/Keychains, including a shipping bundle carrying the "
                            "key.")),

    ("F1-v08", "the exception loses its value bound, so arming it would grant an unbounded "
               "path exception rather than the one path reviewed", "R39",
     lambda m: conditional(m).__setitem__("valuesIfArmed", [])),

    ("F1-v08", "arming is claimed to cost the ceremony a portal record, which would drag "
               "a signing-time entitlement into the human authorization scope", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__("ceremonyC1Impact", "one App ID")),

    ("F1-v08", "the pre-authorization is withdrawn, so a floor-required exception is "
               "unreviewed at the moment it becomes necessary and rule X1 rejects it",
     "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "ifGrantAbsentAtFloor", "Add the temporary file exception to macos.provider.")),

    ("F1-v08", "assertion A19 is dropped, so nothing at build time notices an unarmed "
               "exception appearing in a signed bundle", "R27",
     lambda m: drop_assertion(m, "A19")),

    ("F1-v08", "A19's scope shrinks to the one target that might later carry the key, "
               "leaving the other rows uninstructed", "R35",
     lambda m: escope(m, "AS-11").__setitem__("scopeTargets", ["macos.provider"])),

    # ------------------------------------------------------------ r11, verdict 09 F1
    # Every mutation in this block edits BOTH copies of the field, or edits the derivation
    # itself. That is the whole finding: r10 required the register entry and its row to
    # agree, so a coordinated edit passed. A mutation that changes only one copy would
    # have failed under r10 too and proves nothing about r11.

    ("F1-v09", "the reviewed path is widened to the filesystem root in BOTH the register "
               "and the row, so arming grants everything rather than the keychain store",
     "R39",
     lambda m: (conditional(m).__setitem__("valuesIfArmed", ["/"]),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "valuesIfArmed", ["/"]))),

    ("F1-v09", "the path is widened one level to /Library/ in both copies — an ANCESTOR "
               "of the reviewed path, so a banned-value list alone would miss it", "R39",
     lambda m: (conditional(m).__setitem__("valuesIfArmed", ["/Library/"]),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "valuesIfArmed", ["/Library/"]))),

    ("F1-v09", "the path is moved OUT of the reviewed subtree in both copies, so the "
               "exception grants a path the review never considered", "R39",
     lambda m: (conditional(m).__setitem__("valuesIfArmed", ["/private/var/db/mds/"]),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "valuesIfArmed", ["/private/var/db/mds/"]))),

    ("F1-v09", "a second path is appended to both copies, so one reviewed exception "
               "silently becomes two", "R39",
     lambda m: (conditional(m)["valuesIfArmed"].append("/private/var/db/mds/"),
                target(m, "macos.provider")["entitlements"][TEMP_FILE][
                    "valuesIfArmed"].append("/private/var/db/mds/"))),

    ("F1-v09", "developer-id is dropped from the armed channels in both copies, so the "
               "shipping provider stays broken on the OS the exception exists to fix",
     "R39",
     lambda m: (conditional(m).__setitem__("channelsIfArmed", ["development"]),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "channelsIfArmed", ["development"]))),

    ("F1-v09", "a channel the provider does not sign on is added to both copies", "R39",
     lambda m: (conditional(m).__setitem__(
                    "channelsIfArmed", ["development", "developer-id", "app-store"]),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "channelsIfArmed", ["development", "developer-id", "app-store"]))),

    ("F1-v09", "the arming owner drifts to an unrelated but REAL declared consumer, which "
               "is why a shape check on the element id could not see it", "R39",
     lambda m: (conditional(m).__setitem__("armedBy", "TASK-260715-9yp8to"),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "resolutionOwner", "TASK-260715-9yp8to"))),

    ("F1-v09", "the arming owner drifts to an element that is not a declared consumer, so "
               "rule D1 never checks that it exists on the board or runs after this "
               "contract", "R39",
     lambda m: (conditional(m).__setitem__("armedBy", "TASK-260715-000000"),
                target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
                    "resolutionOwner", "TASK-260715-000000"))),

    ("F1-v09", "rule K3's resolution owner moves while the register keeps the old one, so "
               "the evidence would be produced by one task and spent by another", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "resolutionOwner", "TASK-260715-9yp8to - the macOS probe lane reads the profile "
                            "while it is there anyway.")),

    ("F1-v09", "the entry and its row move together to macos.host, pre-authorizing a "
               "filesystem exception on a target nobody reviewed", "R39",
     lambda m: (conditional(m).__setitem__("target", "macos.host"),
                target(m, "macos.host")["entitlements"].__setitem__(
                    TEMP_FILE,
                    target(m, "macos.provider")["entitlements"].pop(TEMP_FILE)))),

    ("F1-v09", "a SECOND row claims the K3 version scope, so the entry's target stops "
               "being derivable from one place", "R39",
     lambda m: target(m, "macos.host")["entitlements"][KEYCHAIN].__setitem__(
         "osVersionScope", dict(target(m, "macos.provider")["entitlements"][KEYCHAIN][
             "osVersionScope"]))),

    ("F1-v09", "the exception family drifts to read-only in both copies, which would not "
               "reach the read-write transport the row exists for", "R39",
     lambda m: (conditional(m).__setitem__(
                    "key", "com.apple.security.temporary-exception.files.absolute-path.read-only"),
                target(m, "macos.provider")["entitlements"].__setitem__(
                    "com.apple.security.temporary-exception.files.absolute-path.read-only",
                    target(m, "macos.provider")["entitlements"].pop(TEMP_FILE)))),

    ("F1-v09", "rule K3's arming instruction stops naming the key it authorises, so the "
               "rule and the register would authorise different exceptions", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "ifGrantAbsentAtFloor",
         m["keychainSandboxFloorRule"]["ifGrantAbsentAtFloor"].replace(TEMP_FILE, "the "
                                                                      "file exception"))),

    ("F1-v09", "rule K3's arming instruction stops naming the reviewed path, so it would "
               "authorise whatever path the register happened to hold", "R39",
     lambda m: m["keychainSandboxFloorRule"].__setitem__(
         "ifGrantAbsentAtFloor",
         m["keychainSandboxFloorRule"]["ifGrantAbsentAtFloor"].replace(
             "/Library/Keychains", "the keychain directory"))),

    ("F1-v09", "the entry claims review in a revision this contract never issued", "R39",
     lambda m: conditional(m).__setitem__("reviewedIn", "2026-07-28.r99")),

    ("F1-v09", "the scope sentence is widened to a second target while the fields stay "
               "narrow, so the prose describes a grant the register does not", "R39",
     lambda m: conditional(m).__setitem__(
         "scopeIfArmed", "macos.provider and macos.host only, on their macOS channels. It "
                         "is granted to no iOS target and no probe target.")),

    ("F1-v09", "the scope sentence keeps the target and drifts the channel count", "R39",
     lambda m: conditional(m).__setitem__(
         "scopeIfArmed", conditional(m)["scopeIfArmed"].replace(
             "on its two macOS channels", "on its three macOS channels"))),

    ("F1-v09", "the derivation contract is deleted, so every field falls back to agreeing "
               "with its own mirror on the row — r10 restored", "R39",
     lambda m: m["exceptionEntitlementRule"].pop("conditionalExceptionDerivation")),

    ("F1-v09", "one field loses its derivation, so it is constrained by nothing while the "
               "contract still reads as complete", "R39",
     lambda m: m["exceptionEntitlementRule"]["conditionalExceptionDerivation"].__setitem__(
         "fields", [f for f in m["exceptionEntitlementRule"][
             "conditionalExceptionDerivation"]["fields"] if f["field"] != "valuesIfArmed"])),

    ("F1-v09", "a field's derivation is redefined as agreement with the target row, which "
               "is the check verdict 09 rejected, re-entering as a declaration", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "channelsIfArmed").__setitem__("boundKind", "equals-the-row-copy")),

    ("F1-v09", "the reviewed path is widened in the DERIVATION only, so the declared bound "
               "and the reviewed bound part company", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "valuesIfArmed").__setitem__("reviewedPath", "/Library/")),

    ("F1-v09", "the derivation raises the value ceiling, so a second path could be armed "
               "under a review that covered one", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "valuesIfArmed").__setitem__("maxValues", 2)),

    ("F1-v09", "the derivation stops banning the filesystem root", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "valuesIfArmed").__setitem__("bannedValues", ["/Library"])),

    ("F1-v09", "a second entry is registered on the same row, able to shadow the reviewed "
               "one on exactly the field under review", "R39",
     lambda m: m["exceptionEntitlementRule"]["conditionalExceptions"].append(
         dict(conditional(m), id="X1-C2"))),

    ("F1-v09", "the row stops naming the register entry, so a reader of the row alone "
               "cannot find the review that authorises it", "R39",
     lambda m: target(m, "macos.provider")["entitlements"][TEMP_FILE].__setitem__(
         "rationale", target(m, "macos.provider")["entitlements"][TEMP_FILE][
             "rationale"].replace("register entry X1-C1", "reviewed elsewhere"))),

    # ------------------------------------------------------------ r11, verdict 09 item 4
    # The count class. Rule N1 owned it since r9 and could not see either sentence: the
    # shape did not exist, and both sentences sat in regions the scan skipped.

    ("v09-4", "the declared harness count drifts from the harness, so the prose states a "
              "number no longer standing behind the gate", "R38",
     lambda m: m["numericClaimContract"]["harnessCounts"]["declaredCounts"].__setitem__(
         "R39", 9)),

    ("v09-4", "the harness-count register is deleted, so a mutation count goes back to "
              "being written by hand", "R38",
     lambda m: m["numericClaimContract"].pop("harnessCounts")),

    ("v09-4", "the declared harness-count shape is narrowed so it stops matching the "
              "sentences it exists for, while the rule still reads as covering them",
     "R38",
     lambda m: next(s for s in m["numericClaimContract"]["coverageScan"]["shapes"]
                    if s["id"] == "harness-count").__setitem__(
         "regex", r"\*{0,2}(<number-word>)\*{0,2}\s+negative\s+mutations\b")),

    ("v09-4", "the preamble is excluded from the scan again, which is where the stale "
              "count verdict 09 found had been sitting", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].__setitem__(
         "excludedDocSections", ["13", "preamble"])),

    ("v09-4", "the rule stops saying why the preamble is scanned, so a later revision "
              "reads the removed exclusion as an oversight", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].pop("preambleScanRule")),

    ("v09-4", "the singular shape field returns alongside the plural one, so one scan has "
              "two declarations to drift apart", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].__setitem__(
         "shape", r"\*{0,2}(<number-word>|\d+)\*{0,2}\s+keys?\b")),

    ("v09-4", "rule N1 stops naming the harness that recomputes its counts, so the "
              "numbers are hand-written again with an extra step", "R38",
     lambda m: m["numericClaimContract"]["harnessCounts"].__setitem__(
         "derivedBy", "The counts are kept up to date when the harness changes.")),

    ("v09-4", "a historical figure's exclusion is dropped, so the scan reports it as an "
              "unregistered live claim", "R38",
     lambda m: m["numericClaimContract"]["coverageScan"].__setitem__(
         "excludedPhrases",
         [p for p in m["numericClaimContract"]["coverageScan"]["excludedPhrases"]
          if "130 negative gates" not in p["phrase"]])),

    # ------------------------------------------------------- r12, verdict 10 F1 (rule X1-P)
    # reviewedIn stopped being a membership test. The first entry below is the reviewer's own
    # control, verbatim: r11 accepted it with 2805 checks and exit 0.

    ("F1-v10", "the reviewer's control — the conditional entry's review revision is moved to "
               "r2, which predates the conditional register entirely", "R39",
     lambda m: conditional(m).__setitem__("reviewedIn", "2026-07-28.r2")),

    ("F1-v10", "the review revision is moved to another real older revision, r3, in which the "
               "entry did not exist", "R39",
     lambda m: conditional(m).__setitem__("reviewedIn", "2026-07-28.r3")),

    ("F1-v10", "the review revision is moved FORWARD to the current one, claiming this "
               "revision reviewed an exception it inherited", "R39",
     lambda m: conditional(m).__setitem__("reviewedIn", m["revision"])),

    ("F1-v10", "a COORDINATED edit moves the label, the declared introduction and the "
               "introduction record together — the evidence is the chain, not the file", "R39",
     lambda m: (conditional(m).__setitem__("reviewedIn", "2026-07-28.r2"),
                provenance_entry(m, "X1-C1").__setitem__("introducedIn", "2026-07-28.r2"),
                revision_entry(m, "2026-07-28.r10").__setitem__("introduces", []),
                revision_entry(m, "2026-07-28.r2").__setitem__("introduces", ["X1-C1"]))),

    ("F1-v10", "the conditional entry's introduction record is dropped, so no revision claims "
               "to have introduced it", "R39",
     lambda m: revision_entry(m, "2026-07-28.r10").__setitem__("introduces", [])),

    ("F1-v10", "two revisions claim to introduce the same entry, so the record has an answer "
               "for every label a drifted entry could carry", "R39",
     lambda m: revision_entry(m, "2026-07-28.r2").__setitem__("introduces", ["X1-C1"])),

    ("F1-v10", "a revision claims to introduce an entry that is in neither register", "R39",
     lambda m: revision_entry(m, "2026-07-28.r7").__setitem__("introduces", ["X1-C9"])),

    ("F1-v10", "a revisionLog entry stops declaring `introduces` at all, leaving a hole "
               "exactly where a drifted entry would hide", "R39",
     lambda m: revision_entry(m, "2026-07-28.r10").pop("introduces")),

    ("F1-v10", "the provenance rule is deleted, so reviewedIn falls back to whatever the "
               "entry says it is — r11 restored", "R39",
     lambda m: m["exceptionEntitlementRule"].pop("exceptionReviewProvenance")),

    ("F1-v10", "the snapshot chain is emptied, so the only remaining evidence is the file "
               "making the claim", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "snapshotChain", [])),

    ("F1-v10", "the snapshot in which the entry is ABSENT is dropped from the chain, which "
               "would make it undecidable and demote it to attestation", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "snapshotChain", [c for c in m["exceptionEntitlementRule"][
             "exceptionReviewProvenance"]["snapshotChain"]
             if c["revision"] not in ("2026-07-28.r8", "2026-07-28.r9")])),

    ("F1-v10", "the chain stops at an older revision than the one this contract supersedes, "
               "so a bump could shorten the evidence without anyone noticing", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "snapshotChain", m["exceptionEntitlementRule"]["exceptionReviewProvenance"][
             "snapshotChain"][:-1])),

    ("F1-v10", "a snapshot's pinned digest is changed, so the chain would accept a baseline "
               "edited to manufacture an introduction", "R39",
     lambda m: next(c for c in m["exceptionEntitlementRule"]["exceptionReviewProvenance"][
         "snapshotChain"] if c["revision"] == "2026-07-28.r9").__setitem__(
             "sha256", "0" * 64)),

    ("F1-v10", "a declared snapshot points at a file that is not there; a chain that cannot "
               "be read must fail, never skip", "R39",
     lambda m: next(c for c in m["exceptionEntitlementRule"]["exceptionReviewProvenance"][
         "snapshotChain"] if c["revision"] == "2026-07-28.r9").__setitem__(
             "resource", "TASK-260715-ypo7yo_r9-baseline-missing.json")),

    ("F1-v10", "the entry is downgraded to the weaker attested class although the chain can "
               "decide it, which is how prose would replace a digest-pinned file", "R39",
     lambda m: provenance_entry(m, "X1-C1").update(
         {"evidenceClass": "summary-attested",
          "attestingLiteral": provenance_entry(m, "X1-C1")["key"]})),

    ("F1-v10", "the conditional entry loses its provenance entry, so it is unconstrained "
               "while rule X1-P still reads as covering both registers", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "entries", [e for e in m["exceptionEntitlementRule"]["exceptionReviewProvenance"][
             "entries"] if e["entry"] != "X1-C1"])),

    ("F1-v10", "reviewedIn's declared bound reverts to r11's known-revision, the bound "
               "verdict 10 rejected, re-entering as a declaration", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "reviewedIn").__setitem__("boundKind", "known-revision")),

    ("F1-v10", "the derivation prose stops pointing reviewedIn at rule X1-P, so the stated "
               "bound and the implemented one part company", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "reviewedIn").__setitem__(
             "derivedFrom", "a revision this contract has issued")),

    ("F1-v10", "the record of the bound r11 used and r12 rejected is dropped, so a reader "
               "finding known-revision in a diff cannot tell it was refused", "R39",
     lambda m: next(f for f in m["exceptionEntitlementRule"][
         "conditionalExceptionDerivation"]["fields"]
         if f["field"] == "reviewedIn").pop("supersededBound")),

    ("F1-v10", "rule X1-P names a gate for the conditional register that is not the rule "
               "verdict 10 required the control to land under", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"]["gates"].__setitem__(
         "conditionalExceptions", "R26")),

    ("F1-v10", "rule X1-P declares an evidence class this gate does not implement, which is a "
               "promise nothing keeps", "R39",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "evidenceClasses", ["snapshot-proven", "summary-attested", "owner-asserted"])),

    # the ACTIVE register — the half of the class no verdict reported, and the worse half:
    # r11 required only a non-empty string here, so it accepted a revision never issued.

    ("F1-v10", "the ACTIVE register entry's review revision is moved to r2, a real revision "
               "in which the Sparkle exception did not exist", "R26",
     lambda m: active(m).__setitem__("reviewedIn", "2026-07-28.r2")),

    ("F1-v10", "the ACTIVE register entry claims review in a revision this contract has never "
               "issued — accepted outright before r12", "R26",
     lambda m: active(m).__setitem__("reviewedIn", "2026-07-28.r99")),

    ("F1-v10", "the ACTIVE register entry loses its id, so no introduction record can name it",
     "R26",
     lambda m: active(m).pop("id")),

    ("F1-v10", "the ACTIVE register entry's introduction record is dropped", "R26",
     lambda m: revision_entry(m, "2026-07-28.r3").__setitem__("introduces", [])),

    ("F1-v10", "the ACTIVE entry attests on a literal that is not its own key, which could be "
               "chosen to match a convenient revision", "R26",
     lambda m: provenance_entry(m, "X1-A1").__setitem__(
         "attestingLiteral", "reviewed-exception register")),

    ("F1-v10", "the ACTIVE entry claims the strong snapshot class although it predates the "
               "oldest attached snapshot and the chain cannot decide it", "R26",
     lambda m: provenance_entry(m, "X1-A1").__setitem__("evidenceClass", "snapshot-proven")),

    ("F1-v10", "the ACTIVE entry loses its provenance entry entirely", "R26",
     lambda m: m["exceptionEntitlementRule"]["exceptionReviewProvenance"].__setitem__(
         "entries", [e for e in m["exceptionEntitlementRule"]["exceptionReviewProvenance"][
             "entries"] if e["entry"] != "X1-A1"])),
]

# r12: mutations of the EVIDENCE rather than the claim. The snapshot chain is the one input
# to rule X1-P that does not live in the contract, so a harness that only mutates the
# contract cannot show that tampering with a baseline fails closed. Each entry replaces one
# baseline in the sandbox; the attached resources are never touched.
SNAPSHOT_MUTATIONS = [
    ("F1-v10", "the r9 baseline is edited to contain the conditional entry, so the chain "
               "would derive an introduction two revisions early", "R39",
     "TASK-260715-ypo7yo_r9-baseline.json",
     lambda snap, base: snap["exceptionEntitlementRule"].__setitem__(
         "conditionalExceptions",
         copy.deepcopy(base["exceptionEntitlementRule"]["conditionalExceptions"]))),

    ("F1-v10", "the r10 baseline is edited to REMOVE the conditional entry, so the entry the "
               "chain proves was introduced in r10 would appear to arrive later", "R39",
     "TASK-260715-ypo7yo_r10-baseline.json",
     lambda snap, base: snap["exceptionEntitlementRule"].pop("conditionalExceptions")),

    ("F1-v10", "the r9 baseline is relabelled as a different revision, so a snapshot could "
               "stand in for one it is not", "R39",
     "TASK-260715-ypo7yo_r9-baseline.json",
     lambda snap, base: snap.__setitem__("revision", "2026-07-28.r7")),
]

# The furthest a single harness can push this: the baseline AND its pin move together, so the
# digest check passes and the DERIVATION has to catch it on its own. Kept separate because it
# mutates two artifacts at once and needs the digest recomputed after the edit.
COORDINATED_SNAPSHOT_MUTATIONS = [
    ("F1-v10", "the r9 baseline gains the conditional entry AND its pinned digest is "
               "recomputed to match, so only the derivation is left to notice", "R39",
     "TASK-260715-ypo7yo_r9-baseline.json",
     lambda snap, base: snap["exceptionEntitlementRule"].__setitem__(
         "conditionalExceptions",
         copy.deepcopy(base["exceptionEntitlementRule"]["conditionalExceptions"]))),
]

# Mutations of the RATIONALE document rather than the contract. R33 exists because the
# JSON can be corrected and the prose left asserting the superseded grant, one file over.
DOC_MUTATIONS = [
    ("F1-v05", "the rationale document keeps the r5 Keychain grant after the JSON is fixed",
     "R33",
     lambda doc: doc.replace(
         "granted to the iOS host and the iOS provider only, and to NO macOS target on",
         "granted only where functional: the iOS host and appex, and the macOS host, on")),

    # r10: this mutation used to hard-code the revision pair, so it silently stopped
    # applying the moment the contract moved — a negative gate that mutates nothing proves
    # nothing, which is the same defect class rule N1 exists for, one file over. It now
    # derives both ends from the contract and can never go stale again.
    ("F1-v05", "the rationale document is left at the superseded revision", "R33",
     lambda doc: doc.replace(f"revision **{CURRENT}**", f"revision **{SUPERSEDED}**")),

    # r8: the third stale claim, replayed. This is the row the document actually carried
    # into r7 — the r4 Keychain grant, still naming macos.host — which R33 could not see
    # because it renders grantClauses, not assertions.
    ("F1-v07", "the document's A6 row reverts to the r4 grant that still named macos.host",
     "R35",
     lambda doc: doc.replace(
         "`keychain-access-groups present only where status == required, which after r5 is "
         "ios.host and ios.provider alone`",
         "`keychain-access-groups` present only where status is `required` — `ios.host`, "
         "`ios.provider`, `macos.host`")),

    ("F1-v07", "the document drops A5's corrected scope clause", "R35",
     lambda doc: doc.replace(
         "PRESENT on the two PRODUCTION iOS bundles — the iOS host and the iOS provider —",
         "present on every iOS bundle")),

    ("F1-v07", "the document drops A18's scope clause, the half A5 hands off to", "R35",
     lambda doc: doc.replace(
         "com.apple.security.application-groups is ABSENT from both iOS probe bundles and "
         "no probe profile names an App Group",
         "the probe pair carries no App Group")),

    ("F2-v07", "the document drops A9b's deferral clause", "R36",
     lambda doc: doc.replace(
         "NO iOS development profile is created or checked at Ceremony C1: all four declare "
         "profiles[].development.devices as deferred under ADR-024",
         "iOS development profiles are deferred")),

    ("F2-v07", "the document drops A9a's macOS device clause", "R36",
     lambda doc: doc.replace(
         "every macOS development profile — the four Mac Development profiles, which are "
         "exactly the profiles Ceremony C1 authorizes — carries ProvisionedDevices "
         "containing this Mac",
         "macOS development profiles carry this Mac")),

    # ------------------------------------------------------- r9, rule N1 (self-found)
    # The class §9.1 records biting at r3: the prose number and the list beneath it
    # disagree. Both halves are now driven from the rows, so both must fail.
    ("N1-r9", "the §9.1 development count is bumped off the derived allowlist size", "R38",
     lambda doc: doc.replace("**eight** keys — **five authored**",
                             "**nine** keys — **five authored**")),

    ("N1-r9", "the §9.1 developer-id count drifts", "R38",
     lambda doc: doc.replace("minus `get-task-allow`:\n**seven**.",
                             "minus `get-task-allow`:\n**six**.")),

    ("N1-r9", "the §10.1 traceability row keeps a count the rows no longer support", "R38",
     lambda doc: doc.replace("allowlist is **eight** keys on `development`, **seven** on",
                             "allowlist is **nine** keys on `development`, **eight** on")),

    ("N1-r9", "a key r5 withdrew is left rendered in the §9.1 list while the count stays "
              "right — the r3 defect shape exactly", "R38",
     lambda doc: doc.replace(
         "com.apple.security.temporary-exception.mach-lookup.global-name\n"
         "                                                       authored (required-adjacent, r3)",
         "com.apple.security.temporary-exception.mach-lookup.global-name\n"
         "                                                       authored (required-adjacent, r3)\n"
         "keychain-access-groups                                 authored (required)")),

    ("N1-r9", "a key the rows DO author is dropped from the §9.1 list", "R38",
     lambda doc: doc.replace(
         "com.apple.security.network.client                      authored (required-adjacent)\n",
         "")),

    ("N1-r9", "an unregistered count claim is added to a scanned section", "R38",
     lambda doc: doc.replace(
         "## 7. Cross-platform sharing rules",
         "## 7. Cross-platform sharing rules\n\nThe iOS host authors four keys.")),

    ("N1-r9", "the r3 correction paragraph is 'fixed' to the current number, so the "
              "excluded phrase silently stops existing", "R38",
     lambda doc: doc.replace(
         'correction: r3\'s prose claimed "exactly seven keys" while the list beneath it\n'
         "held ten.",
         "correction: r3's prose was corrected.")),
]


# ------------------------------------------------------------------ r7, verdict 06 F1
# Mutations of the simulated BOARD RECORD rather than the contract. The r6 board gate was
# only ever run in the passing direction; these prove it fails closed. Each mutation takes
# the live records, corrupts the snapshot, and must make check-portal-consumer.py exit 1
# naming the rule whose consumer drifted.
#
# Signature: (finding, description, expected rule, mutation over {task_id: record}).
A1_TASK = json.loads(MATRIX.read_text())["authorizationNodeContract"]["task"]
P1_TASK = json.loads(MATRIX.read_text())["portalMutationTaskContract"]["task"]
# CURRENT and SUPERSEDED are read at the top of the file — the document mutations need them.


def edit(records, task, field, fn):
    records[task][field] = fn(records[task][field])
    return records


def edit_all(records, task, fn):
    """Apply an edit to every field the gate reads.

    A required phrase usually appears in more than one field, and the gate joins them, so
    a mutation that removes it from `scope` alone proves nothing: `ac` still satisfies the
    check. Removing it everywhere is what actually tests the rule.
    """
    for field in ("description", "scope", "ac"):
        if records[task].get(field):
            records[task][field] = fn(records[task][field])
    return records


BOARD_MUTATIONS = [
    ("F1-v06", "the r6 defect itself — the ceremony's scope is left at the superseded "
               "revision", "A1",
     lambda r: edit(r, A1_TASK, "scope", lambda s: s.replace(CURRENT, SUPERSEDED))),

    ("F1-v06", "the ceremony names a revision older than the one it was corrected from",
     "A1",
     lambda r: edit(r, A1_TASK, "scope", lambda s: s.replace(CURRENT, "2026-07-28.r2"))),

    ("F1-v06", "the revision label is dropped entirely rather than made stale", "A1",
     lambda r: edit(r, A1_TASK, "scope",
                    lambda s: s.replace(f" (revision {CURRENT})", ""))),

    ("F1-v06", "the ceremony carries the current revision AND a superseded one", "A1",
     lambda r: edit(r, A1_TASK, "scope",
                    lambda s: s + f" Supersedes the sitting planned for revision "
                                  f"{SUPERSEDED}.")),

    ("F1-v06", "the ceremony stops naming one of the four C1-authorized App IDs", "A1",
     lambda r: edit_all(r, A1_TASK,
                        lambda s: s.replace("works.relux.tunnel.probe.mac.tunnel",
                                            "the probe extension"))),

    ("F1-v06", "an excluded iOS App ID is turned into an authorized one", "A1",
     lambda r: edit(r, A1_TASK, "ac",
                    lambda s: s.replace("are explicitly NOT authorized because iOS is "
                                        "deferred under ADR-024",
                                        "are authorized as well under ADR-024"))),

    ("F1-v06", "the legacy identity keeps its clause but loses its negation", "A1",
     lambda r: edit(r, A1_TASK, "ac",
                    lambda s: s.replace("and works.relux.proxy is not touched",
                                        "and works.relux.proxy is migrated"))),

    ("F1-v06", "the Network Extensions capability stops being named", "A1",
     lambda r: edit_all(r, A1_TASK,
                        lambda s: s.replace("Network Extensions", "packet-tunnel"))),

    ("F1-v06", "the ADR-024 iOS deferral reference is dropped", "A1",
     lambda r: edit_all(r, A1_TASK,
                        lambda s: s.replace("ADR-024", "a later decision"))),

    ("F1-v06", "the profile class is widened past Mac Development", "A1",
     lambda r: edit_all(r, A1_TASK,
                        lambda s: s.replace("Mac Development", "signing"))),

    # the P1 consumer, now reachable by a negative gate for the first time
    ("F2-v05", "the portal task loses the phrase that negates the provider-only defect",
     "P1",
     lambda r: edit_all(r, P1_TASK, lambda s: s.replace("hosts included", "as needed"))),

    ("F2-v05", "a pre-r5 phrase returns to the portal task", "P1",
     lambda r: edit(r, P1_TASK, "ac",
                    lambda s: s + " The packet-tunnel entitlement appears only on provider "
                                  "identifiers.")),

    ("F2-v05", "the portal task names an unauthorized iOS App ID as something to create, "
               "at the end of a sentence — the boundary case r6 could not see", "P1",
     lambda r: edit(r, P1_TASK, "scope",
                    lambda s: s + " Also create works.relux.tunnel.ios.")),
]


# ------------------------------------------------------------------ r9, rule D1
# Mutations of the simulated DEPENDENCY GRAPH. D1's reachability half cannot be tested by
# corrupting the contract — the defect it catches lives entirely in the board's edges, which
# is exactly why eight revisions of a 1331-check validator never saw it. Each mutation takes
# the live graph, removes or redirects an edge, and must make the D1 block exit 1. No live
# edge is changed to test a gate.
#
# Signature: (finding, description, expected rule, mutation over {element_id: [blockedBy]}).
ME = json.loads(MATRIX.read_text())["owner"]
EXEMPT = json.loads(MATRIX.read_text())[
    "consumerDependencyContract"]["exemptions"][0]["element"]


def unlink(graph, element, blocker):
    before = list(graph[element])
    graph[element] = [b for b in before if b != blocker]
    if graph[element] == before:
        raise ValueError(f"{element} was not blocked by {blocker}; nothing to remove")
    return graph


GRAPH_MUTATIONS = [
    ("D1-r9", "the r9 defect itself — the edge added in r9 is removed, so the credential "
              "resolver, the snapshot loader and the profile-trust contract are all free to "
              "run before this matrix is accepted", "D1",
     lambda g: unlink(g, "TASK-260715-29ws8l", ME)),

    ("D1-r9", "the authorization node's own edge is cut, so the human ceremony is no longer "
              "ordered after the contract it authorizes", "D1",
     lambda g: unlink(g, "TASK-260728-q5kjta", ME)),

    # Both, not one. Cutting 3jloqy -> ypo7yo ALONE orphans nothing, because q5kjta also
    # blocks 3jloqy and carries its own edge here. That was written as a one-edge mutation
    # first and the gate correctly refused to fail; the premise was wrong, not the gate. It
    # is also the argument for a transitive CLOSURE rather than an edge check: the DAG has
    # redundant paths, so "is there an edge" and "does it run after" are different questions.
    ("D1-r9", "both edges carrying the portal chain are cut, orphaning the twelve consumers "
              "that reach this contract through it", "D1",
     lambda g: unlink(unlink(g, "TASK-260715-3jloqy", ME), "TASK-260728-q5kjta", ME)),

    ("D1-r9", "an edge is cut in the MIDDLE of a chain, so consumers with a direct-looking "
              "path lose it transitively", "D1",
     lambda g: unlink(g, "TASK-260715-1r0fxv", "TASK-260715-3jloqy")),

    ("D1-r9", "the exemption stops being upstream, so an unchecked consumer would be "
              "exempted on a claim nothing verifies", "D1",
     lambda g: unlink(g, ME, EXEMPT)),

    ("D1-r9", "the exemption is inverted — the upstream decision is made to depend on this "
              "contract instead", "D1",
     lambda g: (unlink(g, ME, EXEMPT), g.__setitem__(EXEMPT, g[EXEMPT] + [ME]), g)[-1]),

    ("D1-r9", "a declared consumer stops being a live board element", "D1",
     lambda g: (g.pop("TASK-260715-3f4lxy"), g)[-1]),
]


def run(matrix, rationale=None, snapshots=None):
    """Validate a mutated contract in a sandbox holding all three artifacts and the chain.

    r12: the sandbox now carries the per-revision BASELINES too. Rule X1-P derives the
    revision each X1 register entry was introduced in from those files, so a sandbox without
    them would make every provenance mutation fail for the wrong reason — a missing chain
    rather than the defect under test — and would prove nothing about either.

    `snapshots` maps a baseline resource name to a replacement object, so a mutation can
    corrupt the EVIDENCE as well as the claim. Nothing here touches the attached baselines.
    """
    snapshots = snapshots or {}
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        (d / "apple-identifier-entitlement-matrix.json").write_text(json.dumps(matrix, indent=2))
        (d / "validate_matrix.py").write_text(VALIDATOR.read_text())
        (d / "apple-identifier-entitlement-matrix.md").write_text(
            RATIONALE.read_text() if rationale is None else rationale)
        # the sandbox filesystem is CONSTANT — the baselines the unmutated contract declares.
        # A mutation that narrows the declared chain must fail against the evidence that is
        # actually there, which is the defect it models.
        for name in BASELINES:
            if name in snapshots:
                (d / name).write_text(json.dumps(snapshots[name], indent=2, ensure_ascii=False))
            else:
                (d / name).write_text(locate(name).read_text())
        r = subprocess.run([sys.executable, str(d / "validate_matrix.py")],
                           capture_output=True, text=True)
        return r.returncode, r.stdout


def snapshot_board():
    """Read both pinned consumers' live records once, for the board negative gates."""
    if REPO is None:
        return None, "no checkout containing .task-board was found above this script"
    records = {}
    for task in (A1_TASK, P1_TASK):
        query = f"get({task}) {{ id description scope ac checklist notes }}"
        p = subprocess.run(["task-board", "q", query], cwd=REPO,
                           capture_output=True, text=True)
        if p.returncode != 0:
            return None, f"task-board read of {task} failed (exit {p.returncode})"
        try:
            records[task] = json.loads(p.stdout)
        except json.JSONDecodeError as exc:
            return None, f"task-board read of {task} was not JSON ({exc})"
    return records, None


def failing_rules(out):
    """Which consumer rules the board gate reported FAIL for.

    The gate prints one block per consumer ('rule A1 — TASK-...'), so attribution is read
    per block rather than by grepping the whole run: a mutation to one consumer must not be
    credited by a failure in the other.
    """
    failing = set()
    current = None
    for line in out.splitlines():
        head = re.match(r"^rule (\S+) ", line)
        if head:
            current = head.group(1)
        elif current and line.startswith("  FAIL"):
            # indentation matters: the run's own trailing summary line also starts with
            # FAIL, and attributing it to the last block printed would credit every
            # mutation to whichever consumer happened to be reported second
            failing.add(current)
    return failing


def snapshot_graph():
    """Read the whole blockedBy graph once, for rule D1's negative gates."""
    if REPO is None:
        return None, "no checkout containing .task-board was found above this script"
    graph = {}
    for kind in ("task", "bug"):
        p = subprocess.run(["task-board", "q", f"list(type={kind}) {{ id blockedBy }}"],
                           cwd=REPO, capture_output=True, text=True)
        if p.returncode != 0:
            return None, f"task-board {kind} graph read failed (exit {p.returncode})"
        try:
            for element in json.loads(p.stdout):
                graph[element["id"]] = element.get("blockedBy") or []
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            return None, f"task-board {kind} graph read was unusable ({exc})"
    return graph, None


def run_board(records, graph):
    """Run the board gate against a simulated board and graph, never the live ones.

    Both are simulated on every run, including when only one is being mutated. That keeps
    each mutation ISOLATED — a graph mutation must fail D1 and nothing else — and it means
    the harness never depends on its own working directory to find the board.
    """
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        (d / "apple-identifier-entitlement-matrix.json").write_text(MATRIX.read_text())
        (d / "check-portal-consumer.py").write_text(BOARD_GATE.read_text())
        (d / "board.json").write_text(json.dumps(records))
        (d / "graph.json").write_text(json.dumps(graph))
        r = subprocess.run([sys.executable, str(d / "check-portal-consumer.py"),
                            "--simulate-board", str(d / "board.json"),
                            "--simulate-graph", str(d / "graph.json")],
                           capture_output=True, text=True)
        return r.returncode, r.stdout


def declared_count_check(base):
    """r11: the harness counts ITSELF and must agree with rule N1's declared counts.

    Reviewer verdict 09 item 4: the rationale said rule R39 stood on nine negative
    mutations while this harness held seventeen. The number was written by hand in a
    document, which is rule N1's own defect class — so the count is derived here, where
    the mutations actually live, and the validator then requires the prose to render the
    declared value. Neither half is sufficient alone: this check would let the prose go
    stale, and the validator's check would let this harness silently shrink underneath a
    number nobody re-derived.
    """
    declared = base["numericClaimContract"]["harnessCounts"]["declaredCounts"]
    actual = {}
    for _, _, rule_id, _ in MUTATIONS + DOC_MUTATIONS:
        actual[rule_id] = actual.get(rule_id, 0) + 1
    # r12: the snapshot mutations stand behind R39 too, so they are counted with the rest —
    # a count that silently excluded a harness would be the class rule N1 exists for.
    for _, _, rule_id, _, _ in SNAPSHOT_MUTATIONS + COORDINATED_SNAPSHOT_MUTATIONS:
        actual[rule_id] = actual.get(rule_id, 0) + 1
    bad = 0
    print("--- declared harness counts versus this harness (r11, rule N1) ---")
    for rule_id in sorted(declared):
        have = actual.get(rule_id, 0)
        ok = have == declared[rule_id]
        print(f"    {rule_id}: declared {declared[rule_id]}, harness holds {have} "
              f"{'OK' if ok else 'MISMATCH'}")
        if not ok:
            bad += 1
    return bad


def main():
    base = json.loads(MATRIX.read_text())

    code, out = run(base)
    print("--- positive gate ---")
    print(out.strip())
    print(f"positive exit={code}")
    if code != 0:
        print("BASELINE FAILS — negative gates are meaningless")
        return 1

    count_bad = declared_count_check(base)

    print("\n--- negative gates (each mutation must exit 1 naming its rule) ---")
    bad = 0
    for finding, desc, rule, mutate in MUTATIONS:
        m = copy.deepcopy(base)
        try:
            mutate(m)
        except Exception as exc:  # a mutation that cannot apply is itself a defect
            print(f"[{finding}] {desc}\n    MUTATION DID NOT APPLY: {exc}")
            bad += 1
            continue
        code, out = run(m)
        named = f"{rule}:" in out
        ok = code == 1 and named
        first = next((l.strip() for l in out.splitlines() if l.strip().startswith("- ")), "")
        print(f"[{finding}] {desc}")
        print(f"    expect {rule} -> exit={code} named={named} {'OK' if ok else 'GATE FAILED'}")
        print(f"    {first[:150]}")
        if not ok:
            bad += 1

    print("\n--- rationale-document gates (r6, R33) ---")
    doc_base = RATIONALE.read_text()
    for finding, desc, rule_id, mutate in DOC_MUTATIONS:
        doc = mutate(doc_base)
        if doc == doc_base:
            print(f"[{finding}] {desc}\n    MUTATION DID NOT APPLY (document unchanged)")
            bad += 1
            continue
        code, out = run(copy.deepcopy(base), rationale=doc)
        named = f"{rule_id}:" in out
        ok = code == 1 and named
        first = next((l.strip() for l in out.splitlines() if l.strip().startswith("- ")), "")
        print(f"[{finding}] {desc}")
        print(f"    expect {rule_id} -> exit={code} named={named} {'OK' if ok else 'GATE FAILED'}")
        print(f"    {first[:150]}")
        if not ok:
            bad += 1

    print("\n--- snapshot-evidence gates (r12, rule X1-P) ---")
    for finding, desc, rule_id, resource, mutate in SNAPSHOT_MUTATIONS:
        snapshot = json.loads(locate(resource).read_text())
        try:
            before = json.dumps(snapshot, sort_keys=True)
            mutate(snapshot, base)
            if json.dumps(snapshot, sort_keys=True) == before:
                raise ValueError("snapshot unchanged")
        except Exception as exc:
            print(f"[{finding}] {desc}\n    MUTATION DID NOT APPLY: {exc}")
            bad += 1
            continue
        code, out = run(copy.deepcopy(base), snapshots={resource: snapshot})
        named = f"{rule_id}:" in out
        ok = code == 1 and named
        first = next((l.strip() for l in out.splitlines() if l.strip().startswith("- ")), "")
        print(f"[{finding}] {desc}")
        print(f"    expect {rule_id} -> exit={code} named={named} {'OK' if ok else 'GATE FAILED'}")
        print(f"    {first[:150]}")
        if not ok:
            bad += 1

    for finding, desc, rule_id, resource, mutate in COORDINATED_SNAPSHOT_MUTATIONS:
        snapshot = json.loads(locate(resource).read_text())
        matrix = copy.deepcopy(base)
        try:
            before = json.dumps(snapshot, sort_keys=True)
            mutate(snapshot, base)
            if json.dumps(snapshot, sort_keys=True) == before:
                raise ValueError("snapshot unchanged")
            pin = next(c for c in matrix["exceptionEntitlementRule"][
                "exceptionReviewProvenance"]["snapshotChain"] if c["resource"] == resource)
            pin["sha256"] = hashlib.sha256(json.dumps(
                snapshot, sort_keys=True, separators=(",", ":"),
                ensure_ascii=False).encode("utf-8")).hexdigest()
        except Exception as exc:
            print(f"[{finding}] {desc}\n    MUTATION DID NOT APPLY: {exc}")
            bad += 1
            continue
        code, out = run(matrix, snapshots={resource: snapshot})
        named = f"{rule_id}:" in out
        ok = code == 1 and named
        first = next((l.strip() for l in out.splitlines() if l.strip().startswith("- ")), "")
        print(f"[{finding}] {desc}")
        print(f"    expect {rule_id} -> exit={code} named={named} {'OK' if ok else 'GATE FAILED'}")
        print(f"    {first[:150]}")
        if not ok:
            bad += 1

    print("\n--- board gates (r7 rules A1/P1 over records, r9 rule D1 over the graph) ---")
    board_total = 0
    board_base, err = snapshot_board()
    graph_base, graph_err = snapshot_graph()
    if board_base is None or graph_base is None:
        print(f"BOARD SNAPSHOT UNAVAILABLE: {err or graph_err}")
        print("the board negative gates could not run; this is a FAILURE, not a skip, "
              "because a gate that cannot run proves nothing")
        bad += 1
    else:
        code, out = run_board(copy.deepcopy(board_base), copy.deepcopy(graph_base))
        print(f"positive board gate exit={code}")
        if code != 0:
            print("BOARD BASELINE FAILS — board negative gates are meaningless")
            print(out.strip())
            bad += 1
        else:
            board_total = len(BOARD_MUTATIONS) + len(GRAPH_MUTATIONS)
            # (label, mutations, which half gets corrupted)
            rounds = (("record", BOARD_MUTATIONS, "board"),
                      ("graph", GRAPH_MUTATIONS, "graph"))
            for label, mutations, half in rounds:
                for finding, desc, rule_id, mutate in mutations:
                    records = copy.deepcopy(board_base)
                    graph = copy.deepcopy(graph_base)
                    subject = records if half == "board" else graph
                    try:
                        before = json.dumps(subject, sort_keys=True)
                        mutate(subject)
                        if json.dumps(subject, sort_keys=True) == before:
                            raise ValueError(f"{label} unchanged")
                    except Exception as exc:
                        print(f"[{finding}] {desc}\n    MUTATION DID NOT APPLY: {exc}")
                        bad += 1
                        continue
                    code, out = run_board(records, graph)
                    # the failure must be reported under the DRIFTED consumer's own rule,
                    # not merely somewhere in the run: a gate that fails the wrong consumer
                    # is not the gate this mutation is testing
                    named = failing_rules(out) == {rule_id}
                    ok = code == 1 and named
                    first = next((l.strip() for l in out.splitlines()
                                 if l.strip().startswith("- ")), "")
                    print(f"[{finding}] {desc}")
                    print(f"    expect {rule_id} -> exit={code} named={named} "
                          f"{'OK' if ok else 'GATE FAILED'}")
                    print(f"    {first[:150]}")
                    if not ok:
                        bad += 1

    total = (len(MUTATIONS) + len(DOC_MUTATIONS) + len(SNAPSHOT_MUTATIONS)
             + len(COORDINATED_SNAPSHOT_MUTATIONS) + board_total)
    print(f"\n{total - bad}/{total} negative gates hold")
    if count_bad:
        print(f"{count_bad} declared harness count(s) disagree with this harness")
    return 1 if (bad or count_bad) else 0


if __name__ == "__main__":
    sys.exit(main())
