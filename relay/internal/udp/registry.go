package udp

import (
	"container/heap"
	"context"
	"fmt"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

type RegistryLimits struct {
	MaxAssociations  uint32
	MaxSockets       uint32
	MaxTimers        uint32
	MaxPendingCloses uint32
	IdleTimeout      time.Duration
}

func RegistryLimitsFromEffective(limits protocol.EffectiveLimits) RegistryLimits {
	return RegistryLimits{
		MaxAssociations:  limits.MaxAssociations,
		MaxSockets:       limits.MaxAssociations * 2,
		MaxTimers:        limits.MaxAssociations,
		MaxPendingCloses: limits.MaxAssociations,
		IdleTimeout:      time.Duration(limits.IdleTimeoutMilliseconds) * time.Millisecond,
	}
}

type ErrorCode string

const (
	ErrorInvalidConfiguration ErrorCode = "invalidConfiguration"
	ErrorInvalidAssociationID ErrorCode = "invalidAssociationID"
	ErrorInvalidAddressFamily ErrorCode = "invalidAddressFamily"
	ErrorStaleGeneration      ErrorCode = "staleGeneration"
	ErrorRegistryClosed       ErrorCode = "registryClosed"
	ErrorAssociationLimit     ErrorCode = "associationLimit"
	ErrorSocketLimit          ErrorCode = "socketLimit"
	ErrorTimerLimit           ErrorCode = "timerLimit"
	ErrorPendingCloseLimit    ErrorCode = "pendingCloseLimit"
	ErrorSocketFailure        ErrorCode = "socketFailure"
	ErrorUnknownAssociation   ErrorCode = "unknownAssociation"
	ErrorStaleAssociation     ErrorCode = "staleAssociation"
	ErrorOperationFailure     ErrorCode = "operationFailure"
	ErrorCancelled            ErrorCode = "cancelled"
)

type RegistryError struct {
	Code        ErrorCode
	Scope       string
	Disposition string
}

func (e *RegistryError) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf("relayUDPRegistry code=%s scope=%s disposition=%s", e.Code, e.Scope, e.Disposition)
}

func configurationError() *RegistryError {
	return &RegistryError{Code: ErrorInvalidConfiguration, Scope: "session", Disposition: "closeSession"}
}

func associationError(code ErrorCode) *RegistryError {
	return &RegistryError{Code: code, Scope: "association", Disposition: "rejectDatagram"}
}

func sessionError(code ErrorCode) *RegistryError {
	return &RegistryError{Code: code, Scope: "session", Disposition: "closeSession"}
}

func (limits RegistryLimits) validate() *RegistryError {
	if limits.MaxAssociations < protocol.MaxAssociationsFloor ||
		limits.MaxAssociations > protocol.MaxAssociationsRelayHardCeiling ||
		limits.MaxSockets == 0 || limits.MaxSockets > limits.MaxAssociations*2 ||
		limits.MaxTimers == 0 || limits.MaxTimers > limits.MaxAssociations ||
		limits.MaxPendingCloses == 0 || limits.MaxPendingCloses > limits.MaxAssociations ||
		limits.IdleTimeout < time.Duration(protocol.IdleTimeoutFloor)*time.Millisecond ||
		limits.IdleTimeout > time.Duration(protocol.IdleTimeoutRelayHardCeiling)*time.Millisecond {
		return configurationError()
	}
	return nil
}

type AssociationToken struct {
	Generation    uint64
	AssociationID uint32
	Incarnation   uint64
}

type Admission struct {
	Token              AssociationToken
	Family             AddressFamily
	AssociationCreated bool
	SocketCreated      bool
}

// FamilySetAdmission reports one atomic family-set transaction. Families is
// canonicalized to IPv4 then IPv6, and SocketsCreated counts only descriptors
// opened by this transaction.
type FamilySetAdmission struct {
	Token              AssociationToken
	Families           []AddressFamily
	AssociationCreated bool
	SocketsCreated     uint32
}

