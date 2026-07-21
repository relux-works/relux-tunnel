package udp

import (
	"context"
	"errors"
	"fmt"
	"net/netip"
	"sync"
	"syscall"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

const (
	maxResolverConcurrency = 256
	maxResolverQueue       = 4096
	maxResolverResults     = 32
	maxResolverResultBytes = 512
	maxResolverNameBytes   = maxResolverQueue * protocol.MaxDomainWireBytes
	maxTurnTargets         = protocol.MaxAssociationsRelayHardCeiling * 2
	maxTurnDatagrams       = 4096
	maxTurnBytes           = 16 * 1024 * 1024
	maxTurnDuration        = time.Second
)

type ResolverFamilyPolicy uint8

const (
	ResolverIPv4Only ResolverFamilyPolicy = iota + 1
	ResolverIPv6Only
	ResolverIPv4ThenIPv6
	ResolverIPv6ThenIPv4
)

func (p ResolverFamilyPolicy) valid() bool {
	return p >= ResolverIPv4Only && p <= ResolverIPv6ThenIPv4
}

// IOLimits contains only relay-local immutable limits. No value is serialized
// or inferred from a destination.
type IOLimits struct {
	MaximumPayloadBytes       uint16
	ResolverTimeout           time.Duration
	MaximumConcurrentResolver uint16
	MaximumQueuedResolver     uint16
	MaximumResolverNameBytes  uint32
	MaximumResolverResults    uint8
	MaximumResolverBytes      uint16
	ResolverFamilyPolicy      ResolverFamilyPolicy
	MaximumTurnTargets        uint16
	MaximumTurnDatagrams      uint16
	MaximumTurnBytes          uint32
	MaximumTurnSocketVisits   uint16
	MaximumTurnDuration       time.Duration
}

func DefaultIOLimits(effective protocol.EffectiveLimits) IOLimits {
	return IOLimits{
		MaximumPayloadBytes:       effective.MaxUDPPayload,
		ResolverTimeout:           5 * time.Second,
		MaximumConcurrentResolver: 16,
		MaximumQueuedResolver:     64,
		MaximumResolverNameBytes:  64 * protocol.MaxDomainWireBytes,
		MaximumResolverResults:    8,
		MaximumResolverBytes:      128,
		ResolverFamilyPolicy:      ResolverIPv4ThenIPv6,
		MaximumTurnTargets:        uint16(effective.MaxAssociations * 2),
		MaximumTurnDatagrams:      64,
		MaximumTurnBytes:          uint32(effective.MaxUDPPayload+1) * 64,
		MaximumTurnSocketVisits:   uint16(effective.MaxAssociations * 2),
		MaximumTurnDuration:       2 * time.Millisecond,
	}
}

func (l IOLimits) validate() bool {
	receiveWidth := uint32(l.MaximumPayloadBytes) + 1
	return l.MaximumPayloadBytes >= protocol.MaxUDPPayloadFloor &&
		l.MaximumPayloadBytes <= protocol.MaxUDPPayloadRelayHardCeiling &&
		l.ResolverTimeout > 0 && l.ResolverTimeout <= 30*time.Second &&
		l.MaximumConcurrentResolver > 0 && l.MaximumConcurrentResolver <= maxResolverConcurrency &&
		l.MaximumQueuedResolver > 0 && l.MaximumQueuedResolver <= maxResolverQueue &&
		l.MaximumResolverNameBytes >= protocol.MinDomainWireBytes &&
		l.MaximumResolverNameBytes <= maxResolverNameBytes &&
		l.MaximumResolverResults > 0 && l.MaximumResolverResults <= maxResolverResults &&
		l.MaximumResolverBytes >= 4 && l.MaximumResolverBytes <= maxResolverResultBytes &&
		l.ResolverFamilyPolicy.valid() &&
		l.MaximumTurnTargets > 0 && uint32(l.MaximumTurnTargets) <= maxTurnTargets &&
		l.MaximumTurnDatagrams > 0 && l.MaximumTurnDatagrams <= maxTurnDatagrams &&
		l.MaximumTurnBytes >= receiveWidth && l.MaximumTurnBytes <= maxTurnBytes &&
		l.MaximumTurnSocketVisits > 0 && uint32(l.MaximumTurnSocketVisits) <= maxTurnTargets &&
		l.MaximumTurnDuration > 0 && l.MaximumTurnDuration <= maxTurnDuration
}

// Resolver must honor context cancellation. Implementations return numeric IP
// addresses only and must not retain or log the supplied name.
type Resolver interface {
	LookupNetIP(context.Context, string, string) ([]netip.Addr, error)
}

type SocketOperations interface {
	SendTo(int, AddressFamily, netip.Addr, uint16, []byte) error
	ReceiveFrom(int, AddressFamily, []byte) (int, protocol.DatagramEndpoint, bool, error)
}

type IOFailureCode string

const (
	IOInvalidConfiguration IOFailureCode = "invalidConfiguration"
	IOInvalidDatagram      IOFailureCode = "invalidDatagram"
	IODatagramTooLarge     IOFailureCode = "datagramTooLarge"
	IOUnsupportedAddress   IOFailureCode = "unsupportedAddress"
	IOResolutionFailure    IOFailureCode = "resolutionFailure"
	IOResourceLimit        IOFailureCode = "resourceLimit"
	IOWouldBlock           IOFailureCode = "wouldBlock"
	IOQueueSaturated       IOFailureCode = "queueSaturated"
	IOSocketFailure        IOFailureCode = "socketFailure"
	IOAssociationClosed    IOFailureCode = "associationClosed"
	IOStaleWork            IOFailureCode = "staleWork"
	IOCancelled            IOFailureCode = "cancelled"
)

type IOFailure struct {
	Code        IOFailureCode
	UDPCode     protocol.UDPErrorCode
	Scope       string
	Disposition string
	Retryable   bool
}

func (e *IOFailure) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf(
		"relayUDPIO code=%s scope=%s disposition=%s retryable=%t",
		e.Code,
		e.Scope,
		e.Disposition,
		e.Retryable,
	)
}

