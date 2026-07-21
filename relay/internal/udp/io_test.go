package udp

import (
	"bytes"
	"context"
	"errors"
	"net"
	"net/netip"
	"os"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

func TestDatagramIONumericSendPreservesFamilyPortAndBytes(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 41, testLimits(2, 4, 2, 2))
	operations := newFakeDatagramOperations()
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, testIOLimits())

	tests := []struct {
		name    string
		id      uint32
		address protocol.DatagramAddress
		family  AddressFamily
		want    netip.Addr
	}{
		{
			name: "IPv4", id: 1,
			address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{192, 0, 2, 44}},
			family:  AddressFamilyIPv4, want: netip.MustParseAddr("192.0.2.44"),
		},
		{
			name: "IPv6", id: 2,
			address: protocol.DatagramAddress{
				Type:  protocol.AddressTypeIPv6,
				Bytes: netip.MustParseAddr("2001:db8::2a").AsSlice(),
			},
			family: AddressFamilyIPv6, want: netip.MustParseAddr("2001:db8::2a"),
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			payload := []byte{0x00, 0xff, byte(test.id)}
			result := datagramIO.Send(testContext(t), 41, test.id, protocol.Datagram{
				Endpoint: protocol.DatagramEndpoint{Address: test.address, Port: 8443},
				Data:     payload,
			})
			if result.Disposition != SendDispositionSent || result.Failure != nil || result.Family != test.family {
				t.Fatalf("send result = %#v", result)
			}
			call := operations.lastSend()
			if call.family != test.family || call.address != test.want || call.port != 8443 ||
				!bytes.Equal(call.payload, payload) {
				t.Fatalf("send call = %#v", call)
			}
		})
	}
	if got := factory.families(); len(got) != 2 || got[0] != AddressFamilyIPv4 || got[1] != AddressFamilyIPv6 {
		t.Fatalf("opened families = %#v", got)
	}
	counters := datagramIO.Counters()
	if counters.DatagramsSent != 2 || counters.BytesSent != 6 {
		t.Fatalf("counters = %#v", counters)
	}
}

func TestDatagramIODomainResolutionIsBoundedAndPolicyOrdered(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 42, testLimits(1, 2, 1, 1))
	resolver := &scriptedResolver{results: []netip.Addr{
		netip.MustParseAddr("2001:db8::1"),
		netip.MustParseAddr("192.0.2.1"),
		netip.MustParseAddr("192.0.2.2"),
		netip.MustParseAddr("2001:db8::2"),
	}}
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumResolverResults = 3
	limits.MaximumResolverBytes = 24
	limits.ResolverFamilyPolicy = ResolverIPv4ThenIPv6
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)

	result := sendAndAwait(t, datagramIO, testContext(t), 42, 7, protocol.Datagram{
		Endpoint: protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeDomain, Bytes: []byte("xn--bcher-kva.example.")},
			Port:    5353,
		},
		Data: []byte("opaque"),
	})
	if result.Disposition != SendDispositionSent || result.Family != AddressFamilyIPv4 {
		t.Fatalf("result = %#v", result)
	}
	if call := operations.lastSend(); call.address != netip.MustParseAddr("192.0.2.1") {
		t.Fatalf("selected address = %v", call.address)
	}
	if resolver.callCount() != 1 || resolver.lastNetwork() != "ip" || resolver.lastName() != "xn--bcher-kva.example." {
		t.Fatalf("resolver calls = %#v", resolver.snapshot())
	}
	if got := factory.families(); len(got) != 1 || got[0] != AddressFamilyIPv4 {
		t.Fatalf("families = %#v", got)
	}
	counters := datagramIO.Counters()
	if counters.ResolutionRequests != 1 || counters.MaximumResolutionBytes != 24 ||
		counters.ResolutionResultsDiscarded != 1 || counters.MaximumConcurrentResolution != 1 {
		t.Fatalf("resolution counters = %#v", counters)
	}
}

func TestDatagramIOResolverInspectionAndMemoryCapsAreIndependent(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 58, testLimits(1, 2, 1, 1))
	results := []netip.Addr{
		netip.MustParseAddr("2001:db8::1"),
		netip.MustParseAddr("192.0.2.9"),
	}
	for index := 0; index < 1000; index++ {
		results = append(results, netip.Addr{})
	}
	resolver := &scriptedResolver{results: results}
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumResolverResults = 2
	limits.MaximumResolverBytes = 4
	limits.ResolverFamilyPolicy = ResolverIPv4Only
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
	result := sendAndAwait(t, datagramIO, testContext(t), 58, 1, domainDatagram("bounded.example"))
	if result.Failure != nil || operations.lastSend().address != netip.MustParseAddr("192.0.2.9") {
		t.Fatalf("result=%#v send=%#v", result, operations.lastSend())
	}
	counters := datagramIO.Counters()
	if counters.MaximumResolutionBytes != 4 || counters.ResolutionResultsDiscarded != 1001 {
		t.Fatalf("counters = %#v", counters)
	}
}

func TestDatagramIOResolverFormValidationPrecedesResolverAndSocket(t *testing.T) {
	tests := []struct {
		name  string
		value []byte
	}{
		{"empty", nil},
		{"unicode", []byte{0xc3, 0xa9}},
		{"control", []byte{'a', 0, 'b'}},
		{"empty label", []byte("a..example")},
		{"leading hyphen", []byte("-a.example")},
		{"trailing hyphen", []byte("a-.example")},
		{"label too long", bytes.Repeat([]byte{'a'}, 64)},
		{"two terminal dots", []byte("a.example..")},
		{"numeric IPv4 text", []byte("192.0.2.1")},
		{"numeric IPv6 text", []byte("2001:db8::1")},
		{"empty A-label", []byte("xn--.example")},
		{"invalid A-label", []byte("xn--a-.example")},
		{"A-label decodes control", []byte("xn--a.example")},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, _, factory := newTestRegistry(t, 43, testLimits(1, 2, 1, 1))
			resolver := &scriptedResolver{results: []netip.Addr{netip.MustParseAddr("192.0.2.1")}}
			operations := newFakeDatagramOperations()
			datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, testIOLimits())
			result := datagramIO.Send(testContext(t), 43, 1, protocol.Datagram{
				Endpoint: protocol.DatagramEndpoint{
					Address: protocol.DatagramAddress{Type: protocol.AddressTypeDomain, Bytes: test.value},
					Port:    53,
				},
			})
			assertIOFailure(t, result.Failure, IOInvalidDatagram, protocol.UDPErrorCodeInvalidDatagram, false)
			if resolver.callCount() != 0 || operations.sendCount() != 0 || factory.openCount() != 0 {
				t.Fatalf("invalid input escaped resolver/socket gate")
			}
			if text := result.Failure.Error(); len(test.value) > 0 && bytes.Contains([]byte(text), test.value) {
				t.Fatalf("failure exposed destination input: %q", text)
			}
		})
	}
}

func TestDatagramIOResolverConcurrencyAndCancellation(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 44, testLimits(1, 2, 1, 1))
	resolver := newBarrierResolver()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	limits.MaximumQueuedResolver = 1
	datagramIO := mustDatagramIO(t, registry, resolver, newFakeDatagramOperations(), nil, limits)

	firstContext, cancelFirst := context.WithCancel(context.Background())
	firstPending := datagramIO.Send(firstContext, 44, 1, domainDatagram("one.example"))
	if firstPending.Disposition != SendDispositionPending {
		t.Fatalf("pending result = %#v", firstPending)
	}
	waitSignal(t, resolver.entered, "resolver entry")

	cancelFirst()
	first, ok := datagramIO.NextSendCompletion(testContext(t))
	if !ok {
		t.Fatal("missing cancelled resolver completion")
	}
	assertIOFailure(t, first.Failure, IOCancelled, 0, false)
	if factory.openCount() != 0 {
		t.Fatalf("cancelled resolution opened %d sockets", factory.openCount())
	}
	counters := datagramIO.Counters()
	if counters.ResolutionRequests != 1 || counters.MaximumConcurrentResolution != 1 ||
		counters.Cancelled != 1 {
		t.Fatalf("counters = %#v", counters)
	}
}