// AssociationReservation admits lifecycle state without opening a socket.
// The unexported lifecycle context is cancelled exactly once when this
// incarnation is retired, replaced, or the registry stops.
type AssociationReservation struct {
	Token              AssociationToken
	AssociationCreated bool
	lifecycle          context.Context
}

type CloseReason string

const (
	CloseReasonLocal              CloseReason = "localClose"
	CloseReasonRemote             CloseReason = "remoteClose"
	CloseReasonIdleExpiry         CloseReason = "idleExpiry"
	CloseReasonSessionClose       CloseReason = "sessionClose"
	CloseReasonSessionLoss        CloseReason = "sessionLoss"
	CloseReasonSessionReplacement CloseReason = "sessionReplacement"
	CloseReasonProcessTermination CloseReason = "processTermination"
	CloseReasonCancellation       CloseReason = "cancellation"
)

type CloseResult struct {
	Closed bool
	Stale  bool
}

type EventKind string

const EventIdleExpired EventKind = "idleExpired"

type Event struct {
	Kind  EventKind
	Token AssociationToken
}

type Counters struct {
	AssociationsAdmitted       uint64
	ExistingAssociationsUsed   uint64
	AssociationRejected        uint64
	SocketLimitRejected        uint64
	TimerLimitRejected         uint64
	PendingCloseLimitRejected  uint64
	InvalidAssociationRejected uint64
	InvalidFamilyRejected      uint64
	SocketCreationFailed       uint64
	AtomicAdmissionRolledBack  uint64
	SocketOperationFailed      uint64
	SocketsClosed              uint64
	SocketCloseFailed          uint64
	IdleExpired                uint64
	StaleGenerationIgnored     uint64
	StaleAssociationIgnored    uint64
	UnknownAssociationIgnored  uint64
	StaleTimerArmsIgnored      uint64
	SessionCleanups            uint64
	GenerationReplacements     uint64
	CancellationCleanups       uint64
	MaximumAssociations        uint32
	MaximumSockets             uint32
	MaximumTimers              uint32
	MaximumPendingCloses       uint32
}

type Snapshot struct {
	Generation         uint64
	Associations       uint32
	Sockets            uint32
	Timers             uint32
	PendingCloseEvents uint32
	OwnerRunning       bool
	Counters           Counters
}

type Registry struct {
	commands chan request
	events   chan Event
	done     chan struct{}
}

func NewRegistry(
	parent context.Context,
	generation uint64,
	limits RegistryLimits,
	clock MonotonicClock,
	factory SocketFactory,
) (*Registry, *RegistryError) {
	if generation == 0 || parent == nil || factory == nil {
		return nil, configurationError()
	}
	if failure := limits.validate(); failure != nil {
		return nil, failure
	}
	if clock == nil {
		clock = systemClock{}
	}
	registry := &Registry{
		commands: make(chan request, 1),
		events:   make(chan Event, limits.MaxPendingCloses),
		done:     make(chan struct{}),
	}
	state := registryState{
		generation:   generation,
		limits:       limits,
		clock:        clock,
		factory:      factory,
		associations: make(map[uint32]*association),
		events:       registry.events,
	}
	go registry.run(parent, &state)
	return registry, nil
}

func (r *Registry) Events() <-chan Event  { return r.events }
func (r *Registry) Done() <-chan struct{} { return r.done }

func (r *Registry) Ensure(
	ctx context.Context,
	generation uint64,
	associationID uint32,
	family AddressFamily,
) (Admission, *RegistryError) {
	set, failure := r.EnsureFamilies(ctx, generation, associationID, family)
	return Admission{
		Token:              set.Token,
		Family:             family,
		AssociationCreated: set.AssociationCreated,
		SocketCreated:      set.SocketsCreated == 1,
	}, failure
}