type SendDisposition string

const (
	SendDispositionSent           SendDisposition = "sent"
	SendDispositionPending        SendDisposition = "pendingResolution"
	SendDispositionDropped        SendDisposition = "dropped"
	SendDispositionRetryReadiness SendDisposition = "retryReadiness"
	SendDispositionFailed         SendDisposition = "failed"
)

type SendResult struct {
	Token       AssociationToken
	Family      AddressFamily
	Disposition SendDisposition
	Failure     *IOFailure
}

type ReceiveTarget struct {
	Token  AssociationToken
	Family AddressFamily
}

type ReplyDisposition uint8

const (
	ReplyAccepted ReplyDisposition = iota + 1
	ReplyQueueSaturated
	ReplyAssociationClosed
)

// ReplySink consumes a reply synchronously while the association is known to
// be active. Datagram byte slices are valid only for the duration of the call;
// a retaining sink must copy them under its own already-reserved queue credit.
// The sink must be bounded and nonblocking and must not call back into the
// registry. Failure callbacks carry finite codes only.
type ReplySink interface {
	ConsumeReply(AssociationToken, protocol.Datagram) ReplyDisposition
	ConsumeFailure(AssociationToken, *IOFailure)
}

type TurnStopReason string

const (
	TurnStopNoTargets        TurnStopReason = "noTargets"
	TurnStopTargetsRejected  TurnStopReason = "targetsRejected"
	TurnStopCancelled        TurnStopReason = "cancelled"
	TurnStopSocketVisitLimit TurnStopReason = "socketVisitBudget"
	TurnStopDatagramLimit    TurnStopReason = "datagramBudget"
	TurnStopByteLimit        TurnStopReason = "byteBudget"
	TurnStopTimeLimit        TurnStopReason = "timeBudget"
)

type TurnResult struct {
	StopReason     TurnStopReason
	SocketVisits   uint16
	DatagramsRead  uint16
	BytesRead      uint32
	RepliesEmitted uint16
	Dropped        uint16
}

