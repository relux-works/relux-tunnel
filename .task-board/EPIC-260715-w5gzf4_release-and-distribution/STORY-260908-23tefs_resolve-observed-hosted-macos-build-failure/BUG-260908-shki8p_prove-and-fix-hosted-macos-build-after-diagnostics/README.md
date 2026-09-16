# BUG-260908-shki8p: prove-and-fix-hosted-macos-build-after-diagnostics

## Description
Source repair of actual hosted Swift6.1 compiler failure: TunnelRuntimeCoordinator mapped generic result lacks Sendable. Source review/publication is this phase; mandatory final hosted green/landing proof is retained as open TASK-260908-34gi0y, not waived or claimed here.

## Scope
Observe real hosted macOS xcodebuild diagnostics; repair exact product/build/environment cause with narrow tests; retain independent review and signed PR delivery. No fake CI statuses, toolchain guessing, VPN activation, or weakened gates.

## Acceptance Criteria
Exact hosted compiler diagnostic and source/call-site analysis recorded; narrow safe source fix preserves runtime and cancellation; named regression/negative checks pass with local/minimum-toolchain distinctions explicit; independent source review before signed publication; original error resolved only after open TASK-260908-34gi0y proves actual hosted green and delivery.