// Reserve admits association capacity and returns an incarnation-scoped token
// without creating a descriptor. It is used before asynchronous destination
// resolution so stale work can never attach to a reused association ID.
func (r *Registry) Reserve(
	ctx context.Context,
	generation uint64,
	associationID uint32,
) (AssociationReservation, *RegistryError) {
	response, failure := r.submit(ctx, request{
		kind: requestReserve, generation: generation, associationID: associationID,
	})
	return response.reservation, failure
}

// EnsureFamilies atomically admits every requested descriptor family. All
// required credits are checked before the first socket is opened. If any
// family fails, every socket opened by the transaction and every socket
// already owned by that association is retired exactly once.
func (r *Registry) EnsureFamilies(
	ctx context.Context,
	generation uint64,
	associationID uint32,
	families ...AddressFamily,
) (FamilySetAdmission, *RegistryError) {
	response, failure := r.submit(ctx, request{
		kind: requestEnsure, generation: generation, associationID: associationID,
		families: append([]AddressFamily(nil), families...),
	})
	return response.familySetAdmission, failure
}

// EnsureTokenFamilies opens only the requested missing family sockets when the
// exact generation and incarnation are still active.
func (r *Registry) EnsureTokenFamilies(
	ctx context.Context,
	token AssociationToken,
	families ...AddressFamily,
) (FamilySetAdmission, *RegistryError) {
	response, failure := r.submit(ctx, request{
		kind: requestEnsureToken, token: token,
		families: append([]AddressFamily(nil), families...),
	})
	return response.familySetAdmission, failure
}

func (r *Registry) RecordActivity(ctx context.Context, token AssociationToken) *RegistryError {
	_, failure := r.submit(ctx, request{kind: requestActivity, token: token})
	return failure
}

// UseSocket serializes a nonblocking descriptor operation with close and
// generation replacement. The callback must perform only bounded nonblocking
// work; datagram parsing, resolution, retry, and queueing do not belong here.
func (r *Registry) UseSocket(
	ctx context.Context,
	token AssociationToken,
	family AddressFamily,
	operation func(descriptor int) error,
) *RegistryError {
	if operation == nil {
		_, failure := r.submit(ctx, request{kind: requestUse, token: token, family: family})
		return failure
	}
	return r.UseSocketOperation(ctx, token, family, func(descriptor int) (bool, error) {
		if err := operation(descriptor); err != nil {
			return false, err
		}
		return true, nil
	})
}

// UseSocketOperation serializes one bounded nonblocking descriptor operation
// with association close and generation replacement. The callback reports
// whether actual datagram activity occurred. A readiness miss reports
// activity=false and err=nil so it neither refreshes the idle deadline nor
// becomes a socket failure.
func (r *Registry) UseSocketOperation(
	ctx context.Context,
	token AssociationToken,
	family AddressFamily,
	operation func(descriptor int) (activity bool, err error),
) *RegistryError {
	_, failure := r.submit(ctx, request{
		kind: requestUse, token: token, family: family, socketOperation: operation,
	})
	return failure
}

func (r *Registry) CloseAssociation(
	ctx context.Context,
	token AssociationToken,
	reason CloseReason,
) (CloseResult, *RegistryError) {
	response, failure := r.submit(ctx, request{kind: requestClose, token: token, reason: reason})
	return response.close, failure
}

func (r *Registry) ReplaceGeneration(
	ctx context.Context,
	expectedGeneration uint64,
	newGeneration uint64,
) *RegistryError {
	_, failure := r.submit(ctx, request{
		kind: requestReplace, generation: expectedGeneration, newGeneration: newGeneration,
	})
	return failure
}

func (r *Registry) Snapshot(ctx context.Context) (Snapshot, *RegistryError) {
	response, failure := r.submit(ctx, request{kind: requestSnapshot})
	return response.snapshot, failure
}

func (r *Registry) Shutdown(ctx context.Context, generation uint64, reason CloseReason) *RegistryError {
	_, failure := r.submit(ctx, request{kind: requestShutdown, generation: generation, reason: reason})
	return failure
}