type IOCounters struct {
	DatagramsSent                 uint64
	BytesSent                     uint64
	DatagramsReceived             uint64
	BytesReceived                 uint64
	RepliesEmitted                uint64
	InvalidDatagrams              uint64
	UnsupportedAddresses          uint64
	OversizedDatagramRejected     uint64
	OversizedReplyDropped         uint64
	QueueSaturatedDropped         uint64
	WouldBlock                    uint64
	ResolutionRequests            uint64
	ResolutionFailures            uint64
	ResolutionConcurrencyRejected uint64
	ResolutionResultsDiscarded    uint64
	AssociationRejected           uint64
	ResourceLimitRejected         uint64
	SocketFailures                uint64
	Cancelled                     uint64
	StaleWorkDropped              uint64
	TurnTargetsRejected           uint64
	TurnSocketVisitBudgetReached  uint64
	TurnDatagramBudgetReached     uint64
	TurnByteBudgetReached         uint64
	TurnTimeBudgetReached         uint64
	MaximumConcurrentResolution   uint16
	MaximumResolutionBytes        uint16
}

type DatagramIO struct {
	limits   IOLimits
	registry *Registry
	resolver Resolver
	sockets  SocketOperations
	clock    MonotonicClock

	metricsMu          sync.Mutex
	counters           IOCounters
	resolverConcurrent uint16
	turnMu             sync.Mutex
	nextTarget         int

	resolverContext context.Context
	cancelResolver  context.CancelFunc
	resolverJobs    chan resolverJob
	resolverCredits chan struct{}
	resolverResults chan SendResult
	resolverDone    chan struct{}
	resolverWG      sync.WaitGroup
	schedulerMu     sync.Mutex
	scheduler       IOSnapshot
}

func NewDatagramIO(
	limits IOLimits,
	registry *Registry,
	resolver Resolver,
	sockets SocketOperations,
	clock MonotonicClock,
) (*DatagramIO, *IOFailure) {
	if !limits.validate() || registry == nil {
		return nil, configurationFailure()
	}
	if resolver == nil {
		resolver = systemResolver{}
	}
	if sockets == nil {
		sockets = systemSocketOperations{}
	}
	if clock == nil {
		clock = systemClock{}
	}
	datagramIO := &DatagramIO{
		limits:       limits,
		registry:     registry,
		resolver:     resolver,
		sockets:      sockets,
		clock:        clock,
		resolverJobs: make(chan resolverJob, limits.MaximumQueuedResolver),
		resolverCredits: make(
			chan struct{},
			int(limits.MaximumConcurrentResolver)+int(limits.MaximumQueuedResolver),
		),
		resolverResults: make(
			chan SendResult,
			int(limits.MaximumConcurrentResolver)+int(limits.MaximumQueuedResolver),
		),
		resolverDone: make(chan struct{}),
	}
	datagramIO.startResolverScheduler()
	return datagramIO, nil
}

func (d *DatagramIO) Counters() IOCounters {
	d.metricsMu.Lock()
	defer d.metricsMu.Unlock()
	return d.counters
}

func (d *DatagramIO) Send(
	ctx context.Context,
	generation uint64,
	associationID uint32,
	datagram protocol.Datagram,
) SendResult {
	if ctx == nil || ctx.Err() != nil {
		d.increment(func(c *IOCounters) { c.Cancelled++ })
		return failedSend(cancelledFailure())
	}
	if failure := validateOutboundDatagram(datagram, d.limits.MaximumPayloadBytes); failure != nil {
		d.recordFailure(failure)
		return failedSend(failure)
	}

	if datagram.Endpoint.Address.Type == protocol.AddressTypeDomain {
		if failure := validateResolverName(datagram.Endpoint.Address.Bytes); failure != nil {
			d.recordFailure(failure)
			return failedSend(failure)
		}
		reservation, registryFailure := d.registry.Reserve(ctx, generation, associationID)
		if registryFailure != nil {
			failure := mapRegistryFailure(registryFailure)
			d.recordFailure(failure)
			return failedSend(failure)
		}
		return d.queueResolution(ctx, reservation, datagram)
	}

	address, family, failure := numericDestination(datagram.Endpoint.Address)
	if failure != nil {
		d.recordFailure(failure)
		return failedSend(failure)
	}
	admission, registryFailure := d.registry.Ensure(ctx, generation, associationID, family)
	if registryFailure != nil {
		failure = mapRegistryFailure(registryFailure)
		d.recordFailure(failure)
		return failedSend(failure)
	}

	return d.sendWithToken(ctx, admission.Token, family, address, datagram)
}

