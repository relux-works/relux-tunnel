package udp

import (
	"context"
	"errors"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

func TestRegistryFamilySpecificLazyAdmissionAndDuplicateOwnership(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 7, testLimits(4, 8, 4, 4))

	v4 := mustEnsure(t, registry, 7, 41, AddressFamilyIPv4)
	if !v4.AssociationCreated || !v4.SocketCreated {
		t.Fatalf("first admission = %#v", v4)
	}
	duplicate := mustEnsure(t, registry, 7, 41, AddressFamilyIPv4)
	if duplicate.Token != v4.Token || duplicate.AssociationCreated || duplicate.SocketCreated {
		t.Fatalf("duplicate replaced ownership: %#v", duplicate)
	}
	dual, failure := registry.EnsureFamilies(
		testContext(t), 7, 41, AddressFamilyIPv6, AddressFamilyIPv4, AddressFamilyIPv6,
	)
	if failure != nil || dual.Token != v4.Token || dual.AssociationCreated || dual.SocketsCreated != 1 ||
		len(dual.Families) != 2 || dual.Families[0] != AddressFamilyIPv4 || dual.Families[1] != AddressFamilyIPv6 {
		t.Fatalf("dual-family admission = %#v failure=%v", dual, failure)
	}

	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 1 || snapshot.Sockets != 2 || snapshot.Timers != 1 ||
		snapshot.Counters.AssociationsAdmitted != 1 || snapshot.Counters.ExistingAssociationsUsed != 1 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	if got := factory.families(); len(got) != 2 || got[0] != AddressFamilyIPv4 || got[1] != AddressFamilyIPv6 {
		t.Fatalf("families = %#v", got)
	}

	if _, failure := registry.Ensure(testContext(t), 6, 41, AddressFamilyIPv4); failure == nil || failure.Code != ErrorStaleGeneration {
		t.Fatalf("stale generation failure = %#v", failure)
	}
	if _, failure := registry.Ensure(testContext(t), 7, 0, AddressFamilyIPv4); failure == nil || failure.Code != ErrorInvalidAssociationID {
		t.Fatalf("zero association failure = %#v", failure)
	}
	if _, failure := registry.Ensure(testContext(t), 7, 42, AddressFamily(99)); failure == nil || failure.Code != ErrorInvalidAddressFamily {
		t.Fatalf("invalid family failure = %#v", failure)
	}
	if factory.openCount() != 2 {
		t.Fatalf("validation created descriptors: %d", factory.openCount())
	}
}

func TestRegistryReservationAndTokenScopedSocketAdmission(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 8, testLimits(1, 2, 1, 1))
	reservation, failure := registry.Reserve(testContext(t), 8, 41)
	if failure != nil || !reservation.AssociationCreated || reservation.Token.Incarnation == 0 {
		t.Fatalf("reservation = %#v failure=%v", reservation, failure)
	}
	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 1 || snapshot.Sockets != 0 || snapshot.Timers != 1 || factory.openCount() != 0 {
		t.Fatalf("socketless reservation = %#v opens=%d", snapshot, factory.openCount())
	}
	admission, failure := registry.EnsureTokenFamilies(
		testContext(t), reservation.Token, AddressFamilyIPv6, AddressFamilyIPv4,
	)
	if failure != nil || admission.Token != reservation.Token || admission.SocketsCreated != 2 ||
		len(admission.Families) != 2 || admission.Families[0] != AddressFamilyIPv4 || admission.Families[1] != AddressFamilyIPv6 {
		t.Fatalf("token family admission = %#v failure=%v", admission, failure)
	}
	if got := factory.families(); len(got) != 2 || got[0] != AddressFamilyIPv4 || got[1] != AddressFamilyIPv6 {
		t.Fatalf("opened families = %#v", got)
	}
	if closed, failure := registry.CloseAssociation(testContext(t), reservation.Token, CloseReasonLocal); failure != nil || !closed.Closed {
		t.Fatalf("close = %#v failure=%v", closed, failure)
	}
	select {
	case <-reservation.lifecycle.Done():
	default:
		t.Fatal("reservation lifecycle was not cancelled")
	}
}

func TestRegistryTokenScopedAdmissionRejectsReusedID(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 9, testLimits(1, 2, 1, 1))
	old, failure := registry.Reserve(testContext(t), 9, 1)
	if failure != nil {
		t.Fatalf("reserve old: %v", failure)
	}
	if closed, failure := registry.CloseAssociation(testContext(t), old.Token, CloseReasonRemote); failure != nil || !closed.Closed {
		t.Fatalf("close old = %#v failure=%v", closed, failure)
	}
	current, failure := registry.Reserve(testContext(t), 9, 1)
	if failure != nil || current.Token.Incarnation == old.Token.Incarnation {
		t.Fatalf("reserve current = %#v failure=%v", current, failure)
	}
	if _, failure := registry.EnsureTokenFamilies(testContext(t), old.Token, AddressFamilyIPv4); failure == nil || failure.Code != ErrorStaleAssociation {
		t.Fatalf("old token admission failure = %#v", failure)
	}
	if factory.openCount() != 0 {
		t.Fatalf("stale token opened %d sockets", factory.openCount())
	}
	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 1 || snapshot.Sockets != 0 || snapshot.Timers != 1 {
		t.Fatalf("current reservation mutated = %#v", snapshot)
	}
}

