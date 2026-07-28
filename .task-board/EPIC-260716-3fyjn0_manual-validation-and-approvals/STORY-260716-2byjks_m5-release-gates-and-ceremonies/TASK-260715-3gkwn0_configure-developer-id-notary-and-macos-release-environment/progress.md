## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T03:03:32Z

## Last Update
2026-07-28T01:14:29Z

## Blocked By
- TASK-260715-1tzaed
- TASK-260715-2wjvlx
- TASK-260715-2ybl7y
- TASK-260715-apc34w
- TASK-260728-dveo1o

## Blocks
- TASK-260715-3sk5cd

## Checklist
- [ ] Deliver the stated scope while preserving every explicit non-scope boundary
- [ ] Verify every acceptance criterion with the specified automated or manual evidence
- [ ] Attach a TASK-260715-3gkwn0-scoped redacted outcome with commands, artifacts, and residual risks

## Notes
2026-07-28 replan (TASK-260728-3a2dnr): this task belongs to Ceremony C1, the single up-front human permission session on the current arm64 Mac. See the wave plan and ceremony script attached to TASK-260728-3a2dnr. Never request, echo, or persist secret values, key paths, or credential contents in board, repo, or logs.
Ceremony C1 banks the human half of this task: the operator authorizes notarytool to store a named App Store Connect credential profile in the login Keychain and authorizes Developer ID private-key access. The remaining CI/environment configuration stays gated on the macOS release identity contract and the CI trust contract. Record only the credential-profile NAME; never the key path, key id, issuer id, or key bytes.

## Precondition Resources
(none)

## Outcome Resources
(none)