func TestDatagramIOPausedResolutionLifecycleRaces(t *testing.T) {
	tests := []struct {
		name   string
		reason IOFailureCode
		action func(*testing.T, *Registry, *fakeClock, SendResult, context.CancelFunc)
	}{
		{
			name: "association close", reason: IOStaleWork,
			action: func(t *testing.T, registry *Registry, _ *fakeClock, pending SendResult, _ context.CancelFunc) {
				if closed, failure := registry.CloseAssociation(testContext(t), pending.Token, CloseReasonRemote); failure != nil || !closed.Closed {
					t.Fatalf("close = %#v failure=%v", closed, failure)
				}
			},
		},
		{
			name: "idle expiry", reason: IOStaleWork,
			action: func(t *testing.T, registry *Registry, clock *fakeClock, pending SendResult, _ context.CancelFunc) {
				clock.advance(11 * time.Second)
				event := receiveEvent(t, registry.Events())
				if event.Kind != EventIdleExpired || event.Token != pending.Token {
					t.Fatalf("event = %#v", event)
				}
			},
		},
		{
			name: "generation replacement", reason: IOStaleWork,
			action: func(t *testing.T, registry *Registry, _ *fakeClock, _ SendResult, _ context.CancelFunc) {
				if failure := registry.ReplaceGeneration(testContext(t), 71, 72); failure != nil {
					t.Fatalf("replace generation: %v", failure)
				}
			},
		},
		{
			name: "caller cancellation", reason: IOCancelled,
			action: func(_ *testing.T, _ *Registry, _ *fakeClock, _ SendResult, cancel context.CancelFunc) {
				cancel()
			},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, clock, factory := newTestRegistry(t, 71, testLimits(1, 2, 1, 1))
			resolver := newPausedResolver(false)
			operations := newFakeDatagramOperations()
			limits := testIOLimits()
			limits.MaximumConcurrentResolver = 1
			datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			pending := datagramIO.Send(ctx, 71, 1, domainDatagram("paused.example"))
			if pending.Disposition != SendDispositionPending || pending.Token.Incarnation == 0 {
				t.Fatalf("pending = %#v", pending)
			}
			waitSignal(t, resolver.entered, "resolver entry")
			test.action(t, registry, clock, pending, cancel)
			close(resolver.release)
			completion, ok := datagramIO.NextSendCompletion(testContext(t))
			if !ok || completion.Failure == nil || completion.Failure.Code != test.reason {
				t.Fatalf("completion = %#v ok=%t", completion, ok)
			}
			if operations.sendCount() != 0 || factory.openCount() != 0 {
				t.Fatalf("stale resolution performed socket work: opens=%d sends=%d", factory.openCount(), operations.sendCount())
			}
			snapshot := mustSnapshot(t, registry)
			if snapshot.Associations != 0 || snapshot.Sockets != 0 || snapshot.Timers != 0 {
				t.Fatalf("registry resources = %#v", snapshot)
			}
			assertResolverBaseline(t, datagramIO, 1)
		})
	}
}

func TestDatagramIOPausedResolutionCannotAttachToReusedAssociation(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 73, testLimits(1, 2, 1, 1))
	resolver := newPausedResolver(false)
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)

	old := datagramIO.Send(context.Background(), 73, 1, domainDatagram("old.example"))
	waitSignal(t, resolver.entered, "resolver entry")
	if closed, failure := registry.CloseAssociation(testContext(t), old.Token, CloseReasonRemote); failure != nil || !closed.Closed {
		t.Fatalf("close old = %#v failure=%v", closed, failure)
	}
	reused := datagramIO.Send(testContext(t), 73, 1, ipv4Datagram([]byte("new")))
	if reused.Failure != nil || reused.Token.Incarnation == old.Token.Incarnation {
		t.Fatalf("reused = %#v old=%#v", reused, old)
	}
	close(resolver.release)
	completion, ok := datagramIO.NextSendCompletion(testContext(t))
	if !ok || completion.Failure == nil || completion.Failure.Code != IOStaleWork {
		t.Fatalf("old completion = %#v ok=%t", completion, ok)
	}
	if operations.sendCount() != 1 || factory.openCount() != 1 {
		t.Fatalf("reused socket work: opens=%d sends=%d", factory.openCount(), operations.sendCount())
	}
	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 1 || snapshot.Sockets != 1 || snapshot.Timers != 1 {
		t.Fatalf("reused resources = %#v", snapshot)
	}
	assertResolverBaseline(t, datagramIO, 1)
}

func TestDatagramIOResolverWorkersQueueAndMemoryAreBounded(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 74, testLimits(3, 6, 3, 3))
	resolver := newPausedResolver(true)
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	limits.MaximumQueuedResolver = 1
	limits.MaximumResolverNameBytes = 2 * protocol.MaxDomainWireBytes
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)

	first := datagramIO.Send(context.Background(), 74, 1, domainDatagram("one.example"))
	if first.Disposition != SendDispositionPending {
		t.Fatalf("first = %#v", first)
	}
	waitSignal(t, resolver.entered, "first resolver entry")
	second := datagramIO.Send(context.Background(), 74, 2, domainDatagram("two.example"))
	if second.Disposition != SendDispositionPending {
		t.Fatalf("second = %#v", second)
	}
	third := datagramIO.Send(context.Background(), 74, 3, domainDatagram("three.example"))
	assertIOFailure(t, third.Failure, IOResourceLimit, protocol.UDPErrorCodeResourceLimit, false)
	if third.Disposition != SendDispositionDropped {
		t.Fatalf("third = %#v", third)
	}
	snapshot := datagramIO.Snapshot()
	if snapshot.ResolverWorkers != 1 || snapshot.ActiveResolverJobs != 1 || snapshot.QueuedResolverJobs != 1 ||
		snapshot.CopiedResolverNameBytes != uint32(len("one.example")+len("two.example")) ||
		snapshot.CopiedResolverPayloadBytes != 2 {
		t.Fatalf("bounded scheduler snapshot = %#v", snapshot)
	}
	if resolver.callCount() != 1 || factory.openCount() != 0 || operations.sendCount() != 0 {
		t.Fatalf("rejected work escaped scheduler: resolver=%d opens=%d sends=%d", resolver.callCount(), factory.openCount(), operations.sendCount())
	}

	close(resolver.release)
	for range 2 {
		completion, ok := datagramIO.NextSendCompletion(testContext(t))
		if !ok || completion.Failure != nil || completion.Disposition != SendDispositionSent {
			t.Fatalf("completion = %#v ok=%t", completion, ok)
		}
	}
	if resolver.callCount() != 2 || operations.sendCount() != 2 {
		t.Fatalf("completed work: resolver=%d sends=%d", resolver.callCount(), operations.sendCount())
	}
	assertResolverBaseline(t, datagramIO, 1)
}

func TestDatagramIOCancelledQueuedResolutionNeverCallsResolver(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 78, testLimits(2, 4, 2, 2))
	resolver := newPausedResolver(true)
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	limits.MaximumQueuedResolver = 1
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
	first := datagramIO.Send(context.Background(), 78, 1, domainDatagram("active.example"))
	waitSignal(t, resolver.entered, "active resolver entry")
	queued := datagramIO.Send(context.Background(), 78, 2, domainDatagram("queued.example"))
	if first.Disposition != SendDispositionPending || queued.Disposition != SendDispositionPending {
		t.Fatalf("pending results: first=%#v queued=%#v", first, queued)
	}
	if closed, failure := registry.CloseAssociation(testContext(t), queued.Token, CloseReasonRemote); failure != nil || !closed.Closed {
		t.Fatalf("close queued = %#v failure=%v", closed, failure)
	}
	close(resolver.release)
	firstCompletion, ok := datagramIO.NextSendCompletion(testContext(t))
	if !ok || firstCompletion.Failure != nil || firstCompletion.Token != first.Token {
		t.Fatalf("first completion = %#v ok=%t", firstCompletion, ok)
	}
	queuedCompletion, ok := datagramIO.NextSendCompletion(testContext(t))
	if !ok || queuedCompletion.Token != queued.Token || queuedCompletion.Failure == nil ||
		queuedCompletion.Failure.Code != IOStaleWork {
		t.Fatalf("queued completion = %#v ok=%t", queuedCompletion, ok)
	}
	if resolver.callCount() != 1 || operations.sendCount() != 1 {
		t.Fatalf("cancelled queued work: resolver=%d sends=%d", resolver.callCount(), operations.sendCount())
	}
	assertResolverBaseline(t, datagramIO, 1)
}

func TestDatagramIORegistryShutdownStopsResolverWorkersAndReleasesJobs(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 75, testLimits(2, 4, 2, 2))
	resolver := newPausedResolver(true)
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	limits.MaximumQueuedResolver = 1
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
	first := datagramIO.Send(context.Background(), 75, 1, domainDatagram("one.example"))
	waitSignal(t, resolver.entered, "resolver entry")
	second := datagramIO.Send(context.Background(), 75, 2, domainDatagram("two.example"))
	if first.Disposition != SendDispositionPending || second.Disposition != SendDispositionPending {
		t.Fatalf("pending results: first=%#v second=%#v", first, second)
	}
	if failure := registry.Shutdown(testContext(t), 75, CloseReasonSessionLoss); failure != nil {
		t.Fatalf("shutdown: %v", failure)
	}
	waitDone(t, datagramIO.Done())
	snapshot := datagramIO.Snapshot()
	if !snapshot.Stopped || snapshot.ResolverWorkers != 0 || snapshot.ActiveResolverJobs != 0 ||
		snapshot.QueuedResolverJobs != 0 || snapshot.PendingResolverCompletions != 0 ||
		snapshot.CopiedResolverNameBytes != 0 || snapshot.CopiedResolverPayloadBytes != 0 ||
		snapshot.CopiedResolverResultBytes != 0 {
		t.Fatalf("shutdown scheduler resources = %#v", snapshot)
	}
	if factory.openCount() != 0 || operations.sendCount() != 0 {
		t.Fatalf("shutdown performed stale work: opens=%d sends=%d", factory.openCount(), operations.sendCount())
	}
}

