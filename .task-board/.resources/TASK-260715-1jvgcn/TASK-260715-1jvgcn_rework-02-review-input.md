# TASK-260715-1jvgcn review round 2 rework results

## Review defects addressed

1. Both peers decode and validate HEV records before any association lifecycle insertion.
2. The client drops unsolicited or closed relay datagrams without delivery or state creation and emits at most the bounded close policy response.
3. Relay outbound datagrams and generated association failures require an existing active client-owned association.
4. Fresh client-owned IDs consume injected association credit before insertion. A unique-ID flood over the limit receives finite `associationLimit` plus close responses without growing the lifecycle map or invoking cleanup.
5. Fully retired lifecycle entries are reusable and may be pruned for fresh credit only after both close directions were observed.

## Paired evidence

- Swift and Go cover malformed, protocol-oversized, and lowered-local-cap first datagrams with zero relay association cleanup.
- Swift and Go cover unsolicited and closed relay replies, valid opening after an unsolicited frame, and once-only owned cleanup.
- Swift and Go fill a two-association limit, reject IDs 3 through 8, reconcile error and close counters, retire ID 1, admit a reused ID, and reconcile terminal cleanup.
- Swift and Go enforce the same association limit on client-local admission.

## Validation

- Focused Swift session suite: 13 tests passed.
- Focused Go protocol suite: passed.
- Protocol gate: 53 tests in 5 suites passed.
- Full Swift suite: 163 tests in 17 suites passed.
- Go test and vet, Swift format lint, gofmt, diff check, and board validation passed.