func TestRegistryRejectsEveryCeilingBeforeDescriptorCreation(t *testing.T) {
	tests := []struct {
		name          string
		limits        RegistryLimits
		prepare       func(*testing.T, *Registry)
		associationID uint32
		family        AddressFamily
		code          ErrorCode
		counter       func(Counters) uint64
	}{
		{
			name: "association", limits: testLimits(1, 2, 1, 1), associationID: 2, family: AddressFamilyIPv4,
			prepare: func(t *testing.T, registry *Registry) { mustEnsure(t, registry, 1, 1, AddressFamilyIPv4) },
			code:    ErrorAssociationLimit, counter: func(c Counters) uint64 { return c.AssociationRejected },
		},
		{
			name: "socket", limits: testLimits(2, 1, 2, 2), associationID: 1, family: AddressFamilyIPv6,
			prepare: func(t *testing.T, registry *Registry) { mustEnsure(t, registry, 1, 1, AddressFamilyIPv4) },
			code:    ErrorSocketLimit, counter: func(c Counters) uint64 { return c.SocketLimitRejected },
		},
		{
			name: "timer", limits: testLimits(2, 4, 1, 2), associationID: 2, family: AddressFamilyIPv4,
			prepare: func(t *testing.T, registry *Registry) { mustEnsure(t, registry, 1, 1, AddressFamilyIPv4) },
			code:    ErrorTimerLimit, counter: func(c Counters) uint64 { return c.TimerLimitRejected },
		},
		{
			name: "pending close", limits: testLimits(2, 4, 2, 1), associationID: 2, family: AddressFamilyIPv4,
			prepare: func(t *testing.T, registry *Registry) { mustEnsure(t, registry, 1, 1, AddressFamilyIPv4) },
			code:    ErrorPendingCloseLimit, counter: func(c Counters) uint64 { return c.PendingCloseLimitRejected },
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			registry, _, factory := newTestRegistry(t, 1, test.limits)
			test.prepare(t, registry)
			before := factory.openCount()
			if _, failure := registry.Ensure(testContext(t), 1, test.associationID, test.family); failure == nil || failure.Code != test.code {
				t.Fatalf("failure = %#v, want %s", failure, test.code)
			}
			if factory.openCount() != before {
				t.Fatalf("descriptor created before %s rejection", test.name)
			}
			if got := test.counter(mustSnapshot(t, registry).Counters); got != 1 {
				t.Fatalf("counter = %d", got)
			}
		})
	}

	t.Run("atomic family set reserves every socket", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 1, testLimits(2, 1, 2, 2))
		if _, failure := registry.EnsureFamilies(
			testContext(t), 1, 1, AddressFamilyIPv4, AddressFamilyIPv6,
		); failure == nil || failure.Code != ErrorSocketLimit {
			t.Fatalf("atomic socket reservation failure = %#v", failure)
		}
		if factory.openCount() != 0 {
			t.Fatalf("atomic reservation opened %d descriptors", factory.openCount())
		}
		assertRegistryBaseline(t, registry, clock)
	})
}

func TestRegistryRollsBackPartialSocketCreationFailure(t *testing.T) {
	t.Run("new dual family transaction", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 2, testLimits(2, 4, 2, 2))
		factory.failOnOpen(2, true)
		if _, failure := registry.EnsureFamilies(
			testContext(t), 2, 1, AddressFamilyIPv4, AddressFamilyIPv6,
		); failure == nil || failure.Code != ErrorSocketFailure {
			t.Fatalf("dual-family failure = %#v", failure)
		}
		assertRegistryBaseline(t, registry, clock)
		if factory.openCount() != 2 || factory.totalCloseCalls() != 2 ||
			factory.socket(0).closeCalls() != 1 || factory.socket(1).closeCalls() != 1 {
			t.Fatalf("atomic rollback open=%d close=%d first=%d second=%d",
				factory.openCount(), factory.totalCloseCalls(), factory.socket(0).closeCalls(), factory.socket(1).closeCalls())
		}
		snapshot := mustSnapshot(t, registry)
		if snapshot.Counters.SocketCreationFailed != 1 || snapshot.Counters.SocketsClosed != 2 ||
			snapshot.Counters.AtomicAdmissionRolledBack != 1 {
			t.Fatalf("atomic rollback counters = %#v", snapshot.Counters)
		}
	})

	t.Run("existing family is retired when completion fails", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 3, testLimits(2, 4, 2, 2))
		active := mustEnsure(t, registry, 3, 1, AddressFamilyIPv4)
		factory.failNext(true)
		if _, failure := registry.EnsureFamilies(
			testContext(t), 3, 1, AddressFamilyIPv4, AddressFamilyIPv6,
		); failure == nil || failure.Code != ErrorSocketFailure {
			t.Fatalf("family completion failure = %#v", failure)
		}
		assertRegistryBaseline(t, registry, clock)
		if factory.openCount() != 2 || factory.totalCloseCalls() != 2 ||
			factory.socket(0).closeCalls() != 1 || factory.socket(1).closeCalls() != 1 {
			t.Fatalf("owned rollback open=%d close=%d first=%d second=%d",
				factory.openCount(), factory.totalCloseCalls(), factory.socket(0).closeCalls(), factory.socket(1).closeCalls())
		}
		if failure := registry.RecordActivity(testContext(t), active.Token); failure == nil || failure.Code != ErrorUnknownAssociation {
			t.Fatalf("rolled-back token remained live: %#v", failure)
		}
	})

	t.Run("lazy second family completion also retires partial ownership", func(t *testing.T) {
		registry, clock, factory := newTestRegistry(t, 4, testLimits(2, 4, 2, 2))
		active := mustEnsure(t, registry, 4, 1, AddressFamilyIPv4)
		factory.failNext(true)
		if _, failure := registry.Ensure(testContext(t), 4, 1, AddressFamilyIPv6); failure == nil || failure.Code != ErrorSocketFailure {
			t.Fatalf("lazy family completion failure = %#v", failure)
		}
		assertRegistryBaseline(t, registry, clock)
		if factory.totalCloseCalls() != 2 {
			t.Fatalf("lazy completion rollback close count = %d", factory.totalCloseCalls())
		}
		if failure := registry.RecordActivity(testContext(t), active.Token); failure == nil || failure.Code != ErrorUnknownAssociation {
			t.Fatalf("lazy rolled-back token remained live: %#v", failure)
		}
	})
}

