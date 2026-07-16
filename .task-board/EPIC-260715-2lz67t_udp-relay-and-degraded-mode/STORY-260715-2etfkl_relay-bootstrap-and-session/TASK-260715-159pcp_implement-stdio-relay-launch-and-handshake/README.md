# Implement stdio relay launch and validated session handshake

## Description
Launch the exact verified versioned relay through the selected authenticated SSH exec transport and promote it to a usable session only after stdout, stderr, protocol, build identity, feature, and limit validation.

## Scope
In scope: exact typed command for verified path; --stdio --protocol 1; exec channel deadline and cancellation; separate bounded stdout and stderr readers; protocol hello; build identity evidence; feature and max-frame result; startup generation; error mapping; no shell secrets; post-handshake session handle; cleanup on failure. Out of scope: upload or install, protocol codec internals, health scheduling after startup, UDP associations, reconnect across network paths, arbitrary environment variables, and accepting a different executable reported by remote output.

## Acceptance Criteria
1. Launch occurs only after authenticated SSH and verified atomic install and uses the exact quoted final path plus fixed stdio and protocol arguments with no profile secret or attacker-controlled shell fragment. 2. Framed stdout is parsed only by the protocol state machine, stderr is bounded and diagnostic-only, and any pre-handshake stdout contamination or stderr overflow fails startup. 3. Usable success requires matching protocol version, acceptable status, expected build identity, supported feature intersection, and safe negotiated maxFrame before the session is published. 4. Timeout, exec rejection, permission or noexec error, early EOF, incompatible version, identity mismatch, malformed hello, cancellation, and lane loss close process and channel ownership once with a stable capability reason. 5. Fake transport and controlled-host tests cover successful reuse and new install launch, every failure boundary, split hello, late callbacks, redaction, and repeated resource return to baseline.