func (d *DatagramIO) sendWithToken(
	ctx context.Context,
	token AssociationToken,
	family AddressFamily,
	address netip.Addr,
	datagram protocol.Datagram,
) SendResult {
	var sendError error
	registryFailure := d.registry.UseSocketOperation(ctx, token, family, func(descriptor int) (bool, error) {
		sendError = d.sockets.SendTo(descriptor, family, address, datagram.Endpoint.Port, datagram.Data)
		if isWouldBlock(sendError) {
			return false, nil
		}
		return sendError == nil, sendError
	})
	if sendError != nil {
		failure := mapSocketError(sendError)
		d.recordFailure(failure)
		if failure.Disposition == "closeAssociation" {
			d.closeAssociationBestEffort(token, CloseReasonLocal)
		}
		return SendResult{
			Token:       token,
			Family:      family,
			Disposition: sendDispositionForFailure(failure),
			Failure:     failure,
		}
	}
	if registryFailure != nil {
		failure := mapRegistryFailure(registryFailure)
		d.recordFailure(failure)
		if failure.Disposition == "closeAssociation" {
			d.closeAssociationBestEffort(token, CloseReasonLocal)
		}
		return SendResult{Token: token, Family: family, Disposition: SendDispositionFailed, Failure: failure}
	}

	d.increment(func(c *IOCounters) {
		c.DatagramsSent++
		c.BytesSent += uint64(len(datagram.Data))
	})
	return SendResult{Token: token, Family: family, Disposition: SendDispositionSent}
}

func (d *DatagramIO) ReceiveTurn(
	ctx context.Context,
	targets []ReceiveTarget,
	sink ReplySink,
) TurnResult {
	d.turnMu.Lock()
	defer d.turnMu.Unlock()
	if len(targets) == 0 {
		return TurnResult{StopReason: TurnStopNoTargets}
	}
	if ctx == nil || ctx.Err() != nil {
		d.increment(func(c *IOCounters) { c.Cancelled++ })
		return TurnResult{StopReason: TurnStopCancelled}
	}
	if sink == nil || len(targets) > int(d.limits.MaximumTurnTargets) {
		d.increment(func(c *IOCounters) { c.TurnTargetsRejected++ })
		return TurnResult{StopReason: TurnStopTargetsRejected}
	}

	result := TurnResult{}
	start := d.clock.Now()
	receiveWidth := uint32(d.limits.MaximumPayloadBytes) + 1
	buffer := make([]byte, receiveWidth)
	if d.nextTarget >= len(targets) {
		d.nextTarget %= len(targets)
	}

	for {
		if ctx.Err() != nil {
			result.StopReason = TurnStopCancelled
			d.increment(func(c *IOCounters) { c.Cancelled++ })
			break
		}
		if result.DatagramsRead >= d.limits.MaximumTurnDatagrams {
			result.StopReason = TurnStopDatagramLimit
			d.increment(func(c *IOCounters) { c.TurnDatagramBudgetReached++ })
			break
		}
		if d.limits.MaximumTurnBytes-result.BytesRead < receiveWidth {
			result.StopReason = TurnStopByteLimit
			d.increment(func(c *IOCounters) { c.TurnByteBudgetReached++ })
			break
		}
		if !d.clock.Now().Before(start.Add(d.limits.MaximumTurnDuration)) {
			result.StopReason = TurnStopTimeLimit
			d.increment(func(c *IOCounters) { c.TurnTimeBudgetReached++ })
			break
		}
		if result.SocketVisits >= d.limits.MaximumTurnSocketVisits {
			result.StopReason = TurnStopSocketVisitLimit
			d.increment(func(c *IOCounters) { c.TurnSocketVisitBudgetReached++ })
			break
		}

		target := targets[d.nextTarget]
		d.nextTarget = (d.nextTarget + 1) % len(targets)
		result.SocketVisits++
		d.receiveOne(ctx, target, buffer, sink, &result)
	}
	return result
}