func TestRegistryFakeClockExpiryAndRearmRejectStaleABA(t *testing.T) {
	registry, clock, factory := newTestRegistry(t, 3, testLimits(2, 4, 2, 2))
	admission := mustEnsure(t, registry, 3, 9, AddressFamilyIPv4)
	clock.advance(5 * time.Second)
	if failure := registry.RecordActivity(testContext(t), admission.Token); failure != nil {
		t.Fatalf("activity: %v", failure)
	}
	if clock.timerCount() < 2 {
		t.Fatalf("activity did not create a distinct timer arm")
	}
	if failure := registry.deliverTimerArm(testContext(t), 1); failure != nil {
		t.Fatalf("deliver obsolete timer arm: %v", failure)
	}
	staleSnapshot := mustSnapshot(t, registry)
	if staleSnapshot.Associations != 1 || staleSnapshot.Timers != 1 || clock.activeTimers() != 1 ||
		staleSnapshot.Counters.StaleTimerArmsIgnored != 1 {
		t.Fatalf("obsolete arm mutated current timer state: snapshot=%#v physical=%d", staleSnapshot, clock.activeTimers())
	}
	clock.advance(5 * time.Second)
	if snapshot := mustSnapshot(t, registry); snapshot.Associations != 1 {
		t.Fatalf("stale arm expired live association: %#v", snapshot)
	}

	clock.advance(5 * time.Second)
	waitFor(t, func() bool { return mustSnapshot(t, registry).Associations == 0 })
	event := receiveEvent(t, registry.Events())
	if event.Kind != EventIdleExpired || event.Token != admission.Token {
		t.Fatalf("expiry event = %#v", event)
	}
	if factory.socket(0).closeCalls() != 1 || clock.activeTimers() != 0 {
		t.Fatalf("expiry cleanup close=%d timers=%d", factory.socket(0).closeCalls(), clock.activeTimers())
	}
	snapshot := mustSnapshot(t, registry)
	if snapshot.Sockets != 0 || snapshot.Timers != 0 || snapshot.PendingCloseEvents != 0 || snapshot.Counters.IdleExpired != 1 {
		t.Fatalf("expiry baseline = %#v", snapshot)
	}
}

func TestRegistryCrossedCloseAndIncarnationIsolation(t *testing.T) {
	registry, _, factory := newTestRegistry(t, 4, testLimits(2, 4, 2, 2))
	first := mustEnsure(t, registry, 4, 22, AddressFamilyIPv4)
	closed, failure := registry.CloseAssociation(testContext(t), first.Token, CloseReasonRemote)
	if failure != nil || !closed.Closed || closed.Stale {
		t.Fatalf("first close = %#v failure=%v", closed, failure)
	}
	duplicate, failure := registry.CloseAssociation(testContext(t), first.Token, CloseReasonLocal)
	if failure != nil || duplicate.Closed || duplicate.Stale {
		t.Fatalf("crossed close = %#v failure=%v", duplicate, failure)
	}
	if factory.socket(0).closeCalls() != 1 {
		t.Fatalf("crossed close count = %d", factory.socket(0).closeCalls())
	}

	second := mustEnsure(t, registry, 4, 22, AddressFamilyIPv4)
	if second.Token.Incarnation == first.Token.Incarnation {
		t.Fatalf("association incarnation reused: %#v", second.Token)
	}
	stale, failure := registry.CloseAssociation(testContext(t), first.Token, CloseReasonRemote)
	if failure != nil || stale.Closed || !stale.Stale {
		t.Fatalf("stale close = %#v failure=%v", stale, failure)
	}
	if failure := registry.RecordActivity(testContext(t), first.Token); failure == nil || failure.Code != ErrorStaleAssociation {
		t.Fatalf("stale activity failure = %#v", failure)
	}
	if snapshot := mustSnapshot(t, registry); snapshot.Associations != 1 || snapshot.Sockets != 1 {
		t.Fatalf("stale callback changed replacement: %#v", snapshot)
	}
}

