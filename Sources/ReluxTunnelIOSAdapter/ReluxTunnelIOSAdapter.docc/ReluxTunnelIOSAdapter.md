# ``ReluxTunnelIOSAdapter``

The thin iOS Network Extension boundary from `architecture.md` and ADR-001.

`IOSPacketFlowAdapter` translates only public `NEPacketTunnelFlow` packet
batches. `IOSProviderCompositionRoot` injects that adapter and shared runtime
dependencies into `ReluxTunnelCore.TunnelProviderAdapter`. The concrete
`NEPacketTunnelProvider` subclass, network settings, stop-reason mapping, and
signed extension target belong to later provider and Gate P0 tasks.