func (d *DatagramIO) receiveOne(
	ctx context.Context,
	target ReceiveTarget,
	buffer []byte,
	sink ReplySink,
	result *TurnResult,
) {
	if !target.Family.valid() {
		failure := unsupportedAddressFailure()
		d.recordFailure(failure)
		_, _ = d.registry.CloseAssociation(ctx, target.Token, CloseReasonLocal)
		sink.ConsumeFailure(target.Token, failure)
		result.Dropped++
		return
	}
	var receiveError error
	var receiveFailure *IOFailure
	var received bool
	failure := d.registry.UseSocketOperation(
		ctx,
		target.Token,
		target.Family,
		func(descriptor int) (bool, error) {
			n, source, truncated, err := d.sockets.ReceiveFrom(descriptor, target.Family, buffer)
			receiveError = err
			if isWouldBlock(err) {
				receiveError = nil
				return false, nil
			}
			if err != nil {
				return false, err
			}
			received = true
			if n < 0 || n > len(buffer) || truncated || n > int(d.limits.MaximumPayloadBytes) {
				observed := n
				if observed < 0 {
					observed = 0
				}
				if observed > len(buffer) {
					observed = len(buffer)
				}
				result.DatagramsRead++
				result.BytesRead += uint32(observed)
				result.Dropped++
				d.increment(func(c *IOCounters) {
					c.DatagramsReceived++
					c.BytesReceived += uint64(observed)
					c.OversizedReplyDropped++
				})
				return true, nil
			}
			if endpointFailure := validateObservedEndpoint(source, uint64(n), d.limits.MaximumPayloadBytes); endpointFailure != nil {
				receiveFailure = endpointFailure
				result.DatagramsRead++
				result.BytesRead += uint32(n)
				result.Dropped++
				d.increment(func(c *IOCounters) {
					c.DatagramsReceived++
					c.BytesReceived += uint64(n)
				})
				return true, nil
			}

			result.DatagramsRead++
			result.BytesRead += uint32(n)
			d.increment(func(c *IOCounters) {
				c.DatagramsReceived++
				c.BytesReceived += uint64(n)
			})
			disposition := sink.ConsumeReply(target.Token, protocol.Datagram{
				Endpoint: source,
				Data:     buffer[:n],
			})
			switch disposition {
			case ReplyAccepted:
				result.RepliesEmitted++
				d.increment(func(c *IOCounters) { c.RepliesEmitted++ })
			case ReplyQueueSaturated:
				result.Dropped++
				d.increment(func(c *IOCounters) { c.QueueSaturatedDropped++ })
			case ReplyAssociationClosed:
				result.Dropped++
				d.increment(func(c *IOCounters) { c.StaleWorkDropped++ })
			default:
				result.Dropped++
				d.increment(func(c *IOCounters) { c.QueueSaturatedDropped++ })
			}
			return true, nil
		},
	)
	if receiveError != nil {
		mapped := mapSocketError(receiveError)
		d.recordFailure(mapped)
		if mapped.Disposition == "closeAssociation" {
			_, _ = d.registry.CloseAssociation(ctx, target.Token, CloseReasonLocal)
		}
		sink.ConsumeFailure(target.Token, mapped)
		result.Dropped++
		return
	}
	if receiveFailure != nil {
		d.recordFailure(receiveFailure)
		if receiveFailure.Disposition == "closeAssociation" {
			_, _ = d.registry.CloseAssociation(ctx, target.Token, CloseReasonLocal)
		}
		sink.ConsumeFailure(target.Token, receiveFailure)
		return
	}
	if failure != nil && !received {
		mapped := mapRegistryFailure(failure)
		d.recordFailure(mapped)
		// Stale/closed work is deliberately silent on the wire.
		if mapped.Code == IOStaleWork || mapped.Code == IOAssociationClosed {
			result.Dropped++
			return
		}
		sink.ConsumeFailure(target.Token, mapped)
		result.Dropped++
	}
}

func numericDestination(address protocol.DatagramAddress) (netip.Addr, AddressFamily, *IOFailure) {
	switch address.Type {
	case protocol.AddressTypeIPv4:
		if len(address.Bytes) != 4 {
			return netip.Addr{}, 0, invalidDatagramFailure()
		}
		var raw [4]byte
		copy(raw[:], address.Bytes)
		return netip.AddrFrom4(raw), AddressFamilyIPv4, nil
	case protocol.AddressTypeIPv6:
		if len(address.Bytes) != 16 {
			return netip.Addr{}, 0, invalidDatagramFailure()
		}
		var raw [16]byte
		copy(raw[:], address.Bytes)
		parsed := netip.AddrFrom16(raw)
		if parsed.Is4In6() {
			return netip.Addr{}, 0, unsupportedAddressFailure()
		}
		return parsed, AddressFamilyIPv6, nil
	default:
		return netip.Addr{}, 0, unsupportedAddressFailure()
	}
}

