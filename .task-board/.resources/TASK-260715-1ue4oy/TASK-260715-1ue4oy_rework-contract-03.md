# Rework contract 03

Fix only the remaining before_publish/pre-stat race from TASK-260715-1ue4oy_reviewer-results-rework-03.md.

Carry the initial destination state/publication intent observed by generate_bundle into publish_staged_bundle. If generation began with destination absent, the entire publication attempt must use parent-descriptor-anchored atomic no-replace even if a later stat sees a path; a raced foreign directory must retain exact inode and marker while publication fails closed and owned staging is cleaned. Do not reinterpret the raced destination as a stale existing bundle or enter exchange.

Add the exact before_publish race regression in addition to the already-passing before_initial_publish/post-stat no-replace test. Preserve all 19 current tests, exchange/interruption recovery, same-descriptor archive bounds, and fd leak fixes. Rerun focused 20-test suite, formatting, deterministic/bundle checks, unsigned Apple/provider gates, core/protocol gates, and broad Swift suite. No real VPN state.