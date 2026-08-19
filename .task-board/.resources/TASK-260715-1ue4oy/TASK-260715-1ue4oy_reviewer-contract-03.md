# Fresh reviewer contract 03

Independently verify only the three prior blockers and regression safety; do not trust producer checklist or summary.

- Reproduce the initial-publication foreign-destination race and prove the foreign inode/marker survives while publish fails closed. Audit Darwin renameatx_np RENAME_EXCL and Linux renameat2 RENAME_NOREPLACE handling, parent-dir anchoring, unsupported-platform failure, and cleanup ownership.
- Prove archive hash, rewind, and bounded USTAR parse operate on the same O_NOFOLLOW descriptor. Reproduce pathname replacement/symlink and hostile PAX/oversize cases; audit all metadata/payload bounds.
- Inject fdopen failure into every conversion site and verify no descriptor leak; audit fchmod and close paths.
- Run all 19 focused tests, formatter, deterministic/bundle checks, exact identities, unsigned Apple graph/products, core/protocol gates, and broad Swift suite proportionately.
- Confirm build-host VPN prohibition.

Accept only if all three original reproduction programs now fail safely/pass their safety assertions and no new race/leak exists. Otherwise attach exact evidence and route to to-dev.