func TestDatagramIOParentCancellationStopsResolverWorkers(t *testing.T) {
	parent, cancelParent := context.WithCancel(context.Background())
	clock := newFakeClock()
	factory := newFakeSocketFactory()
	registry, failure := NewRegistry(parent, 77, testLimits(1, 2, 1, 1), clock, factory)
	if failure != nil {
		t.Fatalf("registry: %v", failure)
	}
	resolver := newPausedResolver(true)
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumConcurrentResolver = 1
	limits.MaximumQueuedResolver = 1
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
	if pending := datagramIO.Send(context.Background(), 77, 1, domainDatagram("cancel.example")); pending.Disposition != SendDispositionPending {
		t.Fatalf("pending = %#v", pending)
	}
	waitSignal(t, resolver.entered, "resolver entry")
	cancelParent()
	waitDone(t, registry.Done())
	waitDone(t, datagramIO.Done())
	snapshot := datagramIO.Snapshot()
	if !snapshot.Stopped || snapshot.ResolverWorkers != 0 || snapshot.ActiveResolverJobs != 0 ||
		snapshot.QueuedResolverJobs != 0 || snapshot.PendingResolverCompletions != 0 ||
		snapshot.CopiedResolverNameBytes != 0 || snapshot.CopiedResolverPayloadBytes != 0 ||
		snapshot.CopiedResolverResultBytes != 0 {
		t.Fatalf("parent cancellation resources = %#v", snapshot)
	}
	if factory.openCount() != 0 || operations.sendCount() != 0 {
		t.Fatalf("parent cancellation performed stale work: opens=%d sends=%d", factory.openCount(), operations.sendCount())
	}
}

func TestDatagramIOResolverDeadlineFailureAndFamilyPolicies(t *testing.T) {
	t.Run("deadline", func(t *testing.T) {
		registry, _, factory := newTestRegistry(t, 54, testLimits(1, 2, 1, 1))
		resolver := newBarrierResolver()
		limits := testIOLimits()
		limits.ResolverTimeout = 20 * time.Millisecond
		datagramIO := mustDatagramIO(t, registry, resolver, newFakeDatagramOperations(), nil, limits)
		result := sendAndAwait(t, datagramIO, context.Background(), 54, 1, domainDatagram("timeout.example"))
		assertIOFailure(t, result.Failure, IOResolutionFailure, protocol.UDPErrorCodeResolutionFailure, false)
		if factory.openCount() != 0 || datagramIO.Counters().ResolutionFailures != 1 {
			t.Fatalf("deadline escaped resolver gate: sockets=%d counters=%#v", factory.openCount(), datagramIO.Counters())
		}
	})

	for _, test := range []struct {
		name    string
		policy  ResolverFamilyPolicy
		family  AddressFamily
		address netip.Addr
	}{
		{"IPv4 only", ResolverIPv4Only, AddressFamilyIPv4, netip.MustParseAddr("192.0.2.8")},
		{"IPv6 only", ResolverIPv6Only, AddressFamilyIPv6, netip.MustParseAddr("2001:db8::8")},
		{"IPv6 first", ResolverIPv6ThenIPv4, AddressFamilyIPv6, netip.MustParseAddr("2001:db8::8")},
	} {
		t.Run(test.name, func(t *testing.T) {
			registry, _, _ := newTestRegistry(t, 55, testLimits(1, 2, 1, 1))
			resolver := &scriptedResolver{results: []netip.Addr{
				netip.MustParseAddr("192.0.2.8"), netip.MustParseAddr("2001:db8::8"),
			}}
			operations := newFakeDatagramOperations()
			limits := testIOLimits()
			limits.ResolverFamilyPolicy = test.policy
			datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, limits)
			result := sendAndAwait(t, datagramIO, testContext(t), 55, 1, domainDatagram("policy.example"))
			if result.Failure != nil || result.Family != test.family || operations.lastSend().address != test.address {
				t.Fatalf("result=%#v send=%#v", result, operations.lastSend())
			}
		})
	}
}

func TestDatagramIORejectsInvalidOutboundBeforeResolverOrSocket(t *testing.T) {
	tests := []struct {
		name     string
		datagram protocol.Datagram
		code     IOFailureCode
		udp      protocol.UDPErrorCode
	}{
		{"zero port", protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}},
			},
		}, IOInvalidDatagram, protocol.UDPErrorCodeInvalidDatagram},
		{"short IPv4", protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{192, 0, 2}}, Port: 53,
			},
		}, IOInvalidDatagram, protocol.UDPErrorCodeInvalidDatagram},
		{"short IPv6", protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv6, Bytes: make([]byte, 15)}, Port: 53,
			},
		}, IOInvalidDatagram, protocol.UDPErrorCodeInvalidDatagram},
		{"unsupported family", protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressType(0xff), Bytes: []byte{1}}, Port: 53,
			},
		}, IOUnsupportedAddress, protocol.UDPErrorCodeUnsupportedAddress},
		{"local oversize", protocol.Datagram{
			Endpoint: ipv4Datagram(nil).Endpoint,
			Data:     bytes.Repeat([]byte{1}, int(protocol.MaxUDPPayloadFloor)+1),
		}, IODatagramTooLarge, protocol.UDPErrorCodeDatagramTooLarge},
		{"protocol oversize", protocol.Datagram{
			Endpoint: ipv4Datagram(nil).Endpoint,
			Data:     bytes.Repeat([]byte{1}, int(protocol.MaxUDPPayloadRelayHardCeiling)+1),
		}, IODatagramTooLarge, protocol.UDPErrorCodeDatagramTooLarge},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, _, factory := newTestRegistry(t, 56, testLimits(1, 2, 1, 1))
			resolver := &scriptedResolver{}
			operations := newFakeDatagramOperations()
			datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, testIOLimits())
			result := datagramIO.Send(testContext(t), 56, 1, test.datagram)
			assertIOFailure(t, result.Failure, test.code, test.udp, false)
			if resolver.callCount() != 0 || operations.sendCount() != 0 || factory.openCount() != 0 {
				t.Fatal("invalid datagram escaped validation gate")
			}
		})
	}
}

func TestDatagramIORejectsMappedIPv6BeforeAdmission(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 76, testLimits(1, 2, 1, 1))
	resolver := &scriptedResolver{results: []netip.Addr{netip.MustParseAddr("192.0.2.1")}}
	operations := newFakeDatagramOperations()
	datagramIO := mustDatagramIO(t, registry, resolver, operations, nil, testIOLimits())
	mapped := netip.MustParseAddr("::ffff:192.0.2.1").As16()
	result := datagramIO.Send(testContext(t), 76, 1, protocol.Datagram{
		Endpoint: protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv6, Bytes: mapped[:]},
			Port:    53,
		},
	})
	assertIOFailure(t, result.Failure, IOUnsupportedAddress, protocol.UDPErrorCodeUnsupportedAddress, false)
	if resolver.callCount() != 0 || factory.openCount() != 0 || operations.sendCount() != 0 {
		t.Fatalf("mapped address escaped preflight: resolver=%d opens=%d sends=%d", resolver.callCount(), factory.openCount(), operations.sendCount())
	}
	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 0 || snapshot.Sockets != 0 || snapshot.Timers != 0 {
		t.Fatalf("mapped address admitted state = %#v", snapshot)
	}
}

func TestSystemReceiveTruncationPrecedesUnsupportedSourceConversion(t *testing.T) {
	read, endpoint, truncated, err := receiveFromResult(
		int(protocol.MaxUDPPayloadFloor)+1,
		AddressFamilyIPv4,
		syscall.MSG_TRUNC,
		&syscall.SockaddrInet6{Port: 53, ZoneId: 9},
	)
	if err != nil || !truncated || read != int(protocol.MaxUDPPayloadFloor)+1 ||
		endpoint.Address.Type != 0 || endpoint.Port != 0 || len(endpoint.Address.Bytes) != 0 {
		t.Fatalf("truncated result: read=%d endpoint=%#v truncated=%t err=%v", read, endpoint, truncated, err)
	}
}

func TestDatagramIOSocketErrorMappingIsFinite(t *testing.T) {
	tests := []struct {
		name        string
		err         error
		code        IOFailureCode
		udp         protocol.UDPErrorCode
		disposition string
		retry       bool
	}{
		{"EAGAIN", syscall.EAGAIN, IOWouldBlock, protocol.UDPErrorCodeQueueSaturated, "retryReadiness", true},
		{"ENOBUFS", syscall.ENOBUFS, IOQueueSaturated, protocol.UDPErrorCodeQueueSaturated, "rejectDatagram", false},
		{"EMSGSIZE", syscall.EMSGSIZE, IODatagramTooLarge, protocol.UDPErrorCodeDatagramTooLarge, "rejectDatagram", false},
		{"unreachable", syscall.ENETUNREACH, IOSocketFailure, protocol.UDPErrorCodeSocketFailure, "closeAssociation", false},
		{"permission", syscall.EPERM, IOSocketFailure, protocol.UDPErrorCodeSocketFailure, "closeAssociation", false},
		{"closed", syscall.EBADF, IOSocketFailure, protocol.UDPErrorCodeSocketFailure, "closeAssociation", false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			failure := mapSocketError(test.err)
			if failure.Code != test.code || failure.UDPCode != test.udp ||
				failure.Disposition != test.disposition || failure.Retryable != test.retry {
				t.Fatalf("failure = %#v", failure)
			}
			text := failure.Error()
			if bytes.Contains([]byte(text), []byte(test.err.Error())) || bytes.Contains([]byte(text), []byte("192.0.2")) {
				t.Fatalf("raw error or address leaked: %q", text)
			}
		})
	}
}

