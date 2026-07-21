# Orchestrator runtime disposition

Date: 2026-07-21

Rosetta 2 is accepted as the approved emulated darwin/amd64 fixture for TASK-260715-24icoz AC3. This follows the task wording, which permits a baseline native or approved emulated fixture, and the accepted TASK-260715-2ywde4 review-03 evidence that independently exercised canonical identity, self-hash, protocol-v1 stdio, privacy-safe diagnostics, and clean exit under Rosetta.

This disposition is scoped to TASK-260715-24icoz. It does not claim native Intel coverage and does not remove any later release-CI or distribution validation row that explicitly requires native Intel hardware.

The task remains blocked only on:
1. native execution of the two declared Ubuntu 24.04 Linux fixtures or another explicitly approved equivalent; GitHub Actions run 29855573312 executed zero steps because of the account billing and spending gate;
2. an explicit total relay bundle budget in bytes. The measured four-executable total is 10,259,950 bytes and is evidence, not the policy value.

Do not infer either missing input or weaken AC3 or AC4.