func selectResolvedAddress(results []netip.Addr, policy ResolverFamilyPolicy) (netip.Addr, bool) {
	preferredIPv4 := policy == ResolverIPv4Only || policy == ResolverIPv4ThenIPv6
	for pass := 0; pass < 2; pass++ {
		wantIPv4 := preferredIPv4
		if pass == 1 {
			if policy == ResolverIPv4Only || policy == ResolverIPv6Only {
				break
			}
			wantIPv4 = !wantIPv4
		}
		for _, result := range results {
			if result.Is4() == wantIPv4 {
				return result, true
			}
		}
	}
	return netip.Addr{}, false
}

func validateOutboundDatagram(datagram protocol.Datagram, maximum uint16) *IOFailure {
	_, failure := protocol.ValidateDatagramEncodedLength(
		datagram.Endpoint,
		uint64(len(datagram.Data)),
		maximum,
	)
	if failure == nil {
		return nil
	}
	switch failure.Code {
	case protocol.DatagramMessageLengthExceedsProtocolLimit,
		protocol.DatagramMessageLengthExceedsLocalLimit:
		return datagramTooLargeFailure()
	case protocol.DatagramUnknownAddressType:
		return unsupportedAddressFailure()
	default:
		return invalidDatagramFailure()
	}
}

func validateObservedEndpoint(
	endpoint protocol.DatagramEndpoint,
	payloadLength uint64,
	maximum uint16,
) *IOFailure {
	_, failure := protocol.ValidateDatagramEncodedLength(endpoint, payloadLength, maximum)
	if failure == nil {
		return nil
	}
	if failure.Code == protocol.DatagramUnknownAddressType {
		return unsupportedAddressFailure()
	}
	return socketFailure()
}

func sendDispositionForFailure(failure *IOFailure) SendDisposition {
	if failure == nil {
		return SendDispositionSent
	}
	if failure.Retryable {
		return SendDispositionRetryReadiness
	}
	if failure.Disposition == "rejectDatagram" {
		return SendDispositionDropped
	}
	return SendDispositionFailed
}

func failedSend(failure *IOFailure) SendResult {
	return SendResult{Disposition: sendDispositionForFailure(failure), Failure: failure}
}

func mapSocketError(err error) *IOFailure {
	switch {
	case isWouldBlock(err):
		return &IOFailure{
			Code: IOWouldBlock, UDPCode: protocol.UDPErrorCodeQueueSaturated,
			Scope: "association", Disposition: "retryReadiness", Retryable: true,
		}
	case errors.Is(err, syscall.ENOBUFS):
		return &IOFailure{
			Code: IOQueueSaturated, UDPCode: protocol.UDPErrorCodeQueueSaturated,
			Scope: "association", Disposition: "rejectDatagram",
		}
	case errors.Is(err, syscall.EMSGSIZE):
		return datagramTooLargeFailure()
	case errors.Is(err, errUnsupportedSourceEndpoint), errors.Is(err, syscall.EAFNOSUPPORT):
		return unsupportedAddressFailure()
	default:
		return socketFailure()
	}
}

func mapRegistryFailure(failure *RegistryError) *IOFailure {
	if failure == nil {
		return nil
	}
	switch failure.Code {
	case ErrorCancelled:
		return cancelledFailure()
	case ErrorStaleGeneration, ErrorStaleAssociation:
		return &IOFailure{Code: IOStaleWork, Scope: "association", Disposition: "drop"}
	case ErrorRegistryClosed:
		return &IOFailure{Code: IOStaleWork, Scope: "session", Disposition: "drop"}
	case ErrorUnknownAssociation:
		return &IOFailure{
			Code: IOAssociationClosed, UDPCode: protocol.UDPErrorCodeUnknownOrClosedAssociation,
			Scope: "association", Disposition: "closeAssociation",
		}
	case ErrorInvalidAssociationID:
		return invalidDatagramFailure()
	case ErrorInvalidAddressFamily:
		return unsupportedAddressFailure()
	case ErrorInvalidConfiguration:
		return configurationFailure()
	case ErrorAssociationLimit:
		return &IOFailure{
			Code: IOResourceLimit, UDPCode: protocol.UDPErrorCodeAssociationLimit,
			Scope: "association", Disposition: "rejectDatagram",
		}
	case ErrorSocketLimit, ErrorTimerLimit, ErrorPendingCloseLimit:
		return resourceFailure()
	default:
		return socketFailure()
	}
}