func TestRegistryGenerationReplacementSessionLossAndCancellation(t *testing.T) {
	registry, clock, factory := newTestRegistry(t, 10, testLimits(3, 6, 3, 3))
	old := mustEnsure(t, registry, 10, 1, AddressFamilyIPv4)
	mustEnsure(t, registry, 10, 2, AddressFamilyIPv6)
	if failure := registry.ReplaceGeneration(testContext(t), 10, 11); failure != nil {
		t.Fatalf("replace generation: %v", failure)
	}
	if factory.totalCloseCalls() != 2 || clock.activeTimers() != 0 {
		t.Fatalf("replacement cleanup closes=%d timers=%d", factory.totalCloseCalls(), clock.activeTimers())
	}
	if failure := registry.RecordActivity(testContext(t), old.Token); failure == nil || failure.Code != ErrorStaleGeneration {
		t.Fatalf("old generation activity = %#v", failure)
	}
	current := mustEnsure(t, registry, 11, 1, AddressFamilyIPv4)
	if current.Token.Generation != 11 || current.Token.Incarnation == old.Token.Incarnation {
		t.Fatalf("replacement token = %#v old=%#v", current.Token, old.Token)
	}
	if failure := registry.Shutdown(testContext(t), 11, CloseReasonSessionLoss); failure != nil {
		t.Fatalf("session loss shutdown: %v", failure)
	}
	waitDone(t, registry.Done())
	if factory.totalCloseCalls() != 3 || clock.activeTimers() != 0 {
		t.Fatalf("session cleanup closes=%d timers=%d", factory.totalCloseCalls(), clock.activeTimers())
	}

	parent, cancel := context.WithCancel(context.Background())
	cancelFactory := newFakeSocketFactory()
	cancelClock := newFakeClock()
	cancelRegistry, failure := NewRegistry(parent, 20, testLimits(1, 2, 1, 1), cancelClock, cancelFactory)
	if failure != nil {
		t.Fatalf("new cancellation registry: %v", failure)
	}
	mustEnsure(t, cancelRegistry, 20, 1, AddressFamilyIPv4)
	cancel()
	waitDone(t, cancelRegistry.Done())
	if cancelFactory.totalCloseCalls() != 1 || cancelClock.activeTimers() != 0 {
		t.Fatalf("cancellation cleanup closes=%d timers=%d", cancelFactory.totalCloseCalls(), cancelClock.activeTimers())
	}
	if _, failure := cancelRegistry.Snapshot(testContext(t)); failure == nil || failure.Code != ErrorRegistryClosed {
		t.Fatalf("post-cancel snapshot = %#v", failure)
	}
}

func TestRegistryTerminalReasonsCloseEveryDescriptorOnce(t *testing.T) {
	for index, reason := range []CloseReason{
		CloseReasonSessionClose,
		CloseReasonSessionLoss,
		CloseReasonProcessTermination,
	} {
		t.Run(string(reason), func(t *testing.T) {
			generation := uint64(70 + index)
			clock := newFakeClock()
			factory := newFakeSocketFactory()
			registry, failure := NewRegistry(
				context.Background(), generation, testLimits(2, 4, 2, 2), clock, factory,
			)
			if failure != nil {
				t.Fatalf("new registry: %v", failure)
			}
			mustEnsure(t, registry, generation, 1, AddressFamilyIPv4)
			mustEnsure(t, registry, generation, 1, AddressFamilyIPv6)
			if failure := registry.Shutdown(testContext(t), generation, reason); failure != nil {
				t.Fatalf("shutdown: %v", failure)
			}
			waitDone(t, registry.Done())
			if factory.totalCloseCalls() != 2 || clock.activeTimers() != 0 {
				t.Fatalf("terminal cleanup closes=%d timers=%d", factory.totalCloseCalls(), clock.activeTimers())
			}
		})
	}
}

func TestRegistryForcedDescriptorActivityCleanupRaceMatrix(t *testing.T) {
	tests := []struct {
		name   string
		kind   cleanupRaceKind
		reason CloseReason
	}{
		{name: "local close", kind: cleanupRaceAssociationClose, reason: CloseReasonLocal},
		{name: "remote close", kind: cleanupRaceAssociationClose, reason: CloseReasonRemote},
		{name: "idle expiry", kind: cleanupRaceExpiry, reason: CloseReasonIdleExpiry},
		{name: "generation replacement", kind: cleanupRaceReplacement, reason: CloseReasonSessionReplacement},
		{name: "session close", kind: cleanupRaceShutdown, reason: CloseReasonSessionClose},
		{name: "session loss", kind: cleanupRaceShutdown, reason: CloseReasonSessionLoss},
		{name: "process termination", kind: cleanupRaceShutdown, reason: CloseReasonProcessTermination},
		{name: "parent cancellation", kind: cleanupRaceCancellation, reason: CloseReasonCancellation},
	}

	for testIndex, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			for cycle := 0; cycle < 20; cycle++ {
				generation := uint64(1000 + testIndex*100 + cycle)
				runForcedCleanupRace(t, generation, test.kind, test.reason)
			}
		})
	}
}

