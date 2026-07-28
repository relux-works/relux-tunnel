# Ceremony C1, Approval A1, and every later human interaction

Revised 2026-07-28 (rework round 3) by `TASK-260728-3a2dnr`. Host: the current
Apple-silicon Mac (macOS 26.5, Xcode 26.5).

## What changed in round 3

Round 2 described C1 as one sitting, but the live graph did not agree: the four
grant-bearing tasks were ordered `apc34w` → {`3jloqy`, `dveo1o`}, so a
`max_parallel = 1` scheduler produced **two** human stops with a full
producer-reviewer cycle in between. The independent review rejected that.

C1 is now **one board node**, `TASK-260728-q5kjta`
*conduct-c1-apple-permission-ceremony* (ADR-028). It holds every up-front human
grant. The four evidence tasks it unblocks are ordinary agent work that runs
unattended with the granted access and keeps its full evidence obligations:

| task | what the agent does after C1, unattended |
| --- | --- |
| `TASK-260715-apc34w` | records account/organization readiness with the granted portal session |
| `TASK-260715-3jloqy` | performs the portal mutations, downloads and validates the profiles |
| `TASK-260728-dveo1o` | authenticates through the named notary profile alone and verifies the source-file disposition holds |
| `TASK-260717-ziprhs` | records the Sparkle public key, fingerprint, tool version and custody name |

`TASK-260728-q5kjta` is blocked only by `TASK-260715-ypo7yo` (the approved
identifier and entitlement matrix), so it is reachable inside the first
autonomous segment. It authorizes exactly what that matrix names — nothing more.

## Absolute rule

**No secret value ever leaves the Keychain.** Do not type into a shared context,
paste, echo, log, screenshot, or commit: private keys, certificate contents, App
Store Connect API key files or their paths, key IDs, issuer IDs, passphrases, or
Apple account credentials. The board, repo, shell history, CI logs, and
`providerConfiguration` record only **names, identifiers, expiry dates, and
pass/fail outcomes**.

Before any credential command in this ceremony:

```sh
setopt HIST_IGNORE_SPACE
set +x
```

and prefix each credential command with a leading space so zsh keeps it out of
history. If a command would print a secret, redirect it or use its
`--quiet`/`--output` form.

---

# Ceremony C1 — the up-front permission sitting

Already verified on this host, no re-confirmation needed:

- Relux Works **Apple Development** and **Developer ID Application** identities
  are present in the Keychain; Developer ID expires 2031.
- Existing Relux Works provisioning profiles carry **no** Network Extension
  entitlement, so tunnel identifiers and profiles must be created.
- The approved Git signing key is already loaded in `ssh-agent`.
- **No `notarytool` Keychain profile exists yet.** The notarization credential
  exists only as a mode-0600 source file, which does not satisfy the
  Keychain-only invariant (ADR-025).

## Step 1 — Keychain unlock and private-key access

Unlock the login keychain. When macOS prompts for access to the Apple
Development and Developer ID Application private keys, choose **Always Allow**
for the signing tools that will run unattended during the autonomous segments.

*Recorded:* identity common names, team identifier, expiry dates, which tools
were granted always-allow. No key material.

## Step 2 — Apple Developer portal authentication

Authenticate Xcode / the Apple Developer portal for the Relux Works team,
including two-factor if prompted.

*Recorded:* organization enrollment status required by App Review Guideline 5.4,
legal entity, team identifier, paid-program status, outstanding agreements, and
the operator's least-privilege role.

## Step 3 — Authorize macOS packet-tunnel identifiers and profiles

Authorize creation and download of exactly the macOS entries in the approved
matrix: host App ID, packet-tunnel extension App ID, the Network Extension
packet-tunnel provider capability, the App Group, the Keychain access group,
then the development provisioning profiles for both, including this Mac as a
registered device.

> The two iOS identifiers stay defined in the matrix and are deliberately **not**
> provisioned. iOS is deferred (ADR-024).

> **Residual interaction risk, stated rather than hidden:** if the portal forces
> a fresh two-factor prompt when `3jloqy` performs the mutation later, that is
> one extra short interaction. It cannot be pre-granted, and `3jloqy` records it
> instead of retrying silently.

## Step 4 — notarytool Keychain credential profile and source-file disposition

Two parts, both required (ADR-025):

1. Run `notarytool store-credentials` interactively to write a **named** profile
   into the login Keychain. The agent never receives the key file, its path, the
   key ID, or the issuer ID.
2. Choose and state a disposition for the source `.p8` file: migration into
   Keychain-backed custody, retention under a named custodian with documented
   access control, or secure destruction. A mode-0600 file lying around is
   **not** a compliant end state.

