# ``ReluxTunnelMacOSAdapter``

The thin macOS Network Extension boundary from `architecture.md` and ADR-001.

`MacOSPacketFlowAdapter` translates only public `NEPacketTunnelFlow` packet
batches. `MacOSProviderCompositionRoot` injects that adapter and shared runtime
dependencies into `ReluxTunnelCore.TunnelProviderAdapter`. The concrete
`NEPacketTunnelProvider` subclass, network settings, stop-reason mapping, and
signed extension target belong to later provider and Gate P0 tasks.