func TestRegistryRedactsDescriptorOperationErrors(t *testing.T) {
	registry, _, _ := newTestRegistry(t, 30, testLimits(1, 2, 1, 1))
	admission := mustEnsure(t, registry, 30, 1, AddressFamilyIPv4)
	failure := registry.UseSocket(testContext(t), admission.Token, AddressFamilyIPv4, func(int) error {
		return errors.New("destination.example payload-secret")
	})
	if failure == nil || failure.Code != ErrorOperationFailure || strings.Contains(failure.Error(), "destination") || strings.Contains(failure.Error(), "payload") {
		t.Fatalf("operation failure leaked sensitive input: %v", failure)
	}
}

func TestRegistryPendingExpiryCreditIsBoundedUntilEventConsumed(t *testing.T) {
	limits := testLimits(2, 4, 2, 1)
	registry, clock, factory := newTestRegistry(t, 40, limits)
	mustEnsure(t, registry, 40, 1, AddressFamilyIPv4)
	clock.advance(limits.IdleTimeout)
	waitFor(t, func() bool { return mustSnapshot(t, registry).Associations == 0 })
	before := factory.openCount()
	if _, failure := registry.Ensure(testContext(t), 40, 2, AddressFamilyIPv4); failure == nil || failure.Code != ErrorPendingCloseLimit {
		t.Fatalf("pending event admission = %#v", failure)
	}
	if factory.openCount() != before {
		t.Fatal("pending-close rejection created a descriptor")
	}
	_ = receiveEvent(t, registry.Events())
	mustEnsure(t, registry, 40, 2, AddressFamilyIPv4)
}

func TestRegistryRepeatedCyclesReturnAllResourcesToBaseline(t *testing.T) {
	registry, clock, factory := newTestRegistry(t, 50, testLimits(4, 8, 4, 4))
	for cycle := uint32(1); cycle <= 100; cycle++ {
		admission := mustEnsure(t, registry, 50, cycle, AddressFamilyIPv4)
		mustEnsure(t, registry, 50, cycle, AddressFamilyIPv6)
		result, failure := registry.CloseAssociation(testContext(t), admission.Token, CloseReasonLocal)
		if failure != nil || !result.Closed {
			t.Fatalf("cycle %d close = %#v failure=%v", cycle, result, failure)
		}
		snapshot := mustSnapshot(t, registry)
		if snapshot.Associations != 0 || snapshot.Sockets != 0 || snapshot.Timers != 0 ||
			snapshot.PendingCloseEvents != 0 || clock.activeTimers() != 0 {
			t.Fatalf("cycle %d baseline = %#v activeTimers=%d", cycle, snapshot, clock.activeTimers())
		}
	}
	if factory.openCount() != 200 || factory.totalCloseCalls() != 200 {
		t.Fatalf("descriptor reconciliation open=%d close=%d", factory.openCount(), factory.totalCloseCalls())
	}
}

func TestSystemSocketsAreNonblockingUnboundUnconnectedAndCloseOnce(t *testing.T) {
	registry, failure := NewRegistry(
		context.Background(), 60, testLimits(2, 4, 2, 2), nil, SystemSocketFactory{},
	)
	if failure != nil {
		t.Fatalf("new system registry: %v", failure)
	}
	t.Cleanup(func() { _ = registry.Shutdown(context.Background(), 60, CloseReasonProcessTermination) })

	for index, family := range []AddressFamily{AddressFamilyIPv4, AddressFamilyIPv6} {
		associationID := uint32(index + 1)
		admission, failure := registry.Ensure(testContext(t), 60, associationID, family)
		if failure != nil {
			if family == AddressFamilyIPv6 && failure.Code == ErrorSocketFailure {
				t.Skip("host does not provide an IPv6 UDP descriptor")
			}
			t.Fatalf("ensure %d: %v", family, failure)
		}
		var descriptor int
		failure = registry.UseSocket(testContext(t), admission.Token, family, func(fd int) error {
			descriptor = fd
			flags, _, errno := syscall.Syscall(syscall.SYS_FCNTL, uintptr(fd), uintptr(syscall.F_GETFL), 0)
			if errno != 0 {
				t.Fatalf("F_GETFL: %v", errno)
			}
			if flags&syscall.O_NONBLOCK == 0 {
				t.Fatalf("descriptor %d is blocking", fd)
			}
			fdFlags, _, errno := syscall.Syscall(syscall.SYS_FCNTL, uintptr(fd), uintptr(syscall.F_GETFD), 0)
			if errno != 0 || fdFlags&syscall.FD_CLOEXEC == 0 {
				t.Fatalf("descriptor %d close-on-exec flags=%x errno=%v", fd, fdFlags, errno)
			}
			local, err := syscall.Getsockname(fd)
			if err != nil {
				t.Fatalf("getsockname: %v", err)
			}
			switch address := local.(type) {
			case *syscall.SockaddrInet4:
				if family != AddressFamilyIPv4 || address.Port != 0 {
					t.Fatalf("IPv4 local address = %#v", address)
				}
			case *syscall.SockaddrInet6:
				if family != AddressFamilyIPv6 || address.Port != 0 {
					t.Fatalf("IPv6 local address = %#v", address)
				}
			default:
				t.Fatalf("unexpected local address type %T", local)
			}
			if peer, err := syscall.Getpeername(fd); err == nil || peer != nil {
				t.Fatalf("descriptor unexpectedly connected: peer=%#v err=%v", peer, err)
			}
			return nil
		})
		if failure != nil {
			t.Fatalf("inspect system descriptor: %v", failure)
		}
		result, failure := registry.CloseAssociation(testContext(t), admission.Token, CloseReasonLocal)
		if failure != nil || !result.Closed {
			t.Fatalf("close system descriptor: %#v %v", result, failure)
		}
		_, _, errno := syscall.Syscall(syscall.SYS_FCNTL, uintptr(descriptor), uintptr(syscall.F_GETFL), 0)
		if errno != syscall.EBADF {
			t.Fatalf("descriptor %d remained open: %v", descriptor, errno)
		}
	}
}