func isWouldBlock(err error) bool {
	return errors.Is(err, syscall.EAGAIN) || errors.Is(err, syscall.EWOULDBLOCK)
}

func configurationFailure() *IOFailure {
	return &IOFailure{Code: IOInvalidConfiguration, Scope: "session", Disposition: "closeSession"}
}

func invalidDatagramFailure() *IOFailure {
	return &IOFailure{
		Code: IOInvalidDatagram, UDPCode: protocol.UDPErrorCodeInvalidDatagram,
		Scope: "association", Disposition: "closeAssociation",
	}
}

func unsupportedAddressFailure() *IOFailure {
	return &IOFailure{
		Code: IOUnsupportedAddress, UDPCode: protocol.UDPErrorCodeUnsupportedAddress,
		Scope: "association", Disposition: "closeAssociation",
	}
}

func datagramTooLargeFailure() *IOFailure {
	return &IOFailure{
		Code: IODatagramTooLarge, UDPCode: protocol.UDPErrorCodeDatagramTooLarge,
		Scope: "association", Disposition: "rejectDatagram",
	}
}

func resolutionFailure() *IOFailure {
	return &IOFailure{
		Code: IOResolutionFailure, UDPCode: protocol.UDPErrorCodeResolutionFailure,
		Scope: "association", Disposition: "closeAssociation",
	}
}

func resourceFailure() *IOFailure {
	return &IOFailure{
		Code: IOResourceLimit, UDPCode: protocol.UDPErrorCodeResourceLimit,
		Scope: "association", Disposition: "rejectDatagram",
	}
}

func socketFailure() *IOFailure {
	return &IOFailure{
		Code: IOSocketFailure, UDPCode: protocol.UDPErrorCodeSocketFailure,
		Scope: "association", Disposition: "closeAssociation",
	}
}

func cancelledFailure() *IOFailure {
	return &IOFailure{Code: IOCancelled, Scope: "session", Disposition: "closeSession"}
}

func (d *DatagramIO) recordFailure(failure *IOFailure) {
	if failure == nil {
		return
	}
	d.increment(func(c *IOCounters) {
		switch failure.Code {
		case IOInvalidDatagram:
			c.InvalidDatagrams++
		case IODatagramTooLarge:
			c.OversizedDatagramRejected++
		case IOUnsupportedAddress:
			c.UnsupportedAddresses++
		case IOResolutionFailure:
			c.ResolutionFailures++
		case IOResourceLimit:
			c.ResourceLimitRejected++
			if failure.UDPCode == protocol.UDPErrorCodeAssociationLimit {
				c.AssociationRejected++
			}
		case IOWouldBlock:
			c.WouldBlock++
		case IOQueueSaturated:
			c.QueueSaturatedDropped++
		case IOSocketFailure:
			c.SocketFailures++
		case IOAssociationClosed, IOStaleWork:
			c.StaleWorkDropped++
		case IOCancelled:
			c.Cancelled++
		}
	})
}

func (d *DatagramIO) increment(update func(*IOCounters)) {
	d.metricsMu.Lock()
	update(&d.counters)
	d.metricsMu.Unlock()
}

func (d *DatagramIO) resolverStarted() {
	d.metricsMu.Lock()
	d.resolverConcurrent++
	d.counters.ResolutionRequests++
	if d.resolverConcurrent > d.counters.MaximumConcurrentResolution {
		d.counters.MaximumConcurrentResolution = d.resolverConcurrent
	}
	d.metricsMu.Unlock()
}

func (d *DatagramIO) resolverEnded() {
	d.metricsMu.Lock()
	d.resolverConcurrent--
	d.metricsMu.Unlock()
}

func (d *DatagramIO) recordResolution(bytes uint16, discarded uint64) {
	d.metricsMu.Lock()
	d.counters.ResolutionResultsDiscarded += discarded
	if bytes > d.counters.MaximumResolutionBytes {
		d.counters.MaximumResolutionBytes = bytes
	}
	d.metricsMu.Unlock()
}