func TestDatagramIORegistryErrorMappingIsFinite(t *testing.T) {
	tests := []struct {
		registry    ErrorCode
		code        IOFailureCode
		udp         protocol.UDPErrorCode
		scope       string
		disposition string
	}{
		{ErrorInvalidAssociationID, IOInvalidDatagram, protocol.UDPErrorCodeInvalidDatagram, "association", "closeAssociation"},
		{ErrorInvalidAddressFamily, IOUnsupportedAddress, protocol.UDPErrorCodeUnsupportedAddress, "association", "closeAssociation"},
		{ErrorAssociationLimit, IOResourceLimit, protocol.UDPErrorCodeAssociationLimit, "association", "rejectDatagram"},
		{ErrorSocketLimit, IOResourceLimit, protocol.UDPErrorCodeResourceLimit, "association", "rejectDatagram"},
		{ErrorUnknownAssociation, IOAssociationClosed, protocol.UDPErrorCodeUnknownOrClosedAssociation, "association", "closeAssociation"},
		{ErrorStaleGeneration, IOStaleWork, 0, "association", "drop"},
		{ErrorRegistryClosed, IOStaleWork, 0, "session", "drop"},
		{ErrorCancelled, IOCancelled, 0, "session", "closeSession"},
		{ErrorOperationFailure, IOSocketFailure, protocol.UDPErrorCodeSocketFailure, "association", "closeAssociation"},
	}
	for _, test := range tests {
		failure := mapRegistryFailure(&RegistryError{Code: test.registry})
		if failure.Code != test.code || failure.UDPCode != test.udp || failure.Scope != test.scope ||
			failure.Disposition != test.disposition || failure.Retryable {
			t.Fatalf("registry code %s mapped to %#v", test.registry, failure)
		}
	}
}

func TestDatagramIOSendPressureAndTerminalCleanup(t *testing.T) {
	tests := []struct {
		name         string
		err          error
		disposition  SendDisposition
		code         IOFailureCode
		associations uint32
	}{
		{"would block", syscall.EAGAIN, SendDispositionRetryReadiness, IOWouldBlock, 1},
		{"queue saturated", syscall.ENOBUFS, SendDispositionDropped, IOQueueSaturated, 1},
		{"unreachable", syscall.EHOSTUNREACH, SendDispositionFailed, IOSocketFailure, 0},
		{"permission", syscall.EACCES, SendDispositionFailed, IOSocketFailure, 0},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, _, _ := newTestRegistry(t, 45, testLimits(1, 2, 1, 1))
			operations := newFakeDatagramOperations()
			operations.sendError = test.err
			datagramIO := mustDatagramIO(t, registry, nil, operations, nil, testIOLimits())
			result := datagramIO.Send(testContext(t), 45, 1, ipv4Datagram([]byte{1, 2, 3}))
			if result.Disposition != test.disposition || result.Failure == nil || result.Failure.Code != test.code {
				t.Fatalf("result = %#v", result)
			}
			if snapshot := mustSnapshot(t, registry); snapshot.Associations != test.associations {
				t.Fatalf("snapshot = %#v", snapshot)
			}
		})
	}
}

func TestDatagramIONumericOutboundActivityRequiresSuccessfulSend(t *testing.T) {
	tests := []struct {
		name        string
		sendError   error
		disposition SendDisposition
		code        IOFailureCode
		refreshes   bool
		closes      bool
	}{
		{name: "success", disposition: SendDispositionSent, refreshes: true},
		{name: "would block", sendError: syscall.EAGAIN, disposition: SendDispositionRetryReadiness, code: IOWouldBlock},
		{name: "queue saturated", sendError: syscall.ENOBUFS, disposition: SendDispositionDropped, code: IOQueueSaturated},
		{name: "terminal failure", sendError: syscall.EHOSTUNREACH, disposition: SendDispositionFailed, code: IOSocketFailure, closes: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, clock, _ := newTestRegistry(t, 80, testLimits(1, 2, 1, 1))
			operations := newFakeDatagramOperations()
			datagramIO := mustDatagramIO(t, registry, nil, operations, clock, testIOLimits())
			opened := datagramIO.Send(testContext(t), 80, 1, ipv4Datagram([]byte("open")))
			if opened.Failure != nil {
				t.Fatalf("open = %#v", opened)
			}
			initialDeadline := clock.Now().Add(10 * time.Second)
			assertActivityTimer(t, clock, initialDeadline, 2)

			clock.advance(4 * time.Second)
			operations.setSendError(test.sendError)
			// Switching families exercises existing-association socket admission:
			// opening the IPv6 socket must not itself count as activity.
			result := datagramIO.Send(testContext(t), 80, 1, ipv6Datagram([]byte("next")))
			if result.Disposition != test.disposition {
				t.Fatalf("result = %#v", result)
			}
			if test.code == "" {
				if result.Failure != nil {
					t.Fatalf("unexpected failure = %#v", result.Failure)
				}
			} else if result.Failure == nil || result.Failure.Code != test.code {
				t.Fatalf("failure = %#v, want %s", result.Failure, test.code)
			}

			snapshot := mustSnapshot(t, registry)
			switch {
			case test.closes:
				if snapshot.Associations != 0 || snapshot.Sockets != 0 || clock.activeTimers() != 0 || clock.timerCount() != 2 {
					t.Fatalf("terminal send refreshed before close: snapshot=%#v timers=%d active=%d", snapshot, clock.timerCount(), clock.activeTimers())
				}
			case test.refreshes:
				assertActivityTimer(t, clock, clock.Now().Add(10*time.Second), 3)
			default:
				assertActivityTimer(t, clock, initialDeadline, 2)
			}
			if snapshot.Associations != 0 {
				if closed, failure := registry.CloseAssociation(testContext(t), result.Token, CloseReasonLocal); failure != nil || !closed.Closed {
					t.Fatalf("close = %#v failure=%v", closed, failure)
				}
			}
			assertRegistryBaseline(t, registry, clock)
		})
	}
}

func TestDatagramIOResolvedDomainOutboundActivityRequiresSuccessfulSend(t *testing.T) {
	tests := []struct {
		name        string
		sendError   error
		disposition SendDisposition
		code        IOFailureCode
		refreshes   bool
		closes      bool
	}{
		{name: "success", disposition: SendDispositionSent, refreshes: true},
		{name: "would block", sendError: syscall.EAGAIN, disposition: SendDispositionRetryReadiness, code: IOWouldBlock},
		{name: "queue saturated", sendError: syscall.ENOBUFS, disposition: SendDispositionDropped, code: IOQueueSaturated},
		{name: "terminal failure", sendError: syscall.EACCES, disposition: SendDispositionFailed, code: IOSocketFailure, closes: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, clock, _ := newTestRegistry(t, 81, testLimits(1, 2, 1, 1))
			resolver := &scriptedResolver{results: []netip.Addr{netip.MustParseAddr("2001:db8::81")}}
			operations := newFakeDatagramOperations()
			limits := testIOLimits()
			limits.ResolverFamilyPolicy = ResolverIPv6Only
			datagramIO := mustDatagramIO(t, registry, resolver, operations, clock, limits)
			opened := datagramIO.Send(testContext(t), 81, 1, ipv4Datagram([]byte("open")))
			if opened.Failure != nil {
				t.Fatalf("open = %#v", opened)
			}
			initialDeadline := clock.Now().Add(10 * time.Second)
			assertActivityTimer(t, clock, initialDeadline, 2)

			clock.advance(4 * time.Second)
			operations.setSendError(test.sendError)
			result := sendAndAwait(t, datagramIO, testContext(t), 81, 1, domainDatagram("activity.example"))
			if result.Disposition != test.disposition {
				t.Fatalf("result = %#v", result)
			}
			if test.code == "" {
				if result.Failure != nil {
					t.Fatalf("unexpected failure = %#v", result.Failure)
				}
			} else if result.Failure == nil || result.Failure.Code != test.code {
				t.Fatalf("failure = %#v, want %s", result.Failure, test.code)
			}

			snapshot := mustSnapshot(t, registry)
			switch {
			case test.closes:
				if snapshot.Associations != 0 || snapshot.Sockets != 0 || clock.activeTimers() != 0 || clock.timerCount() != 2 {
					t.Fatalf("terminal resolution send refreshed before close: snapshot=%#v timers=%d active=%d", snapshot, clock.timerCount(), clock.activeTimers())
				}
			case test.refreshes:
				assertActivityTimer(t, clock, clock.Now().Add(10*time.Second), 3)
			default:
				assertActivityTimer(t, clock, initialDeadline, 2)
			}
			if snapshot.Associations != 0 {
				if closed, failure := registry.CloseAssociation(testContext(t), result.Token, CloseReasonLocal); failure != nil || !closed.Closed {
					t.Fatalf("close = %#v failure=%v", closed, failure)
				}
			}
			assertResolverBaseline(t, datagramIO, 2)
			assertRegistryBaseline(t, registry, clock)
		})
	}
}

