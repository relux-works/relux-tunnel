# Fresh reviewer contract 04

Independently verify the one remaining rework-03 blocker and regression safety.

- Reproduce the exact before_publish/pre-stat race from reviewer-results-rework-03. Generation started with destination absent; create a foreign directory plus marker in before_publish. The operation must fail safely, preserve exact device/inode and marker, and clean only owned staging.
- Also reproduce the existing before_initial_publish/post-stat race, existing-bundle exchange/interruption cases, same-descriptor archive replacement, hostile metadata/oversize, and fdopen leak cases.
- Audit that initial destination state is captured without a path race and carried unambiguously into publication; no later stat may reclassify an initially absent destination into exchange.
- Run all 20 focused tests, formatter, deterministic/bundle/identity checks, unsigned Apple/provider gates, core/protocol gates, and broad Swift suite proportionately.
- Confirm no real VPN/signing/install/system-state operation.

Accept only on independent evidence and attach a new verdict artifact; otherwise return an exact reproduction to to-dev.