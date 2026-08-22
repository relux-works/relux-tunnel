# Independent review 02 focus

Verify the complete accepted scope, with primary focus on closure of the previous blocking finding.

- Independently prove that any extractor nonzero exit, missing/invalid `screenshots.json`, empty/outside PNG, missing expected step, or duplicate expected step makes the runtime row and aggregate build-host gate nonzero.
- Ensure the regression tests invoke the production smoke/extraction seam rather than merely duplicate its control flow.
- Re-run the positive focused contract/smoke and the negative injection gate; inspect the exact summary semantics.
- Reconfirm unsigned macOS build-only behavior and signed runtime ownership by `TASK-260822-3q4grm`; do not sign or launch native macOS runner/provider.
- Audit safety/privacy and all five revised ACs. Route exact changes to `to-dev`, or accepted evidence to `reviewing` pending orchestrator git confirmation.