// deliverTimerArm is an internal controlled seam used to prove that an
// obsolete physical timer callback cannot mutate current owner state.
func (r *Registry) deliverTimerArm(ctx context.Context, arm uint64) *RegistryError {
	_, failure := r.submit(ctx, request{kind: requestTimerArm, timerArm: arm})
	return failure
}

func (r *Registry) submit(ctx context.Context, command request) (response, *RegistryError) {
	if ctx == nil {
		return response{}, sessionError(ErrorCancelled)
	}
	command.ctx = ctx
	command.response = make(chan response, 1)
	select {
	case <-ctx.Done():
		return response{}, sessionError(ErrorCancelled)
	case <-r.done:
		return response{}, sessionError(ErrorRegistryClosed)
	case r.commands <- command:
	}
	select {
	case <-ctx.Done():
		return response{}, sessionError(ErrorCancelled)
	case result := <-command.response:
		return result, result.failure
	case <-r.done:
		select {
		case result := <-command.response:
			return result, result.failure
		default:
			return response{}, sessionError(ErrorRegistryClosed)
		}
	}
}

func (r *Registry) run(parent context.Context, state *registryState) {
	defer close(r.done)
	defer close(r.events)
	for {
		timerChannel := state.timerChannel
		timerArm := state.timerArm
		select {
		case <-parent.Done():
			state.shutdown(CloseReasonCancellation)
			state.counters.CancellationCleanups++
			return
		case <-timerChannel:
			state.expire(timerArm)
		case command := <-r.commands:
			result, terminal := state.process(command)
			command.response <- result
			if terminal {
				return
			}
		}
	}
}

type requestKind uint8

const (
	requestReserve requestKind = iota
	requestEnsure
	requestEnsureToken
	requestActivity
	requestUse
	requestClose
	requestReplace
	requestSnapshot
	requestShutdown
	requestTimerArm
)

type request struct {
	kind            requestKind
	ctx             context.Context
	generation      uint64
	newGeneration   uint64
	associationID   uint32
	token           AssociationToken
	family          AddressFamily
	families        []AddressFamily
	reason          CloseReason
	timerArm        uint64
	socketOperation func(int) (bool, error)
	response        chan response
}

type response struct {
	reservation        AssociationReservation
	familySetAdmission FamilySetAdmission
	close              CloseResult
	snapshot           Snapshot
	failure            *RegistryError
}

type registryState struct {
	generation      uint64
	limits          RegistryLimits
	clock           MonotonicClock
	factory         SocketFactory
	associations    map[uint32]*association
	deadlines       deadlineHeap
	events          chan Event
	socketCount     uint32
	nextIncarnation uint64
	timer           MonotonicTimer
	timerChannel    <-chan time.Time
	timerArm        uint64
	counters        Counters
}

type association struct {
	token           AssociationToken
	sockets         map[AddressFamily]Socket
	deadline        *deadlineEntry
	lifecycle       context.Context
	cancelLifecycle context.CancelFunc
}

func (s *registryState) process(command request) (response, bool) {
	if command.ctx.Err() != nil {
		return response{failure: sessionError(ErrorCancelled)}, false
	}
	switch command.kind {
	case requestReserve:
		reservation, failure := s.reserve(command.generation, command.associationID)
		return response{reservation: reservation, failure: failure}, false
	case requestEnsure:
		admission, failure := s.ensureFamilies(command.generation, command.associationID, command.families)
		return response{familySetAdmission: admission, failure: failure}, false
	case requestEnsureToken:
		admission, failure := s.ensureTokenFamilies(command.token, command.families)
		return response{familySetAdmission: admission, failure: failure}, false
	case requestActivity:
		failure := s.activity(command.token)
		return response{failure: failure}, false
	case requestUse:
		failure := s.use(command.token, command.family, command.socketOperation)
		return response{failure: failure}, false
	case requestClose:
		result := s.close(command.token, command.reason)
		return response{close: result}, false
	case requestReplace:
		failure := s.replace(command.generation, command.newGeneration)
		return response{failure: failure}, false
	case requestSnapshot:
		return response{snapshot: s.snapshot(true)}, false
	case requestShutdown:
		if command.generation != s.generation {
			s.counters.StaleGenerationIgnored++
			return response{failure: sessionError(ErrorStaleGeneration)}, false
		}
		s.shutdown(command.reason)
		return response{}, true
	case requestTimerArm:
		s.expire(command.timerArm)
		return response{}, false
	default:
		return response{failure: sessionError(ErrorInvalidConfiguration)}, false
	}
}