func TestDatagramIOResolverFailureAndCancellationDoNotRefreshExistingActivity(t *testing.T) {
	t.Run("resolver failure", func(t *testing.T) {
		registry, clock, _ := newTestRegistry(t, 82, testLimits(1, 2, 1, 1))
		resolver := &scriptedResolver{err: errors.New("synthetic resolver failure")}
		datagramIO := mustDatagramIO(t, registry, resolver, newFakeDatagramOperations(), clock, testIOLimits())
		opened := datagramIO.Send(testContext(t), 82, 1, ipv4Datagram([]byte("open")))
		initialDeadline := clock.Now().Add(10 * time.Second)
		assertActivityTimer(t, clock, initialDeadline, 2)
		clock.advance(4 * time.Second)

		result := sendAndAwait(t, datagramIO, testContext(t), 82, 1, domainDatagram("failure.example"))
		assertIOFailure(t, result.Failure, IOResolutionFailure, protocol.UDPErrorCodeResolutionFailure, false)
		if result.Token != opened.Token || clock.timerCount() != 2 || clock.activeTimers() != 0 {
			t.Fatalf("resolver failure refreshed activity: result=%#v timers=%d active=%d", result, clock.timerCount(), clock.activeTimers())
		}
		assertResolverBaseline(t, datagramIO, 2)
		assertRegistryBaseline(t, registry, clock)
	})

	t.Run("caller cancellation", func(t *testing.T) {
		registry, clock, _ := newTestRegistry(t, 83, testLimits(1, 2, 1, 1))
		resolver := newBarrierResolver()
		datagramIO := mustDatagramIO(t, registry, resolver, newFakeDatagramOperations(), clock, testIOLimits())
		opened := datagramIO.Send(testContext(t), 83, 1, ipv4Datagram([]byte("open")))
		initialDeadline := clock.Now().Add(10 * time.Second)
		assertActivityTimer(t, clock, initialDeadline, 2)
		clock.advance(4 * time.Second)

		ctx, cancel := context.WithCancel(context.Background())
		pending := datagramIO.Send(ctx, 83, 1, domainDatagram("cancelled.example"))
		if pending.Disposition != SendDispositionPending || pending.Token != opened.Token {
			t.Fatalf("pending = %#v", pending)
		}
		waitSignal(t, resolver.entered, "resolver entry")
		cancel()
		result, ok := datagramIO.NextSendCompletion(testContext(t))
		if !ok {
			t.Fatal("cancelled completion unavailable")
		}
		assertIOFailure(t, result.Failure, IOCancelled, 0, false)
		if clock.timerCount() != 2 || clock.activeTimers() != 0 {
			t.Fatalf("cancellation refreshed activity: timers=%d active=%d", clock.timerCount(), clock.activeTimers())
		}
		assertResolverBaseline(t, datagramIO, 2)
		assertRegistryBaseline(t, registry, clock)
	})
}

func TestDatagramIORejectsScopedResolverIPv6BeforeCreditOrSocketAdmission(t *testing.T) {
	scoped := netip.MustParseAddr("fe80::1%scope")
	t.Run("only scoped result", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 84, testLimits(1, 2, 1, 1))
		resolver := &scriptedResolver{results: []netip.Addr{scoped}}
		operations := newFakeDatagramOperations()
		datagramIO := mustDatagramIO(t, registry, resolver, operations, clock, testIOLimits())
		result := sendAndAwait(t, datagramIO, testContext(t), 84, 1, domainDatagram("scoped.example"))
		assertIOFailure(t, result.Failure, IOResolutionFailure, protocol.UDPErrorCodeResolutionFailure, false)
		counters := datagramIO.Counters()
		if counters.ResolutionResultsDiscarded != 1 || counters.MaximumResolutionBytes != 0 ||
			factory.openCount() != 0 || operations.sendCount() != 0 {
			t.Fatalf("scoped result escaped gate: counters=%#v opens=%d sends=%d", counters, factory.openCount(), operations.sendCount())
		}
		assertResolverBaseline(t, datagramIO, 2)
		assertRegistryBaseline(t, registry, clock)
	})

	t.Run("falls back to later unzoned result", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 85, testLimits(1, 2, 1, 1))
		unzoned := netip.MustParseAddr("2001:db8::85")
		resolver := &scriptedResolver{results: []netip.Addr{scoped, unzoned}}
		operations := newFakeDatagramOperations()
		limits := testIOLimits()
		limits.MaximumResolverResults = 2
		limits.ResolverFamilyPolicy = ResolverIPv6Only
		datagramIO := mustDatagramIO(t, registry, resolver, operations, clock, limits)
		result := sendAndAwait(t, datagramIO, testContext(t), 85, 1, domainDatagram("fallback.example"))
		if result.Failure != nil || result.Family != AddressFamilyIPv6 {
			t.Fatalf("result = %#v", result)
		}
		call := operations.lastSend()
		if call.address != unzoned || call.address.Zone() != "" || call.family != AddressFamilyIPv6 {
			t.Fatalf("fallback send rewrote endpoint = %#v", call)
		}
		counters := datagramIO.Counters()
		if counters.ResolutionResultsDiscarded != 1 || counters.MaximumResolutionBytes != 16 ||
			factory.openCount() != 1 || operations.sendCount() != 1 {
			t.Fatalf("fallback bounds: counters=%#v opens=%d sends=%d", counters, factory.openCount(), operations.sendCount())
		}
		if closed, failure := registry.CloseAssociation(testContext(t), result.Token, CloseReasonLocal); failure != nil || !closed.Closed {
			t.Fatalf("close = %#v failure=%v", closed, failure)
		}
		assertResolverBaseline(t, datagramIO, 2)
		assertRegistryBaseline(t, registry, clock)
	})

	if err := (systemSocketOperations{}).SendTo(-1, AddressFamilyIPv6, scoped, 53, nil); !errors.Is(err, syscall.EAFNOSUPPORT) {
		t.Fatalf("system scoped-address preflight = %v", err)
	}
}

func TestDatagramIOReceivePreservesSourceAndResponseRecord(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 46, testLimits(2, 4, 2, 2))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnSocketVisits = 2
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, limits)
	v4 := datagramIO.Send(testContext(t), 46, 1, ipv4Datagram([]byte("open4")))
	v6 := datagramIO.Send(testContext(t), 46, 2, ipv6Datagram([]byte("open6")))
	if v4.Failure != nil || v6.Failure != nil {
		t.Fatalf("open failures v4=%#v v6=%#v", v4, v6)
	}

	sources := []protocol.DatagramEndpoint{
		{Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{198, 51, 100, 7}}, Port: 5300},
		{Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv6, Bytes: netip.MustParseAddr("2001:db8::7").AsSlice()}, Port: 5301},
	}
	operations.enqueue(v4.Token, v4.Family, fakeReceive{source: sources[0], payload: []byte{0x00, 0xff, 0x04}})
	operations.enqueue(v6.Token, v6.Family, fakeReceive{source: sources[1], payload: []byte{0x00, 0xff, 0x06}})
	sink := &captureReplySink{}
	turn := datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{
		{Token: v4.Token, Family: v4.Family},
		{Token: v6.Token, Family: v6.Family},
	}, sink)
	if turn.DatagramsRead != 2 || turn.RepliesEmitted != 2 || turn.Dropped != 0 {
		t.Fatalf("turn = %#v", turn)
	}
	replies := sink.repliesSnapshot()
	if len(replies) != 2 {
		t.Fatalf("replies = %#v", replies)
	}
	codec, failure := protocol.NewDatagramCodec(protocol.MaxUDPPayloadRelayDefault)
	if failure != nil {
		t.Fatal(failure)
	}
	for index, reply := range replies {
		record, encodeFailure := codec.Encode(reply.datagram)
		if encodeFailure != nil {
			t.Fatal(encodeFailure)
		}
		decoded, decodeFailure := codec.Decode(record)
		if decodeFailure != nil {
			t.Fatal(decodeFailure)
		}
		if !endpointsEqual(decoded.Endpoint, sources[index]) ||
			!bytes.Equal(decoded.Data, []byte{0x00, 0xff, byte(4 + index*2)}) {
			t.Fatalf("reply %d changed: %#v", index, decoded)
		}
	}
}

