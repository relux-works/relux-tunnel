# BUG-260916-20xt79: fix-nwerror-wifiaware-xcode16-sdk-compatibility

## Description
Hosted run 35048178384 for PR6 head a46e2ba351a81e42f2907805b4cda2c313af7bd1 fails compiling MacOSSSHBootstrapErrorMapper.swift:37: NWError has no member wifiAware on Xcode 16.4 / Swift 6.1 / macOS SDK 15.5. The defect predates the last Sendable fix. Implement the smallest SDK-compatible error mapping correction, retain privacy-safe categories, validate applicable tests and prepare an independently reviewable delta. This task owns the new product correction; it must not require full PR6 landing or unrelated CI fixes for handoff.

## Scope
MacOSSSHBootstrapErrorMapper and directly relevant compatibility tests/documentation only. No VPN operations, routes, tooling edits, gate relaxation, unrelated fixes or publication before independent review.

## Acceptance Criteria
Declared older SDK compiles the mapper; current SDK retains intended error mapping and safe fallback behavior; focused checks pass and evidence distinguishes local toolchain from hosted proof; independent reviewer accepts exact candidate before composition into PR6.