func (s *registryState) reserve(
	generation uint64,
	associationID uint32,
) (AssociationReservation, *RegistryError) {
	if generation != s.generation {
		s.counters.StaleGenerationIgnored++
		return AssociationReservation{}, associationError(ErrorStaleGeneration)
	}
	if associationID == 0 {
		s.counters.InvalidAssociationRejected++
		return AssociationReservation{}, associationError(ErrorInvalidAssociationID)
	}
	if existing := s.associations[associationID]; existing != nil {
		s.counters.ExistingAssociationsUsed++
		return AssociationReservation{Token: existing.token, lifecycle: existing.lifecycle}, nil
	}
	if failure := s.checkAssociationCapacity(); failure != nil {
		return AssociationReservation{}, failure
	}
	entry := s.newAssociation(associationID)
	return AssociationReservation{
		Token: entry.token, AssociationCreated: true, lifecycle: entry.lifecycle,
	}, nil
}

func (s *registryState) ensureFamilies(
	generation uint64,
	associationID uint32,
	requested []AddressFamily,
) (FamilySetAdmission, *RegistryError) {
	if generation != s.generation {
		s.counters.StaleGenerationIgnored++
		return FamilySetAdmission{}, associationError(ErrorStaleGeneration)
	}
	if associationID == 0 {
		s.counters.InvalidAssociationRejected++
		return FamilySetAdmission{}, associationError(ErrorInvalidAssociationID)
	}
	families, valid := canonicalFamilies(requested)
	if !valid {
		s.counters.InvalidFamilyRejected++
		return FamilySetAdmission{}, associationError(ErrorInvalidAddressFamily)
	}

	existing := s.associations[associationID]
	missing := make([]AddressFamily, 0, len(families))
	for _, family := range families {
		if existing == nil || existing.sockets[family] == nil {
			missing = append(missing, family)
		}
	}
	if existing != nil && len(missing) == 0 {
		s.counters.ExistingAssociationsUsed++
		return FamilySetAdmission{Token: existing.token, Families: families}, nil
	}

	if existing == nil {
		if failure := s.checkAssociationCapacity(); failure != nil {
			return FamilySetAdmission{}, failure
		}
	}
	if s.socketCount > s.limits.MaxSockets ||
		uint32(len(missing)) > s.limits.MaxSockets-s.socketCount {
		s.counters.SocketLimitRejected++
		return FamilySetAdmission{}, associationError(ErrorSocketLimit)
	}

	opened := make(map[AddressFamily]Socket, len(missing))
	for _, family := range missing {
		socket, failure := s.openSocket(family)
		if failure != nil {
			s.rollbackAdmission(existing, opened)
			return FamilySetAdmission{}, failure
		}
		opened[family] = socket
	}

	entry := existing
	created := entry == nil
	if created {
		entry = s.newAssociation(associationID)
	}
	for family, socket := range opened {
		entry.sockets[family] = socket
	}
	s.socketCount += uint32(len(opened))
	s.updateHighWater()
	return FamilySetAdmission{
		Token: entry.token, Families: families, AssociationCreated: created,
		SocketsCreated: uint32(len(opened)),
	}, nil
}