func TestRegistryConfigurationUsesAcceptedProtocolBounds(t *testing.T) {
	effective := protocol.EffectiveLimits{
		MaxAssociations:         protocol.MaxAssociationsRelayDefault,
		IdleTimeoutMilliseconds: protocol.IdleTimeoutRelayDefault,
	}
	limits := RegistryLimitsFromEffective(effective)
	if limits.MaxSockets != protocol.MaxAssociationsRelayDefault*2 || limits.MaxTimers != protocol.MaxAssociationsRelayDefault ||
		limits.MaxPendingCloses != protocol.MaxAssociationsRelayDefault || limits.IdleTimeout != 120*time.Second {
		t.Fatalf("derived limits = %#v", limits)
	}
	invalid := limits
	invalid.IdleTimeout = time.Duration(protocol.IdleTimeoutFloor-1) * time.Millisecond
	if registry, failure := NewRegistry(context.Background(), 1, invalid, nil, newFakeSocketFactory()); registry != nil || failure == nil || failure.Code != ErrorInvalidConfiguration {
		t.Fatalf("invalid configuration = registry=%#v failure=%#v", registry, failure)
	}
}

type cleanupRaceKind uint8

const (
	cleanupRaceAssociationClose cleanupRaceKind = iota
	cleanupRaceExpiry
	cleanupRaceReplacement
	cleanupRaceShutdown
	cleanupRaceCancellation
)

type cleanupTerminalResult struct {
	close   CloseResult
	failure *RegistryError
}

