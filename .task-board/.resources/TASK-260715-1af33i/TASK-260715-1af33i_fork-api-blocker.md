# TASK-260715-1af33i — ReluxNIOSSH fork API blocker

## Stop-the-line result

The accepted candidate-neutral contract and the reviewed ReluxNIOSSH fork do
not currently compose for three mandatory adapter clauses. Product-code work
stopped before adding a candidate downcast, private-key export, fake
keepalive, guessed negotiation result, or test-only fork access.

## Evidence

### 1. Opaque async credential signing cannot reach NIOSSH authentication

`Sources/ReluxTunnelCore/SSHContracts.swift:172-180` supplies an
`SSHPublicKeyCredential` as algorithm, public SSH key bytes, and an async
`sign(_:)` operation. The private key is deliberately absent.

ReluxNIOSSH's only public-key client offer is
`NIOSSHUserAuthenticationOffer.Offer.privateKey`; its public initializer
requires concrete `NIOSSHPrivateKey`
(`Dependencies/ReluxNIOSSH/Sources/NIOSSH/User Authentication/UserAuthenticationMethod.swift:193-214`).
The engine constructs the signable payload and invokes the concrete private
key synchronously inside the internal message initializer at lines 237-252.
There is no public external-signer offer or signature callback.

Therefore an adapter cannot implement approved public-key authentication from
the neutral credential without either leaking/downcasting a candidate type or
exporting private key material. Both conflict with the reviewed boundary.

### 2. Reply-requiring keepalive is not a public API

The only public global-request send method is
`NIOSSHHandler.sendTCPForwardingRequest`
(`Dependencies/ReluxNIOSSH/Sources/NIOSSH/NIOSSHHandler.swift:354-372`). The
generic `sendGlobalRequestMessage` at lines 374-383 is internal, and its
`SSHMessage.GlobalRequestMessage` input is also internal
(`Dependencies/ReluxNIOSSH/Sources/NIOSSH/SSHMessages.swift:191-203`).

The adapter consequently cannot send `keepalive@openssh.com` with a reply and
measure its RTT through supported production API. Encoding a global-request
packet outside NIOSSH would bypass its packet sequence, encryption, MAC, and
request-response ordering and is not a valid workaround.

### 3. Caller algorithm policy and exact negotiated algorithms are unavailable

The neutral configuration requires caller-owned KEX, host-key, cipher, and MAC
allowlists (`Sources/ReluxTunnelCore/SSHContracts.swift:416-436`), and the
session/snapshot must report exact negotiated values.

`SSHClientConfiguration` exposes delegates and transport-protection schemes
only (`Dependencies/ReluxNIOSSH/Sources/NIOSSH/SSHClientConfiguration.swift:15-52`).
KEX/host-key negotiation choices and `NegotiationResult` remain internal
(`Dependencies/ReluxNIOSSH/Sources/NIOSSH/Key Exchange/SSHKeyExchangeStateMachine.swift:603-622`),
with only a test-only internal host-key accessor at lines 640-655. No supported
snapshot/event reports exact KEX, host key, cipher, and MAC, and the client
cannot constrain KEX/host-key lists to the caller policy.

## Failed assumptions and rejected forced fits

- Public key bytes cannot reconstruct a private signing key.
- Downcasting `any SSHPublicKeyCredential` to an adapter-owned credential would
  violate candidate-neutral injection and fail ordinary core consumers.
- Treating a TCP-forwarding request as keepalive changes protocol semantics and
  can create remote listeners.
- Writing a raw global request beside NIOSSH would corrupt engine ownership of
  protected packet state.
- Inferring negotiated algorithms from configured capability lists is false
  whenever the peer selects another common algorithm.
- Importing internal or test-only symbols is explicitly forbidden.

## Viable options

1. **Recommended: extend TASK-260715-nzdzv3's minimal fork surface.** Add:
   - a public external public-key signer authentication offer whose asynchronous
     signature path accepts wire-format public key material without exporting a
     private key;
   - a public reply-observing keepalive/global-request operation with explicit
     request name and bounded payload, preserving request ordering and exposing
     reply completion;
   - caller-configurable KEX and host-key allowlists plus a public immutable
     negotiated-algorithm snapshot/event covering KEX, host key, cipher, and
     MAC.
   Keep all concrete NIOSSH values inside the adapter/fork boundary and add
   deterministic fork tests for each hook.
2. Revise the common credential and algorithm contracts. This is not
   recommended because it would weaken engine neutrality or require private-key
   export and would reopen an already reviewed contract.
3. Mark mandatory capabilities red and abandon this adapter. That contradicts
   this implementation task's requirement to implement the full contract and
   should be a later candidate-selection decision, not an adapter workaround.

## Exact resume condition

Resume TASK-260715-1af33i only after the ReluxNIOSSH fork provides reviewed
public APIs for all three gaps above (or the architecture owners explicitly
revise the common contract). The adapter can then implement and validate the
remaining lifecycle, channels, windows, rekey, cancellation, metrics, harness,
and Apple build paths without a forced fit.
