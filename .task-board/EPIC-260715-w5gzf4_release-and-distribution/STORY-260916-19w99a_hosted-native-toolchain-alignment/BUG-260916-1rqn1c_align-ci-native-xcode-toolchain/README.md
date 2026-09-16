# BUG-260916-1rqn1c: align-ci-native-xcode-toolchain

## Description
PR6 head d45c85d67b78b6578b5cb0821bd2e78217124d30 hosted run35091586150 passes macOS target builds, Swift tests and release build, then native packaging rejects Xcode16.4 build16F6 because NativeDependencies manifest pins17F42. Determine and implement smallest supported toolchain alignment preserving artifact provenance and strict validation.

## Scope
Hosted workflow and directly necessary native toolchain compatibility contracts; no unrelated product fixes, no VPN activation, no weakened checks

## Acceptance Criteria
A narrow reproducible fix has independent review, exact prospective PR composition identity, targeted validation and honest hosted validation requirements handed to parent; real hosted CI publication and landing are separate parent delivery obligations.