func runForcedCleanupRace(
	t *testing.T,
	generation uint64,
	kind cleanupRaceKind,
	reason CloseReason,
) {
	t.Helper()
	parent, cancel := context.WithCancel(context.Background())
	defer cancel()
	limits := testLimits(1, 2, 1, 1)
	clock := newFakeClock()
	factory := newFakeSocketFactory()
	registry, failure := NewRegistry(parent, generation, limits, clock, factory)
	if failure != nil {
		t.Fatalf("new race registry: %v", failure)
	}
	admission := mustEnsure(t, registry, generation, 1, AddressFamilyIPv4)

	descriptorStarted := make(chan struct{})
	releaseDescriptor := make(chan struct{})
	useResult := make(chan *RegistryError, 1)
	go func() {
		useResult <- registry.UseSocket(context.Background(), admission.Token, AddressFamilyIPv4, func(int) error {
			close(descriptorStarted)
			<-releaseDescriptor
			if kind == cleanupRaceExpiry {
				return errors.New("controlled descriptor operation failure")
			}
			return nil
		})
	}()
	waitSignal(t, descriptorStarted, "descriptor operation")

	activityResult := make(chan *RegistryError, 1)
	terminalResult := make(chan cleanupTerminalResult, 1)
	terminalStarted := make(chan struct{})
	if kind == cleanupRaceExpiry {
		clock.advance(limits.IdleTimeout)
		go func() {
			close(terminalStarted)
			terminalResult <- cleanupTerminalResult{failure: registry.deliverTimerArm(context.Background(), 1)}
		}()
		waitSignal(t, terminalStarted, "expiry submission")
		waitFor(t, func() bool { return len(registry.commands) == 1 })
		go func() { activityResult <- registry.RecordActivity(context.Background(), admission.Token) }()
	} else {
		go func() { activityResult <- registry.RecordActivity(context.Background(), admission.Token) }()
		waitFor(t, func() bool { return len(registry.commands) == 1 })
		if kind == cleanupRaceCancellation {
			cancel()
		} else {
			go func() {
				close(terminalStarted)
				switch kind {
				case cleanupRaceAssociationClose:
					result, closeFailure := registry.CloseAssociation(context.Background(), admission.Token, reason)
					terminalResult <- cleanupTerminalResult{close: result, failure: closeFailure}
				case cleanupRaceReplacement:
					terminalResult <- cleanupTerminalResult{
						failure: registry.ReplaceGeneration(context.Background(), generation, generation+1),
					}
				case cleanupRaceShutdown:
					terminalResult <- cleanupTerminalResult{
						failure: registry.Shutdown(context.Background(), generation, reason),
					}
				}
			}()
			waitSignal(t, terminalStarted, "terminal submission")
		}
	}

	close(releaseDescriptor)
	useFailure := receiveRegistryFailure(t, useResult, "descriptor result")
	if kind == cleanupRaceExpiry {
		if useFailure == nil || useFailure.Code != ErrorOperationFailure {
			t.Fatalf("expiry descriptor result = %#v", useFailure)
		}
	} else if useFailure != nil {
		t.Fatalf("descriptor result = %v", useFailure)
	}

	if kind != cleanupRaceCancellation {
		terminal := receiveTerminalResult(t, terminalResult)
		if terminal.failure != nil {
			t.Fatalf("terminal result: %v", terminal.failure)
		}
		if kind == cleanupRaceAssociationClose && !terminal.close.Closed {
			t.Fatalf("association close result = %#v", terminal.close)
		}
	}
	activityFailure := receiveRegistryFailure(t, activityResult, "activity result")
	switch kind {
	case cleanupRaceExpiry:
		if activityFailure == nil || activityFailure.Code != ErrorUnknownAssociation {
			t.Fatalf("expiry activity result = %#v", activityFailure)
		}
	case cleanupRaceCancellation:
		if activityFailure != nil && activityFailure.Code != ErrorRegistryClosed {
			t.Fatalf("cancellation activity result = %#v", activityFailure)
		}
	default:
		if activityFailure != nil {
			t.Fatalf("linearized pre-teardown activity result = %v", activityFailure)
		}
	}

	if kind == cleanupRaceShutdown || kind == cleanupRaceCancellation {
		waitDone(t, registry.Done())
		if factory.totalCloseCalls() != 1 || clock.activeTimers() != 0 {
			t.Fatalf("terminal baseline closes=%d timers=%d", factory.totalCloseCalls(), clock.activeTimers())
		}
		if _, snapshotFailure := registry.Snapshot(testContext(t)); snapshotFailure == nil || snapshotFailure.Code != ErrorRegistryClosed {
			t.Fatalf("terminal owner remained reachable: %#v", snapshotFailure)
		}
		return
	}

	if kind == cleanupRaceExpiry {
		event := receiveEvent(t, registry.Events())
		if event.Kind != EventIdleExpired || event.Token != admission.Token {
			t.Fatalf("expiry race event = %#v", event)
		}
	}
	assertRegistryBaseline(t, registry, clock)
	if factory.totalCloseCalls() != 1 {
		t.Fatalf("teardown close count = %d", factory.totalCloseCalls())
	}

	currentGeneration := generation
	if kind == cleanupRaceReplacement {
		currentGeneration++
	}
	replacement := mustEnsure(t, registry, currentGeneration, 1, AddressFamilyIPv4)
	if replacement.Token.Incarnation == admission.Token.Incarnation {
		t.Fatalf("incarnation reused after teardown: old=%#v new=%#v", admission.Token, replacement.Token)
	}
	staleFailure := registry.RecordActivity(testContext(t), admission.Token)
	wantStale := ErrorStaleAssociation
	if kind == cleanupRaceReplacement {
		wantStale = ErrorStaleGeneration
	}
	if staleFailure == nil || staleFailure.Code != wantStale {
		t.Fatalf("stale token result = %#v, want %s", staleFailure, wantStale)
	}
	closed, closeFailure := registry.CloseAssociation(testContext(t), replacement.Token, CloseReasonLocal)
	if closeFailure != nil || !closed.Closed {
		t.Fatalf("replacement close = %#v failure=%v", closed, closeFailure)
	}
	assertRegistryBaseline(t, registry, clock)
	if factory.totalCloseCalls() != 2 {
		t.Fatalf("repeated lifecycle close count = %d", factory.totalCloseCalls())
	}
	if shutdownFailure := registry.Shutdown(testContext(t), currentGeneration, CloseReasonProcessTermination); shutdownFailure != nil {
		t.Fatalf("race registry shutdown: %v", shutdownFailure)
	}
	waitDone(t, registry.Done())
}

func assertRegistryBaseline(t *testing.T, registry *Registry, clock *fakeClock) {
	t.Helper()
	snapshot := mustSnapshot(t, registry)
	if snapshot.Associations != 0 || snapshot.Sockets != 0 || snapshot.Timers != 0 ||
		snapshot.PendingCloseEvents != 0 || clock.activeTimers() != 0 {
		t.Fatalf("registry baseline = %#v physicalTimers=%d", snapshot, clock.activeTimers())
	}
}

func waitSignal(t *testing.T, signal <-chan struct{}, label string) {
	t.Helper()
	select {
	case <-signal:
	case <-time.After(time.Second):
		t.Fatalf("timed out waiting for %s", label)
	}
}

func receiveRegistryFailure(t *testing.T, result <-chan *RegistryError, label string) *RegistryError {
	t.Helper()
	select {
	case failure := <-result:
		return failure
	case <-time.After(time.Second):
		t.Fatalf("timed out waiting for %s", label)
		return nil
	}
}

func receiveTerminalResult(t *testing.T, result <-chan cleanupTerminalResult) cleanupTerminalResult {
	t.Helper()
	select {
	case terminal := <-result:
		return terminal
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for terminal result")
		return cleanupTerminalResult{}
	}
}

func testLimits(associations, sockets, timers, pending uint32) RegistryLimits {
	return RegistryLimits{
		MaxAssociations: associations, MaxSockets: sockets, MaxTimers: timers, MaxPendingCloses: pending,
		IdleTimeout: 10 * time.Second,
	}
}