func (s *registryState) ensureTokenFamilies(
	token AssociationToken,
	requested []AddressFamily,
) (FamilySetAdmission, *RegistryError) {
	families, valid := canonicalFamilies(requested)
	if !valid {
		s.counters.InvalidFamilyRejected++
		return FamilySetAdmission{}, associationError(ErrorInvalidAddressFamily)
	}
	entry, failure := s.lookup(token)
	if failure != nil {
		return FamilySetAdmission{}, failure
	}
	missing := make([]AddressFamily, 0, len(families))
	for _, family := range families {
		if entry.sockets[family] == nil {
			missing = append(missing, family)
		}
	}
	if len(missing) == 0 {
		s.counters.ExistingAssociationsUsed++
		return FamilySetAdmission{Token: token, Families: families}, nil
	}
	if s.socketCount > s.limits.MaxSockets || uint32(len(missing)) > s.limits.MaxSockets-s.socketCount {
		s.counters.SocketLimitRejected++
		return FamilySetAdmission{}, associationError(ErrorSocketLimit)
	}
	opened := make(map[AddressFamily]Socket, len(missing))
	for _, family := range missing {
		socket, openFailure := s.openSocket(family)
		if openFailure != nil {
			s.rollbackAdmission(entry, opened)
			return FamilySetAdmission{}, openFailure
		}
		opened[family] = socket
	}
	for family, socket := range opened {
		entry.sockets[family] = socket
	}
	s.socketCount += uint32(len(opened))
	s.updateHighWater()
	return FamilySetAdmission{
		Token: token, Families: families, SocketsCreated: uint32(len(opened)),
	}, nil
}

func (s *registryState) checkAssociationCapacity() *RegistryError {
	if uint32(len(s.associations)) >= s.limits.MaxAssociations {
		s.counters.AssociationRejected++
		return associationError(ErrorAssociationLimit)
	}
	if uint32(len(s.deadlines)) >= s.limits.MaxTimers {
		s.counters.TimerLimitRejected++
		return associationError(ErrorTimerLimit)
	}
	if uint32(len(s.associations)+len(s.events)) >= s.limits.MaxPendingCloses {
		s.counters.PendingCloseLimitRejected++
		return associationError(ErrorPendingCloseLimit)
	}
	return nil
}

func (s *registryState) newAssociation(associationID uint32) *association {
	s.nextIncarnation++
	lifecycle, cancel := context.WithCancel(context.Background())
	entry := &association{
		token: AssociationToken{
			Generation: s.generation, AssociationID: associationID, Incarnation: s.nextIncarnation,
		},
		sockets: make(map[AddressFamily]Socket, 2), lifecycle: lifecycle, cancelLifecycle: cancel,
	}
	entry.deadline = &deadlineEntry{association: entry, index: -1}
	s.associations[associationID] = entry
	heap.Push(&s.deadlines, entry.deadline)
	s.counters.AssociationsAdmitted++
	// Admission establishes a bounded initial lifetime. Subsequent Reserve,
	// Ensure, and family attachment calls deliberately leave this deadline
	// unchanged; only observed datagram activity may refresh it.
	s.touch(entry)
	return entry
}

func canonicalFamilies(requested []AddressFamily) ([]AddressFamily, bool) {
	if len(requested) == 0 {
		return nil, false
	}
	wantsIPv4 := false
	wantsIPv6 := false
	for _, family := range requested {
		switch family {
		case AddressFamilyIPv4:
			wantsIPv4 = true
		case AddressFamilyIPv6:
			wantsIPv6 = true
		default:
			return nil, false
		}
	}
	families := make([]AddressFamily, 0, 2)
	if wantsIPv4 {
		families = append(families, AddressFamilyIPv4)
	}
	if wantsIPv6 {
		families = append(families, AddressFamilyIPv6)
	}
	return families, true
}