func TestDatagramIOReceiveOversizeTruncationAndReceiverStallAreBoundedDrops(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 47, testLimits(1, 2, 1, 1))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnDatagrams = 4
	limits.MaximumTurnSocketVisits = 4
	limits.MaximumTurnBytes = uint32(limits.MaximumPayloadBytes+1) * 4
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, limits)
	opened := datagramIO.Send(testContext(t), 47, 1, ipv4Datagram([]byte("open")))
	target := ReceiveTarget{Token: opened.Token, Family: opened.Family}
	source := protocol.DatagramEndpoint{
		Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{203, 0, 113, 9}},
		Port:    9000,
	}
	operations.enqueue(opened.Token, opened.Family,
		fakeReceive{source: source, payload: bytes.Repeat([]byte{1}, int(limits.MaximumPayloadBytes)+1)},
		fakeReceive{
			source: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressType(0xff), Bytes: []byte{1}},
			},
			payload: []byte{2}, truncated: true,
		},
		fakeReceive{source: source, payload: []byte{3}},
		fakeReceive{err: syscall.EAGAIN},
	)
	sink := &captureReplySink{replyDisposition: ReplyQueueSaturated}
	turn := datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{target}, sink)
	if turn.DatagramsRead != 3 || turn.RepliesEmitted != 0 || turn.Dropped != 3 || turn.SocketVisits != 4 {
		t.Fatalf("turn = %#v", turn)
	}
	if len(sink.repliesSnapshot()) != 1 {
		t.Fatalf("sink should observe only the bounded non-oversized reply")
	}
	counters := datagramIO.Counters()
	if counters.OversizedReplyDropped != 2 || counters.QueueSaturatedDropped != 1 ||
		counters.DatagramsReceived != 3 {
		t.Fatalf("counters = %#v", counters)
	}
	if snapshot := mustSnapshot(t, registry); snapshot.Associations != 1 || snapshot.Sockets != 1 {
		t.Fatalf("truncated unsupported source closed association = %#v", snapshot)
	}
}

func TestDatagramIOReceiveSocketFailureClosesAssociationOnce(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 59, testLimits(1, 2, 1, 1))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnSocketVisits = 1
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, limits)
	opened := datagramIO.Send(testContext(t), 59, 1, ipv4Datagram(nil))
	operations.enqueue(opened.Token, opened.Family, fakeReceive{err: syscall.ECONNREFUSED})
	sink := &captureReplySink{}
	turn := datagramIO.ReceiveTurn(
		testContext(t),
		[]ReceiveTarget{{Token: opened.Token, Family: opened.Family}},
		sink,
	)
	failures := sink.failuresSnapshot()
	if turn.Dropped != 1 || len(failures) != 1 || failures[0].Code != IOSocketFailure {
		t.Fatalf("turn=%#v failures=%#v", turn, failures)
	}
	if snapshot := mustSnapshot(t, registry); snapshot.Associations != 0 || snapshot.Sockets != 0 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	if factory.totalCloseCalls() != 1 || datagramIO.Counters().SocketFailures != 1 {
		t.Fatalf("closeCalls=%d counters=%#v", factory.totalCloseCalls(), datagramIO.Counters())
	}
}

func TestDatagramIOReadinessMissDoesNotRefreshAssociationActivity(t *testing.T) {
	registry, clock, _ := newTestRegistry(t, 48, testLimits(1, 2, 1, 1))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnSocketVisits = 1
	datagramIO := mustDatagramIO(t, registry, nil, operations, clock, limits)
	opened := datagramIO.Send(testContext(t), 48, 1, ipv4Datagram(nil))
	clock.advance(9 * time.Second)
	operations.enqueue(opened.Token, opened.Family, fakeReceive{err: syscall.EAGAIN})
	datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{{Token: opened.Token, Family: opened.Family}}, &captureReplySink{})
	clock.advance(time.Second)
	event := receiveEvent(t, registry.Events())
	if event.Kind != EventIdleExpired || event.Token != opened.Token {
		t.Fatalf("event = %#v", event)
	}
}

func TestDatagramIOReceiveTurnIsRoundRobinAndBudgeted(t *testing.T) {
	registry, clock, _ := newTestRegistry(t, 49, testLimits(3, 6, 3, 3))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnTargets = 6
	limits.MaximumTurnDatagrams = 2
	limits.MaximumTurnSocketVisits = 2
	limits.MaximumTurnBytes = uint32(limits.MaximumPayloadBytes+1) * 2
	datagramIO := mustDatagramIO(t, registry, nil, operations, clock, limits)
	targets := make([]ReceiveTarget, 0, 3)
	for id := uint32(1); id <= 3; id++ {
		opened := datagramIO.Send(testContext(t), 49, id, ipv4Datagram([]byte{byte(id)}))
		target := ReceiveTarget{Token: opened.Token, Family: opened.Family}
		targets = append(targets, target)
		operations.enqueue(opened.Token, opened.Family,
			fakeReceive{source: testSourceEndpoint(), payload: []byte{byte(id), 1}},
			fakeReceive{source: testSourceEndpoint(), payload: []byte{byte(id), 2}},
		)
	}
	sink := &captureReplySink{}
	first := datagramIO.ReceiveTurn(testContext(t), targets, sink)
	second := datagramIO.ReceiveTurn(testContext(t), targets, sink)
	if first.StopReason != TurnStopDatagramLimit || second.StopReason != TurnStopDatagramLimit {
		t.Fatalf("stops first=%#v second=%#v", first, second)
	}
	replies := sink.repliesSnapshot()
	if len(replies) != 4 {
		t.Fatalf("replies = %#v", replies)
	}
	want := []byte{1, 2, 3, 1}
	for index, reply := range replies {
		if reply.datagram.Data[0] != want[index] {
			t.Fatalf("fair order %d = %d, want %d", index, reply.datagram.Data[0], want[index])
		}
	}

	operations.advanceClock = clock
	operations.advanceDuration = 2 * time.Millisecond
	timeLimits := testIOLimits()
	timeLimits.MaximumTurnTargets = 6
	timeLimits.MaximumTurnDatagrams = 10
	timeLimits.MaximumTurnSocketVisits = 10
	timeLimits.MaximumTurnBytes = uint32(timeLimits.MaximumPayloadBytes+1) * 10
	timeLimits.MaximumTurnDuration = 3 * time.Millisecond
	timedIO := mustDatagramIO(t, registry, nil, operations, clock, timeLimits)
	for _, target := range targets {
		operations.enqueue(target.Token, target.Family, fakeReceive{source: testSourceEndpoint(), payload: []byte{9}})
	}
	timed := timedIO.ReceiveTurn(testContext(t), targets, &captureReplySink{})
	if timed.StopReason != TurnStopTimeLimit || timed.SocketVisits != 2 || timed.DatagramsRead != 2 {
		t.Fatalf("timed turn = %#v", timed)
	}
}

func TestDatagramIOReceiveTurnByteAndCancellationBudgets(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 57, testLimits(1, 2, 1, 1))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnDatagrams = 10
	limits.MaximumTurnSocketVisits = 10
	limits.MaximumTurnBytes = uint32(limits.MaximumPayloadBytes+1) * 2
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, limits)
	opened := datagramIO.Send(testContext(t), 57, 1, ipv4Datagram(nil))
	target := ReceiveTarget{Token: opened.Token, Family: opened.Family}
	for index := 0; index < 3; index++ {
		operations.enqueue(opened.Token, opened.Family, fakeReceive{
			source: testSourceEndpoint(), payload: bytes.Repeat([]byte{byte(index)}, int(limits.MaximumPayloadBytes)),
		})
	}
	turn := datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{target}, &captureReplySink{})
	if turn.StopReason != TurnStopByteLimit || turn.DatagramsRead != 2 ||
		turn.BytesRead != uint32(limits.MaximumPayloadBytes)*2 || turn.SocketVisits != 2 {
		t.Fatalf("byte-bounded turn = %#v", turn)
	}

	cancelledContext, cancel := context.WithCancel(context.Background())
	cancel()
	before := operations.receiveCount()
	cancelled := datagramIO.ReceiveTurn(cancelledContext, []ReceiveTarget{target}, &captureReplySink{})
	if cancelled.StopReason != TurnStopCancelled || operations.receiveCount() != before {
		t.Fatalf("cancelled turn=%#v receiveCalls=%d want=%d", cancelled, operations.receiveCount(), before)
	}
}

func TestDatagramIOStaleTargetsCannotEmitIntoReplacementGeneration(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 50, testLimits(1, 2, 1, 1))
	operations := newFakeDatagramOperations()
	limits := testIOLimits()
	limits.MaximumTurnSocketVisits = 1
	datagramIO := mustDatagramIO(t, registry, nil, operations, nil, limits)
	old := datagramIO.Send(testContext(t), 50, 1, ipv4Datagram(nil))
	operations.enqueue(old.Token, old.Family, fakeReceive{source: testSourceEndpoint(), payload: []byte("late")})
	if failure := registry.ReplaceGeneration(testContext(t), 50, 51); failure != nil {
		t.Fatal(failure)
	}
	sink := &captureReplySink{}
	turn := datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{{Token: old.Token, Family: old.Family}}, sink)
	if turn.RepliesEmitted != 0 || turn.Dropped != 1 || len(sink.repliesSnapshot()) != 0 ||
		operations.receiveCount() != 0 {
		t.Fatalf("stale turn escaped: turn=%#v sink=%#v receives=%d", turn, sink, operations.receiveCount())
	}
	if datagramIO.Counters().StaleWorkDropped == 0 {
		t.Fatal("stale work was not counted")
	}
}

