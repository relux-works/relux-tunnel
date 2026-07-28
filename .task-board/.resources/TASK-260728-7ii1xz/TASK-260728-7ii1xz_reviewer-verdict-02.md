# TASK-260728-7ii1xz — reviewer verdict 02

Verdict: **ACCEPTED**.

The r2 decision artifact closes all three findings from reviewer verdict 01 and
meets the task acceptance criteria. The selected transport fits the macOS
root/user execution split: the containing app seeds a provider-owned,
system-domain file-based keychain item through the existing Network Extension
app-message channel; `startTunnel` reads the persisted item and does not depend
on the app being alive.

## Acceptance evidence

| requirement | reviewer finding |
| --- | --- |
| AC1 — exact open question and two Apple-sourced premise facts | Met in §§1–2. The question matches the task scope. TN3137 confirms that code outside a user context must use the file-based keychain and that access groups belong to the Data Protection Keychain; Apple DTS confirms the macOS system extension/root versus containing-app/user split and same-user limit for access-group sharing. |
| AC2 — at least three candidates across every required dimension, including what each cannot guarantee | Met in §4. Five candidates are compared on unattended start, lifetime/zeroization, compromise blast radius, entitlement/portal cost, and testability. Every candidate has an explicit `cannot guarantee` row. |
| AC3 — selection or complete blocker packet | Met in §5. Candidate D is selected with five ordered reasons. No human-only blocker remains. |
| AC4 — exact `works.relux.tunnel.mac.tunnel` amendment owned by `TASK-260715-ypo7yo` | Met in §7. `keychain-access-groups` changes from `prohibited-pending-decision` to settled `prohibited`; it has no literal value, no portal capability, and the stale `resolutionOwner` and `amendmentRule` are removed. `TASK-260715-ypo7yo` is named as applying owner. For `com.apple.security.application-groups`, both macOS targets keep the existing exact literal `group.works.relux.tunnel`; only the false shared-file-container purpose/traceability text changes to the `providerConfiguration` plus app-message channel. |
| AC5 — privacy-safe physical evidence and named limits | Met in §§3 and 7. Four logs record commands and per-step exit codes without real key material or passphrases. Root execution, signed-provider System-keychain write, root App Group resolution, launch-on-message, and disabled-configuration behavior are explicitly unproven and assigned as privacy-safe V1–V5 checks to the existing physical-Mac task. |
| AC6 — downstream assumptions | Met in §8 and on the board. `TASK-260715-379cpk`, `TASK-260715-1o9wjz`, `TASK-260715-29ws8l`, `TASK-260715-2hhh7x`, and `TASK-260715-3f4lxy` each carry a specific revised-assumption note and a dependency on this task. |

## Independent source and architecture review

- Apple TN3137 confirms the selected API model: file-based keychains use
  `SecAccess`; Data Protection Keychains use access groups;
  `SecItemAdd` is scoped with `kSecUseKeychain`; queries are scoped with
  `kSecMatchSearchList`.
- Apple’s `NETunnelProviderSession.sendProviderMessage` reference confirms:
  “If the extension is not running, it should be launched to handle the
  message.” Its documented immediate error set includes
  `NEVPNErrorConfigurationInvalid` and
  `NEVPNErrorConfigurationDisabled`. The revised five-state revocation
  contract is therefore evidence-based, and the unexecuted lifecycle claim is
  retained as physical verification V4 rather than assumed proven.
- Apple DTS thread 759976 confirms that an NE system extension is the exception
  to the normal sandbox prohibition on writing the System keychain and
  recommends app-to-daemon IPC followed by root-context persistence.
- The design preserves the project’s prohibition on secrets in
  `providerConfiguration`, App Group data, logs, and board resources. It
  explicitly records the macOS security downgrade relative to iOS: the
  System-keychain item is root-unlocked and is not protected by the user’s
  login password.
- The file-based `SecKeychain` / `SecAccess` compatibility surface is
  deprecated and the decisive signed-provider behaviors are not overclaimed;
  V1–V5 remain release gates on `TASK-260715-9yp8to`.

## Gates observed by this reviewer

| gate | observed result |
| --- | --- |
| `swift test` | exit **0**; 335 tests in 29 suites passed |
| `swiftc -O TASK-260728-7ii1xz_kcdomain.swift` | exit **0**; deprecation warnings only |
| compiled `kcdomain` probe | exit **0**; system-domain resolution `OSStatus=0`; search-list count 1; add/read/delete against a throwaway keychain all `OSStatus=0`; negative control `-25300`; throwaway keychain deleted |
| `zsh TASK-260728-7ii1xz_collect-evidence.sh` | exit **0**; shipping NE system extension observed at uid 0; sandbox and entitlement evidence reproduced; the expected root-container `ls` step recorded exit **1** |
| `task-board validate` while this leaf was `reviewing` | process exit **0**, but semantic gate **failed** with one `PARENT_STATUS_MISMATCH`: parent remained `analysis` while the child aggregate was `reviewing`. This is the same transient lifecycle mismatch identified in verdict 01 and must be rerun after verdict routing. |
| accepted verdict routing | `set_status(TASK-260728-7ii1xz, status=done)` exit **0**; no `commit_ack` supplied |
| `task-board validate` after verdict routing | exit **0**; `Board is valid. No issues found.` |

No product source, specification, matrix, portal state, or secret was changed by
this review. No Stop-The-Line condition exists.