func (s *registryState) rollbackAdmission(existing *association, opened map[AddressFamily]Socket) {
	for _, socket := range opened {
		s.closeSocket(socket)
	}
	if existing != nil {
		s.retire(existing)
		s.armTimer()
	}
	s.counters.AtomicAdmissionRolledBack++
}

func (s *registryState) openSocket(family AddressFamily) (Socket, *RegistryError) {
	socket, err := s.factory.Open(family)
	if err != nil || socket == nil {
		if socket != nil {
			s.closeSocket(socket)
		}
		s.counters.SocketCreationFailed++
		return nil, associationError(ErrorSocketFailure)
	}
	return socket, nil
}

func (s *registryState) activity(token AssociationToken) *RegistryError {
	entry, failure := s.lookup(token)
	if failure != nil {
		return failure
	}
	s.touch(entry)
	return nil
}

func (s *registryState) use(
	token AssociationToken,
	family AddressFamily,
	operation func(int) (bool, error),
) *RegistryError {
	if !family.valid() || operation == nil {
		if !family.valid() {
			s.counters.InvalidFamilyRejected++
			return associationError(ErrorInvalidAddressFamily)
		}
		s.counters.SocketOperationFailed++
		return associationError(ErrorOperationFailure)
	}
	entry, failure := s.lookup(token)
	if failure != nil {
		return failure
	}
	socket := entry.sockets[family]
	if socket == nil {
		return associationError(ErrorUnknownAssociation)
	}
	activity := false
	if err := socket.UseDescriptor(func(descriptor int) error {
		var err error
		activity, err = operation(descriptor)
		return err
	}); err != nil {
		s.counters.SocketOperationFailed++
		return associationError(ErrorOperationFailure)
	}
	if activity {
		s.touch(entry)
	}
	return nil
}

func (s *registryState) lookup(token AssociationToken) (*association, *RegistryError) {
	if token.Generation != s.generation {
		s.counters.StaleGenerationIgnored++
		return nil, associationError(ErrorStaleGeneration)
	}
	entry := s.associations[token.AssociationID]
	if entry == nil {
		s.counters.UnknownAssociationIgnored++
		return nil, associationError(ErrorUnknownAssociation)
	}
	if entry.token != token {
		s.counters.StaleAssociationIgnored++
		return nil, associationError(ErrorStaleAssociation)
	}
	return entry, nil
}

func (s *registryState) close(token AssociationToken, _ CloseReason) CloseResult {
	if token.Generation != s.generation {
		s.counters.StaleGenerationIgnored++
		return CloseResult{Stale: true}
	}
	entry := s.associations[token.AssociationID]
	if entry == nil {
		s.counters.UnknownAssociationIgnored++
		return CloseResult{}
	}
	if entry.token != token {
		s.counters.StaleAssociationIgnored++
		return CloseResult{Stale: true}
	}
	s.retire(entry)
	s.armTimer()
	return CloseResult{Closed: true}
}

func (s *registryState) replace(expectedGeneration uint64, newGeneration uint64) *RegistryError {
	if expectedGeneration != s.generation {
		s.counters.StaleGenerationIgnored++
		return sessionError(ErrorStaleGeneration)
	}
	if newGeneration == 0 || newGeneration == s.generation {
		return sessionError(ErrorInvalidConfiguration)
	}
	s.cleanupAssociations()
	s.drainEvents()
	s.generation = newGeneration
	s.counters.SessionCleanups++
	s.counters.GenerationReplacements++
	return nil
}

func (s *registryState) touch(entry *association) {
	entry.deadline.epoch++
	entry.deadline.at = s.clock.Now().Add(s.limits.IdleTimeout)
	if entry.deadline.index >= 0 {
		heap.Fix(&s.deadlines, entry.deadline.index)
	}
	s.armTimer()
}