func TestDatagramIORealLoopbackIPv4AndIPv6(t *testing.T) {
	tests := []struct {
		name        string
		network     string
		address     string
		family      AddressFamily
		addressType protocol.AddressType
	}{
		{"IPv4", "udp4", "127.0.0.1:0", AddressFamilyIPv4, protocol.AddressTypeIPv4},
		{"IPv6", "udp6", "[::1]:0", AddressFamilyIPv6, protocol.AddressTypeIPv6},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server, err := net.ListenUDP(test.network, mustResolveUDPAddr(t, test.network, test.address))
			if err != nil {
				if test.family == AddressFamilyIPv6 {
					t.Skip("IPv6 loopback is unavailable")
				}
				t.Fatal(err)
			}
			defer server.Close()
			serverAddress := server.LocalAddr().(*net.UDPAddr)
			serverDone := make(chan error, 1)
			request := []byte{0x00, 0x7f, 0xff}
			reply := []byte{0xff, 0x7f, 0x00}
			go func() {
				buffer := make([]byte, 16)
				read, peer, readError := server.ReadFromUDP(buffer)
				if readError != nil {
					serverDone <- readError
					return
				}
				if !bytes.Equal(buffer[:read], request) {
					serverDone <- errors.New("loopback request changed")
					return
				}
				_, writeError := server.WriteToUDP(reply, peer)
				serverDone <- writeError
			}()

			registry, registryFailure := NewRegistry(
				context.Background(), 52, testLimits(1, 2, 1, 1), nil, SystemSocketFactory{},
			)
			if registryFailure != nil {
				t.Fatal(registryFailure)
			}
			defer registry.Shutdown(context.Background(), 52, CloseReasonProcessTermination)
			datagramIO := mustDatagramIO(t, registry, nil, nil, nil, testIOLimits())
			serverIP, ok := netip.AddrFromSlice(serverAddress.IP)
			if !ok {
				t.Fatal("loopback server returned an invalid address")
			}
			serverIP = serverIP.Unmap()
			endpointAddress := protocol.DatagramAddress{Type: test.addressType, Bytes: serverIP.AsSlice()}
			sent := datagramIO.Send(testContext(t), 52, 1, protocol.Datagram{
				Endpoint: protocol.DatagramEndpoint{Address: endpointAddress, Port: uint16(serverAddress.Port)},
				Data:     request,
			})
			if sent.Failure != nil {
				if test.family == AddressFamilyIPv6 && sent.Failure.Code == IOSocketFailure {
					t.Skip("IPv6 loopback send is unavailable")
				}
				t.Fatalf("send = %#v", sent)
			}
			select {
			case serverError := <-serverDone:
				if serverError != nil {
					t.Fatal(serverError)
				}
			case <-time.After(time.Second):
				t.Fatal("loopback server stalled")
			}

			sink := &captureReplySink{}
			waitSocketReadable(t, registry, sent.Token, sent.Family)
			turn := datagramIO.ReceiveTurn(testContext(t), []ReceiveTarget{{Token: sent.Token, Family: sent.Family}}, sink)
			replies := sink.repliesSnapshot()
			if turn.RepliesEmitted != 1 || len(replies) != 1 || !bytes.Equal(replies[0].datagram.Data, reply) {
				t.Fatalf("reply turn=%#v replies=%#v", turn, replies)
			}
			wantSource := protocol.DatagramEndpoint{Address: endpointAddress, Port: uint16(serverAddress.Port)}
			if !endpointsEqual(replies[0].datagram.Endpoint, wantSource) {
				t.Fatalf("source=%#v want=%#v", replies[0].datagram.Endpoint, wantSource)
			}
		})
	}
}

func TestDatagramIOConfigurationBounds(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 53, testLimits(1, 2, 1, 1))
	tests := []func(*IOLimits){
		func(value *IOLimits) { value.MaximumPayloadBytes = protocol.MaxUDPPayloadFloor - 1 },
		func(value *IOLimits) { value.ResolverTimeout = 0 },
		func(value *IOLimits) { value.MaximumConcurrentResolver = 0 },
		func(value *IOLimits) { value.MaximumQueuedResolver = 0 },
		func(value *IOLimits) { value.MaximumResolverNameBytes = 0 },
		func(value *IOLimits) { value.MaximumResolverResults = 0 },
		func(value *IOLimits) { value.MaximumResolverBytes = 3 },
		func(value *IOLimits) { value.ResolverFamilyPolicy = 0 },
		func(value *IOLimits) { value.MaximumTurnTargets = 0 },
		func(value *IOLimits) { value.MaximumTurnDatagrams = 0 },
		func(value *IOLimits) { value.MaximumTurnBytes = 1 },
		func(value *IOLimits) { value.MaximumTurnSocketVisits = 0 },
		func(value *IOLimits) { value.MaximumTurnDuration = 0 },
	}
	for index, mutate := range tests {
		limits := testIOLimits()
		mutate(&limits)
		if datagramIO, failure := NewDatagramIO(limits, registry, nil, nil, nil); datagramIO != nil ||
			failure == nil || failure.Code != IOInvalidConfiguration {
			t.Fatalf("invalid configuration %d accepted: io=%#v failure=%#v", index, datagramIO, failure)
		}
	}
}

func testIOLimits() IOLimits {
	return IOLimits{
		MaximumPayloadBytes:       protocol.MaxUDPPayloadFloor,
		ResolverTimeout:           time.Second,
		MaximumConcurrentResolver: 2,
		MaximumQueuedResolver:     4,
		MaximumResolverNameBytes:  4 * protocol.MaxDomainWireBytes,
		MaximumResolverResults:    8,
		MaximumResolverBytes:      128,
		ResolverFamilyPolicy:      ResolverIPv4ThenIPv6,
		MaximumTurnTargets:        8,
		MaximumTurnDatagrams:      8,
		MaximumTurnBytes:          uint32(protocol.MaxUDPPayloadFloor+1) * 8,
		MaximumTurnSocketVisits:   8,
		MaximumTurnDuration:       time.Second,
	}
}

func sendAndAwait(
	t *testing.T,
	datagramIO *DatagramIO,
	ctx context.Context,
	generation uint64,
	associationID uint32,
	datagram protocol.Datagram,
) SendResult {
	t.Helper()
	pending := datagramIO.Send(ctx, generation, associationID, datagram)
	if pending.Failure != nil || pending.Disposition != SendDispositionPending || pending.Token.Incarnation == 0 {
		t.Fatalf("domain send was not admitted asynchronously: %#v", pending)
	}
	result, ok := datagramIO.NextSendCompletion(testContext(t))
	if !ok {
		t.Fatal("domain send completion unavailable")
	}
	if result.Token != pending.Token {
		t.Fatalf("completion token = %#v, want %#v", result.Token, pending.Token)
	}
	return result
}

func assertResolverBaseline(t *testing.T, datagramIO *DatagramIO, workers uint16) {
	t.Helper()
	waitFor(t, func() bool {
		snapshot := datagramIO.Snapshot()
		return snapshot.ResolverWorkers == workers && snapshot.ActiveResolverJobs == 0 &&
			snapshot.QueuedResolverJobs == 0 && snapshot.PendingResolverCompletions == 0 &&
			snapshot.CopiedResolverNameBytes == 0 && snapshot.CopiedResolverPayloadBytes == 0 &&
			snapshot.CopiedResolverResultBytes == 0
	})
}

func assertActivityTimer(t *testing.T, clock *fakeClock, deadline time.Time, armEpoch int) {
	t.Helper()
	activeDeadline, ok := clock.activeDeadline()
	if !ok || !activeDeadline.Equal(deadline) || clock.timerCount() != armEpoch || clock.activeTimers() != 1 {
		t.Fatalf(
			"activity timer deadline=%v active=%t armEpoch=%d physicalActive=%d, want deadline=%v armEpoch=%d",
			activeDeadline,
			ok,
			clock.timerCount(),
			clock.activeTimers(),
			deadline,
			armEpoch,
		)
	}
}

func mustDatagramIO(
	t *testing.T,
	registry *Registry,
	resolver Resolver,
	operations SocketOperations,
	clock MonotonicClock,
	limits IOLimits,
) *DatagramIO {
	t.Helper()
	datagramIO, failure := NewDatagramIO(limits, registry, resolver, operations, clock)
	if failure != nil {
		t.Fatalf("NewDatagramIO: %v", failure)
	}
	return datagramIO
}

func ipv4Datagram(payload []byte) protocol.Datagram {
	return protocol.Datagram{
		Endpoint: protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}},
			Port:    53,
		},
		Data: payload,
	}
}

func ipv6Datagram(payload []byte) protocol.Datagram {
	return protocol.Datagram{
		Endpoint: protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv6, Bytes: netip.MustParseAddr("2001:db8::1").AsSlice()},
			Port:    53,
		},
		Data: payload,
	}
}

func domainDatagram(name string) protocol.Datagram {
	return protocol.Datagram{
		Endpoint: protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeDomain, Bytes: []byte(name)},
			Port:    53,
		},
		Data: []byte{1},
	}
}