func newTestRegistry(
	t *testing.T,
	generation uint64,
	limits RegistryLimits,
) (*Registry, *fakeClock, *fakeSocketFactory) {
	t.Helper()
	clock := newFakeClock()
	factory := newFakeSocketFactory()
	registry, failure := NewRegistry(context.Background(), generation, limits, clock, factory)
	if failure != nil {
		t.Fatalf("new registry: %v", failure)
	}
	t.Cleanup(func() {
		_ = registry.Shutdown(context.Background(), generation, CloseReasonProcessTermination)
	})
	return registry, clock, factory
}

func mustEnsure(t *testing.T, registry *Registry, generation uint64, associationID uint32, family AddressFamily) Admission {
	t.Helper()
	admission, failure := registry.Ensure(testContext(t), generation, associationID, family)
	if failure != nil {
		t.Fatalf("ensure generation=%d association=%d family=%d: %v", generation, associationID, family, failure)
	}
	return admission
}

func mustSnapshot(t *testing.T, registry *Registry) Snapshot {
	t.Helper()
	snapshot, failure := registry.Snapshot(testContext(t))
	if failure != nil {
		t.Fatalf("snapshot: %v", failure)
	}
	return snapshot
}

func testContext(t *testing.T) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	t.Cleanup(cancel)
	return ctx
}

func receiveEvent(t *testing.T, events <-chan Event) Event {
	t.Helper()
	select {
	case event := <-events:
		return event
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for registry event")
		return Event{}
	}
}

func waitFor(t *testing.T, condition func() bool) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for !condition() {
		if time.Now().After(deadline) {
			t.Fatal("condition did not become true")
		}
		runtime.Gosched()
	}
}

func waitDone(t *testing.T, done <-chan struct{}) {
	t.Helper()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("registry owner did not stop")
	}
}

type fakeClock struct {
	mu     sync.Mutex
	now    time.Time
	timers []*fakeTimer
}

func newFakeClock() *fakeClock {
	return &fakeClock{now: time.Unix(1_000, 0)}
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *fakeClock) NewTimer(duration time.Duration) MonotonicTimer {
	c.mu.Lock()
	defer c.mu.Unlock()
	timer := &fakeTimer{
		clock: c, deadline: c.now.Add(duration), channel: make(chan time.Time, 1), active: true,
	}
	c.timers = append(c.timers, timer)
	return timer
}

func (c *fakeClock) advance(duration time.Duration) {
	c.mu.Lock()
	c.now = c.now.Add(duration)
	now := c.now
	for _, timer := range c.timers {
		if timer.active && !timer.deadline.After(now) {
			timer.active = false
			timer.channel <- now
		}
	}
	c.mu.Unlock()
}

func (c *fakeClock) timerCount() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.timers)
}

func (c *fakeClock) activeTimers() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	count := 0
	for _, timer := range c.timers {
		if timer.active {
			count++
		}
	}
	return count
}

func (c *fakeClock) activeDeadline() (time.Time, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, timer := range c.timers {
		if timer.active {
			return timer.deadline, true
		}
	}
	return time.Time{}, false
}

type fakeTimer struct {
	clock    *fakeClock
	deadline time.Time
	channel  chan time.Time
	active   bool
}

func (t *fakeTimer) C() <-chan time.Time { return t.channel }
func (t *fakeTimer) Stop() bool {
	t.clock.mu.Lock()
	defer t.clock.mu.Unlock()
	wasActive := t.active
	t.active = false
	return wasActive
}

type fakeSocketFactory struct {
	mu             sync.Mutex
	nextDescriptor int
	opened         []*fakeSocket
	openedFamilies []AddressFamily
	failAt         int
	partial        bool
}

func newFakeSocketFactory() *fakeSocketFactory {
	return &fakeSocketFactory{nextDescriptor: 100}
}

func (f *fakeSocketFactory) Open(family AddressFamily) (Socket, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	socket := &fakeSocket{descriptor: f.nextDescriptor}
	f.nextDescriptor++
	f.opened = append(f.opened, socket)
	f.openedFamilies = append(f.openedFamilies, family)
	if f.failAt == len(f.opened) {
		partial := f.partial
		f.failAt = 0
		f.partial = false
		if partial {
			return socket, errors.New("controlled socket failure")
		}
		return nil, errors.New("controlled socket failure")
	}
	return socket, nil
}

func (f *fakeSocketFactory) failNext(partial bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.failAt = len(f.opened) + 1
	f.partial = partial
}

func (f *fakeSocketFactory) failOnOpen(number int, partial bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.failAt = number
	f.partial = partial
}

func (f *fakeSocketFactory) openCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.opened)
}

func (f *fakeSocketFactory) families() []AddressFamily {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]AddressFamily(nil), f.openedFamilies...)
}

func (f *fakeSocketFactory) socket(index int) *fakeSocket {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.opened[index]
}

func (f *fakeSocketFactory) totalCloseCalls() int {
	f.mu.Lock()
	sockets := append([]*fakeSocket(nil), f.opened...)
	f.mu.Unlock()
	total := 0
	for _, socket := range sockets {
		total += socket.closeCalls()
	}
	return total
}

type fakeSocket struct {
	mu         sync.Mutex
	descriptor int
	closed     bool
	closes     int
}

func (s *fakeSocket) UseDescriptor(operation func(int) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return errDescriptorClosed
	}
	return operation(s.descriptor)
}

func (s *fakeSocket) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil
	}
	s.closed = true
	s.closes++
	return nil
}

func (s *fakeSocket) closeCalls() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.closes
}