`TASK-260728-dveo1o` then proves, unattended, that the profile authenticates
using only its name and that the stated disposition actually holds. If it does
not, that task stays blocked — an unverified profile is never a ready
notarization path.

## Step 5 — Sparkle EdDSA keypair: generation and custody only

Generate the ed25519 keypair with the pinned Sparkle vendor tool. Place the
**private** key into the same custody as the Developer ID and notarization
credentials.

**Stop there.** `SUPublicEDKey` pinning, CI signing-secret binding, and appcast
sign/verify evidence belong to `TASK-260728-3bj9bk`, which is blocked by the
generated macOS target (`uyju7n` → `xempiv`) and the appcast pipeline
(`1mt4e7`) — none of which exist at C1. **An accepted key ceremony does not mean
self-update signing works** (ADR-026).

## Step 6 — Owner decision D1, same conversation

`TASK-260715-intsjz`: launch locales, copy ownership, fallback policy. It needs
no Mac access and becomes eligible at the same barrier as C1, so it is asked in
the same sitting to avoid a separate interruption. There is **no approved
default**; an agent must not choose launch locales.

## C1 exit criteria

- [ ] `TASK-260728-q5kjta` accepted `done`: every grant performed in one session,
      declines recorded as named blockers on the specific downstream task
- [ ] `git status` clean of any credential, profile, or key file
- [ ] Privacy scan of session notes, run logs, and shell history finds no secret
      value, key path, key ID, issuer ID, or account identifier
- [ ] `TASK-260715-intsjz` answered or explicitly deferred with its consequence
      (`1ets2m` stalls) accepted

---

# Approval A1 — one click, later

**Trigger.** `TASK-260715-1r0fxv` (disposable macOS packet-tunnel probe) has
been built by an agent and accepted by an independent reviewer. Only then does a
signed, correctly entitled probe exist to install.

**Human.** The probe installs a VPN configuration; macOS shows the system-VPN
approval dialog and, for a direct-distribution system extension, a System
Settings approval. Approve both. That is the entire human contribution to
`TASK-260715-9yp8to`, which then exercises manager save and reload, provider
launch, app↔provider messaging, repeated stop, host termination, uninstall and
reinstall, and captures privacy-safe unified logs — unattended.

**If the probe build fails**, it is ordinary rework on `1r0fxv` — do not call the
human. A1 is requested only when a reviewer-accepted probe is ready to install.

# Sign-off S1 — the Gate P0 verdict

`TASK-260715-2ayxqn` AC5 requires the accountable engineering or release owner
to acknowledge the verdict and the downstream tasks it unblocks or leaves
blocked. The report itself is agent-produced. This cannot be folded into A1: the
verdict does not exist until `9yp8to` has been produced and reviewed. The
physical-iPhone row is recorded as **deferred with iOS**, never as a failure and
never as a pass.

---

# After S1

The orchestrator runs **autonomous segment 3: 167 agent tasks in 26 waves**,
carrying the board from the M0 SSH matrix and engine selection through the
working macOS client, M2 relay/UDP, and M3 resilience, with no human input.

# Every later human interaction

| batch | node | what the human does |
| --- | --- | --- |
| H2 | `TASK-260715-3f4rhy` | approve the system VPN / system extension for the **real** app (its bundle identifier differs from the probe's, so A1 does not carry over) |
| D2 | `TASK-260715-35nc5m` | decide legacy SOCKS coexist / replace / retire |
| D3 | `TASK-260715-3mnqn8` | approve a fork of the vendored HEV dependency, only if the Instruments evidence justifies it |
| D4 | `TASK-260715-2gwfaw` | approve VPN privacy, retention, and support copy |
| R1 | `TASK-260717-1dsqnj` | ratify the four M1 runtime/routing/trust contracts |
| R2 | `TASK-260717-l639qp` | ratify the M3 policy and resilience contracts |
| L2 | `TASK-260715-151xf0` | dated legal/compliance review of the third-party notice set |
| S2 | `TASK-260715-1tzaed` | approve the macOS release identity/entitlement/migration contract |
| C2 | `TASK-260715-3gkwn0` | GitHub protected-environment secrets, reviewers, publication token scope |
| R3 | `TASK-260717-2d308k` | ratify the M5 release-governance contracts |
| H3 | `TASK-260715-1r48pc` | approve the Developer ID-signed candidate's system extension on a clean system |
| S3 | `TASK-260715-yynqbr` | declare the bad candidate and approve the promotion freeze in the rollback rehearsal |
| H4 | `TASK-260715-2aessv` | approve the extension on each clean acceptance system for the final distribution gate |

H2, D2, D3, D4, R1, R2 and L2 all become eligible at the same barrier, so they
are one interruption. The rest are separate because each waits on an artifact
the previous batch produces.