func testSourceEndpoint() protocol.DatagramEndpoint {
	return protocol.DatagramEndpoint{
		Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: []byte{203, 0, 113, 1}},
		Port:    9000,
	}
}

func assertIOFailure(
	t *testing.T,
	failure *IOFailure,
	code IOFailureCode,
	udpCode protocol.UDPErrorCode,
	retryable bool,
) {
	t.Helper()
	if failure == nil || failure.Code != code || failure.UDPCode != udpCode || failure.Retryable != retryable {
		t.Fatalf("failure = %#v, want code=%s udp=%d retry=%t", failure, code, udpCode, retryable)
	}
}

func endpointsEqual(left, right protocol.DatagramEndpoint) bool {
	return left.Address.Type == right.Address.Type && left.Port == right.Port &&
		bytes.Equal(left.Address.Bytes, right.Address.Bytes)
}

func mustResolveUDPAddr(t *testing.T, network, address string) *net.UDPAddr {
	t.Helper()
	value, err := net.ResolveUDPAddr(network, address)
	if err != nil {
		t.Fatal(err)
	}
	return value
}

func receiveSendResult(t *testing.T, results <-chan SendResult) SendResult {
	t.Helper()
	select {
	case result := <-results:
		return result
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for send result")
		return SendResult{}
	}
}

func waitSocketReadable(t *testing.T, registry *Registry, token AssociationToken, family AddressFamily) {
	t.Helper()
	descriptor := -1
	if failure := registry.UseSocket(testContext(t), token, family, func(value int) error {
		descriptor = value
		return nil
	}); failure != nil {
		t.Fatalf("capture descriptor for readiness: %v", failure)
	}
	duplicate, err := syscall.Dup(descriptor)
	if err != nil {
		t.Fatalf("duplicate descriptor for readiness: %v", err)
	}
	file := os.NewFile(uintptr(duplicate), "relay-udp-readiness")
	packetConnection, err := net.FilePacketConn(file)
	_ = file.Close()
	if err != nil {
		t.Fatalf("create readiness connection: %v", err)
	}
	defer packetConnection.Close()
	udpConnection, ok := packetConnection.(*net.UDPConn)
	if !ok {
		t.Fatalf("readiness connection type = %T", packetConnection)
	}
	if err := udpConnection.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
		t.Fatalf("set readiness deadline: %v", err)
	}
	rawConnection, err := udpConnection.SyscallConn()
	if err != nil {
		t.Fatalf("obtain readiness raw connection: %v", err)
	}
	var probeError error
	err = rawConnection.Read(func(value uintptr) bool {
		var probe [1]byte
		_, _, _, _, probeError = syscall.Recvmsg(int(value), probe[:], nil, syscall.MSG_PEEK)
		return !isWouldBlock(probeError)
	})
	if err != nil || probeError != nil {
		t.Fatalf("wait for loopback readiness: raw=%v probe=%v", err, probeError)
	}
}

type resolverCall struct {
	network string
	name    string
}

type scriptedResolver struct {
	mu      sync.Mutex
	results []netip.Addr
	err     error
	calls   []resolverCall
}

func (r *scriptedResolver) LookupNetIP(_ context.Context, network, name string) ([]netip.Addr, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.calls = append(r.calls, resolverCall{network: network, name: name})
	return append([]netip.Addr(nil), r.results...), r.err
}

func (r *scriptedResolver) snapshot() []resolverCall {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]resolverCall(nil), r.calls...)
}

func (r *scriptedResolver) callCount() int { return len(r.snapshot()) }

func (r *scriptedResolver) lastNetwork() string {
	calls := r.snapshot()
	return calls[len(calls)-1].network
}

func (r *scriptedResolver) lastName() string {
	calls := r.snapshot()
	return calls[len(calls)-1].name
}

type barrierResolver struct {
	entered chan struct{}
	once    sync.Once
}

type pausedResolver struct {
	entered           chan struct{}
	release           chan struct{}
	honorCancellation bool
	once              sync.Once
	mu                sync.Mutex
	calls             int
}

func newPausedResolver(honorCancellation bool) *pausedResolver {
	return &pausedResolver{
		entered: make(chan struct{}), release: make(chan struct{}), honorCancellation: honorCancellation,
	}
}

func (r *pausedResolver) LookupNetIP(ctx context.Context, _, _ string) ([]netip.Addr, error) {
	r.mu.Lock()
	r.calls++
	r.mu.Unlock()
	r.once.Do(func() { close(r.entered) })
	if r.honorCancellation {
		select {
		case <-r.release:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	} else {
		<-r.release
	}
	return []netip.Addr{netip.MustParseAddr("192.0.2.88")}, nil
}

func (r *pausedResolver) callCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.calls
}

func newBarrierResolver() *barrierResolver {
	return &barrierResolver{entered: make(chan struct{})}
}

func (r *barrierResolver) LookupNetIP(ctx context.Context, _, _ string) ([]netip.Addr, error) {
	r.once.Do(func() { close(r.entered) })
	<-ctx.Done()
	return nil, ctx.Err()
}

type sendCall struct {
	descriptor int
	family     AddressFamily
	address    netip.Addr
	port       uint16
	payload    []byte
}

type receiveKey struct {
	token  AssociationToken
	family AddressFamily
}

type fakeReceive struct {
	source    protocol.DatagramEndpoint
	payload   []byte
	truncated bool
	err       error
}

type fakeDatagramOperations struct {
	mu              sync.Mutex
	sends           []sendCall
	sendError       error
	receives        map[int][]fakeReceive
	receiveCalls    int
	advanceClock    *fakeClock
	advanceDuration time.Duration
}

func newFakeDatagramOperations() *fakeDatagramOperations {
	return &fakeDatagramOperations{receives: make(map[int][]fakeReceive)}
}

func (o *fakeDatagramOperations) SendTo(
	descriptor int,
	family AddressFamily,
	address netip.Addr,
	port uint16,
	payload []byte,
) error {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.sends = append(o.sends, sendCall{
		descriptor: descriptor,
		family:     family,
		address:    address,
		port:       port,
		payload:    append([]byte(nil), payload...),
	})
	return o.sendError
}

func (o *fakeDatagramOperations) setSendError(err error) {
	o.mu.Lock()
	o.sendError = err
	o.mu.Unlock()
}

func (o *fakeDatagramOperations) ReceiveFrom(
	descriptor int,
	_ AddressFamily,
	buffer []byte,
) (int, protocol.DatagramEndpoint, bool, error) {
	o.mu.Lock()
	o.receiveCalls++
	queue := o.receives[descriptor]
	if len(queue) == 0 {
		o.mu.Unlock()
		return 0, protocol.DatagramEndpoint{}, false, syscall.EAGAIN
	}
	next := queue[0]
	o.receives[descriptor] = queue[1:]
	clock := o.advanceClock
	duration := o.advanceDuration
	o.mu.Unlock()
	if clock != nil && duration > 0 {
		clock.advance(duration)
	}
	read := copy(buffer, next.payload)
	truncated := next.truncated || read < len(next.payload)
	return read, next.source, truncated, next.err
}

func (o *fakeDatagramOperations) enqueue(token AssociationToken, family AddressFamily, receives ...fakeReceive) {
	descriptor := 100 + int(token.AssociationID-1)
	if family == AddressFamilyIPv6 && token.AssociationID == 1 {
		descriptor++
	}
	o.mu.Lock()
	o.receives[descriptor] = append(o.receives[descriptor], receives...)
	o.mu.Unlock()
}

func (o *fakeDatagramOperations) lastSend() sendCall {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.sends[len(o.sends)-1]
}

func (o *fakeDatagramOperations) sendCount() int {
	o.mu.Lock()
	defer o.mu.Unlock()
	return len(o.sends)
}

func (o *fakeDatagramOperations) receiveCount() int {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.receiveCalls
}

type capturedReply struct {
	token    AssociationToken
	datagram protocol.Datagram
}

type captureReplySink struct {
	mu               sync.Mutex
	replyDisposition ReplyDisposition
	replies          []capturedReply
	failures         []*IOFailure
}

func (s *captureReplySink) ConsumeReply(token AssociationToken, datagram protocol.Datagram) ReplyDisposition {
	s.mu.Lock()
	s.replies = append(s.replies, capturedReply{
		token: token,
		datagram: protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{
					Type:  datagram.Endpoint.Address.Type,
					Bytes: append([]byte(nil), datagram.Endpoint.Address.Bytes...),
				},
				Port: datagram.Endpoint.Port,
			},
			Data: append([]byte(nil), datagram.Data...),
		},
	})
	disposition := s.replyDisposition
	if disposition == 0 {
		disposition = ReplyAccepted
	}
	s.mu.Unlock()
	return disposition
}

func (s *captureReplySink) ConsumeFailure(_ AssociationToken, failure *IOFailure) {
	s.mu.Lock()
	s.failures = append(s.failures, failure)
	s.mu.Unlock()
}

func (s *captureReplySink) repliesSnapshot() []capturedReply {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]capturedReply(nil), s.replies...)
}

func (s *captureReplySink) failuresSnapshot() []*IOFailure {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]*IOFailure(nil), s.failures...)
}