func (s *registryState) expire(arm uint64) {
	if arm != s.timerArm {
		s.counters.StaleTimerArmsIgnored++
		return
	}
	s.timer = nil
	s.timerChannel = nil
	now := s.clock.Now()
	for len(s.deadlines) > 0 {
		entry := s.deadlines[0]
		if entry.at.After(now) {
			break
		}
		token := entry.association.token
		s.retire(entry.association)
		s.counters.IdleExpired++
		s.events <- Event{Kind: EventIdleExpired, Token: token}
	}
	s.armTimer()
}

func (s *registryState) retire(entry *association) {
	entry.cancelLifecycle()
	delete(s.associations, entry.token.AssociationID)
	if entry.deadline.index >= 0 {
		heap.Remove(&s.deadlines, entry.deadline.index)
	}
	for family, socket := range entry.sockets {
		s.closeSocket(socket)
		s.socketCount--
		delete(entry.sockets, family)
	}
}

func (s *registryState) closeSocket(socket Socket) {
	if err := socket.Close(); err != nil {
		s.counters.SocketCloseFailed++
	}
	s.counters.SocketsClosed++
}

func (s *registryState) armTimer() {
	if s.timer != nil {
		s.timer.Stop()
		s.timer = nil
		s.timerChannel = nil
	}
	s.timerArm++
	if len(s.deadlines) == 0 {
		return
	}
	delay := s.deadlines[0].at.Sub(s.clock.Now())
	if delay < 0 {
		delay = 0
	}
	s.timer = s.clock.NewTimer(delay)
	s.timerChannel = s.timer.C()
}

func (s *registryState) cleanupAssociations() {
	if s.timer != nil {
		s.timer.Stop()
		s.timer = nil
		s.timerChannel = nil
	}
	s.timerArm++
	for _, entry := range s.associations {
		s.retire(entry)
	}
	s.deadlines = nil
}

func (s *registryState) drainEvents() {
	for {
		select {
		case <-s.events:
		default:
			return
		}
	}
}

func (s *registryState) shutdown(_ CloseReason) {
	s.cleanupAssociations()
	s.drainEvents()
	s.counters.SessionCleanups++
}

func (s *registryState) updateHighWater() {
	associations := uint32(len(s.associations))
	timers := uint32(len(s.deadlines))
	pending := uint32(len(s.events))
	if associations > s.counters.MaximumAssociations {
		s.counters.MaximumAssociations = associations
	}
	if s.socketCount > s.counters.MaximumSockets {
		s.counters.MaximumSockets = s.socketCount
	}
	if timers > s.counters.MaximumTimers {
		s.counters.MaximumTimers = timers
	}
	if pending > s.counters.MaximumPendingCloses {
		s.counters.MaximumPendingCloses = pending
	}
}

func (s *registryState) snapshot(running bool) Snapshot {
	s.updateHighWater()
	return Snapshot{
		Generation:         s.generation,
		Associations:       uint32(len(s.associations)),
		Sockets:            s.socketCount,
		Timers:             uint32(len(s.deadlines)),
		PendingCloseEvents: uint32(len(s.events)),
		OwnerRunning:       running,
		Counters:           s.counters,
	}
}

type deadlineEntry struct {
	association *association
	at          time.Time
	epoch       uint64
	index       int
}

type deadlineHeap []*deadlineEntry

func (h deadlineHeap) Len() int { return len(h) }
func (h deadlineHeap) Less(i, j int) bool {
	if h[i].at.Equal(h[j].at) {
		return h[i].epoch < h[j].epoch
	}
	return h[i].at.Before(h[j].at)
}
func (h deadlineHeap) Swap(i, j int) {
	h[i], h[j] = h[j], h[i]
	h[i].index = i
	h[j].index = j
}
func (h *deadlineHeap) Push(value any) {
	entry := value.(*deadlineEntry)
	entry.index = len(*h)
	*h = append(*h, entry)
}
func (h *deadlineHeap) Pop() any {
	old := *h
	entry := old[len(old)-1]
	old[len(old)-1] = nil
	entry.index = -1
	*h = old[:len(old)-1]
	return entry
}
