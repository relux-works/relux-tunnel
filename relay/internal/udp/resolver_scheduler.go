package udp

import (
	"context"
	"net/netip"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

type resolverJob struct {
	callerContext context.Context
	lifecycle     context.Context
	token         AssociationToken
	name          []byte
	datagram      protocol.Datagram
}

// IOSnapshot exposes only bounded resource counts. Destination names,
// addresses, payloads, and raw resolver results never leave the scheduler.
type IOSnapshot struct {
	ResolverWorkers              uint16
	ActiveResolverJobs           uint16
	QueuedResolverJobs           uint16
	PendingResolverCompletions   uint16
	CopiedResolverNameBytes      uint32
	CopiedResolverPayloadBytes   uint32
	CopiedResolverResultBytes    uint32
	MaximumCopiedResolverNames   uint32
	MaximumCopiedResolverResults uint32
	Stopped                      bool
}

func (d *DatagramIO) startResolverScheduler() {
	d.resolverContext, d.cancelResolver = context.WithCancel(context.Background())
	d.schedulerMu.Lock()
	d.scheduler.ResolverWorkers = d.limits.MaximumConcurrentResolver
	d.schedulerMu.Unlock()
	for range d.limits.MaximumConcurrentResolver {
		d.resolverWG.Add(1)
		go d.resolverWorker()
	}
	go func() {
		select {
		case <-d.registry.Done():
			d.cancelResolver()
		case <-d.resolverContext.Done():
		}
		d.resolverWG.Wait()
		d.releaseQueuedResolverJobs()
		d.releasePendingResolverResults()
		d.schedulerMu.Lock()
		d.scheduler.Stopped = true
		d.schedulerMu.Unlock()
		close(d.resolverDone)
	}()
}

func (d *DatagramIO) Done() <-chan struct{} { return d.resolverDone }

func (d *DatagramIO) Snapshot() IOSnapshot {
	d.schedulerMu.Lock()
	defer d.schedulerMu.Unlock()
	snapshot := d.scheduler
	snapshot.QueuedResolverJobs = uint16(len(d.resolverJobs))
	return snapshot
}

// NextSendCompletion releases the scheduler credit reserved by a domain Send.
// Callers must drain completions to admit more domain work; this makes receiver
// stall a finite, observable backpressure condition rather than a hidden queue.
func (d *DatagramIO) NextSendCompletion(ctx context.Context) (SendResult, bool) {
	if ctx == nil {
		return SendResult{}, false
	}
	select {
	case result := <-d.resolverResults:
		d.schedulerMu.Lock()
		if d.scheduler.PendingResolverCompletions > 0 {
			d.scheduler.PendingResolverCompletions--
		}
		d.schedulerMu.Unlock()
		d.releaseResolverCredit()
		return result, true
	case <-ctx.Done():
		return SendResult{}, false
	case <-d.resolverDone:
		return SendResult{}, false
	}
}

func (d *DatagramIO) queueResolution(
	ctx context.Context,
	reservation AssociationReservation,
	datagram protocol.Datagram,
) SendResult {
	select {
	case d.resolverCredits <- struct{}{}:
	default:
		d.rejectResolutionAdmission(reservation)
		return d.resolutionAdmissionFailure(reservation.Token)
	}

	nameBytes := uint32(len(datagram.Endpoint.Address.Bytes))
	payloadBytes := uint32(len(datagram.Data))
	d.schedulerMu.Lock()
	if nameBytes > d.limits.MaximumResolverNameBytes-d.scheduler.CopiedResolverNameBytes {
		d.schedulerMu.Unlock()
		d.releaseResolverCredit()
		d.rejectResolutionAdmission(reservation)
		return d.resolutionAdmissionFailure(reservation.Token)
	}
	d.scheduler.CopiedResolverNameBytes += nameBytes
	d.scheduler.CopiedResolverPayloadBytes += payloadBytes
	if d.scheduler.CopiedResolverNameBytes > d.scheduler.MaximumCopiedResolverNames {
		d.scheduler.MaximumCopiedResolverNames = d.scheduler.CopiedResolverNameBytes
	}
	d.schedulerMu.Unlock()

	job := resolverJob{
		callerContext: ctx,
		lifecycle:     reservation.lifecycle,
		token:         reservation.Token,
		name:          append([]byte(nil), datagram.Endpoint.Address.Bytes...),
		datagram: protocol.Datagram{
			Endpoint: protocol.DatagramEndpoint{
				Address: protocol.DatagramAddress{Type: protocol.AddressTypeDomain},
				Port:    datagram.Endpoint.Port,
			},
			Data: append([]byte(nil), datagram.Data...),
		},
	}
	select {
	case d.resolverJobs <- job:
		return SendResult{Token: reservation.Token, Disposition: SendDispositionPending}
	default:
		d.releaseResolverJobMemory(job)
		d.releaseResolverCredit()
		d.rejectResolutionAdmission(reservation)
		return d.resolutionAdmissionFailure(reservation.Token)
	}
}

func (d *DatagramIO) resolutionAdmissionFailure(token AssociationToken) SendResult {
	d.increment(func(c *IOCounters) { c.ResolutionConcurrencyRejected++ })
	failure := resourceFailure()
	d.recordFailure(failure)
	return SendResult{
		Token: token, Disposition: sendDispositionForFailure(failure), Failure: failure,
	}
}

func (d *DatagramIO) rejectResolutionAdmission(reservation AssociationReservation) {
	if reservation.AssociationCreated {
		d.closeAssociationBestEffort(reservation.Token, CloseReasonLocal)
	}
}

func (d *DatagramIO) resolverWorker() {
	defer d.resolverWG.Done()
	defer func() {
		d.schedulerMu.Lock()
		d.scheduler.ResolverWorkers--
		d.schedulerMu.Unlock()
	}()
	for {
		select {
		case <-d.resolverContext.Done():
			return
		case job := <-d.resolverJobs:
			d.schedulerMu.Lock()
			d.scheduler.ActiveResolverJobs++
			d.schedulerMu.Unlock()
			d.resolverStarted()
			result := d.executeResolverJob(job)
			d.resolverEnded()
			d.schedulerMu.Lock()
			d.scheduler.ActiveResolverJobs--
			d.schedulerMu.Unlock()
			d.releaseResolverJobMemory(job)
			d.publishResolverResult(result)
		}
	}
}

func (d *DatagramIO) executeResolverJob(job resolverJob) SendResult {
	if job.lifecycle.Err() != nil {
		return d.finishResolverFailure(
			job.token,
			&IOFailure{Code: IOStaleWork, Scope: "association", Disposition: "drop"},
		)
	}
	if job.callerContext.Err() != nil || d.resolverContext.Err() != nil {
		return d.finishResolverFailure(job.token, cancelledFailure())
	}
	lookupContext, cancel := context.WithTimeout(job.lifecycle, d.limits.ResolverTimeout)
	stopCaller := context.AfterFunc(job.callerContext, cancel)
	stopScheduler := context.AfterFunc(d.resolverContext, cancel)
	defer func() {
		stopCaller()
		stopScheduler()
		cancel()
	}()

	results, err := d.resolver.LookupNetIP(lookupContext, "ip", string(job.name))
	if failure := d.resolverLookupFailure(job, lookupContext, err); failure != nil {
		return d.finishResolverFailure(job.token, failure)
	}

	accepted, usedBytes, discarded := d.boundResolverResults(results)
	d.recordResolution(usedBytes, discarded)
	d.schedulerMu.Lock()
	d.scheduler.CopiedResolverResultBytes += uint32(usedBytes)
	if d.scheduler.CopiedResolverResultBytes > d.scheduler.MaximumCopiedResolverResults {
		d.scheduler.MaximumCopiedResolverResults = d.scheduler.CopiedResolverResultBytes
	}
	d.schedulerMu.Unlock()
	defer func() {
		d.schedulerMu.Lock()
		d.scheduler.CopiedResolverResultBytes -= uint32(usedBytes)
		d.schedulerMu.Unlock()
	}()

	selected, ok := selectResolvedAddress(accepted, d.limits.ResolverFamilyPolicy)
	if !ok {
		if len(accepted) != 0 {
			return d.finishResolverFailure(job.token, unsupportedAddressFailure())
		}
		return d.finishResolverFailure(job.token, resolutionFailure())
	}
	family := AddressFamilyIPv6
	if selected.Is4() {
		family = AddressFamilyIPv4
	}
	admission, registryFailure := d.registry.EnsureTokenFamilies(
		lookupContext,
		job.token,
		family,
	)
	if registryFailure != nil {
		return d.finishResolverFailure(job.token, mapRegistryFailure(registryFailure))
	}
	return d.sendWithToken(lookupContext, admission.Token, family, selected, job.datagram)
}

func (d *DatagramIO) resolverLookupFailure(
	job resolverJob,
	lookupContext context.Context,
	err error,
) *IOFailure {
	if job.lifecycle.Err() != nil {
		return &IOFailure{Code: IOStaleWork, Scope: "association", Disposition: "drop"}
	}
	if job.callerContext.Err() != nil || d.resolverContext.Err() != nil {
		return cancelledFailure()
	}
	if err != nil || lookupContext.Err() != nil {
		return resolutionFailure()
	}
	return nil
}

func (d *DatagramIO) boundResolverResults(results []netip.Addr) ([]netip.Addr, uint16, uint64) {
	accepted := make([]netip.Addr, 0, d.limits.MaximumResolverResults)
	usedBytes := uint16(0)
	inspected := len(results)
	if inspected > int(d.limits.MaximumResolverResults) {
		inspected = int(d.limits.MaximumResolverResults)
	}
	discarded := uint64(len(results) - inspected)
	for _, result := range results[:inspected] {
		// A scope identifier is required to use a zoned IPv6 address correctly,
		// but relay protocol v1 has no zone representation. Reject it before
		// unmapping or charging accepted-result byte credit so it can never be
		// silently rewritten into an unscoped destination.
		if result.Zone() != "" {
			discarded++
			continue
		}
		result = result.Unmap()
		width := uint16(16)
		if result.Is4() {
			width = 4
		} else if !result.Is6() {
			discarded++
			continue
		}
		if width > d.limits.MaximumResolverBytes-usedBytes {
			discarded++
			continue
		}
		accepted = append(accepted, result)
		usedBytes += width
	}
	return accepted, usedBytes, discarded
}

func (d *DatagramIO) finishResolverFailure(token AssociationToken, failure *IOFailure) SendResult {
	d.recordFailure(failure)
	if failure != nil && failure.Code == IOCancelled {
		d.closeAssociationBestEffort(token, CloseReasonCancellation)
	} else if failure != nil && failure.Disposition == "closeAssociation" && failure.Code != IOStaleWork {
		d.closeAssociationBestEffort(token, CloseReasonLocal)
	}
	return SendResult{
		Token: token, Disposition: sendDispositionForFailure(failure), Failure: failure,
	}
}

func (d *DatagramIO) publishResolverResult(result SendResult) {
	d.schedulerMu.Lock()
	d.scheduler.PendingResolverCompletions++
	d.schedulerMu.Unlock()
	select {
	case d.resolverResults <- result:
	case <-d.resolverContext.Done():
		d.schedulerMu.Lock()
		d.scheduler.PendingResolverCompletions--
		d.schedulerMu.Unlock()
		d.releaseResolverCredit()
	}
}

func (d *DatagramIO) releaseResolverJobMemory(job resolverJob) {
	d.schedulerMu.Lock()
	d.scheduler.CopiedResolverNameBytes -= uint32(len(job.name))
	d.scheduler.CopiedResolverPayloadBytes -= uint32(len(job.datagram.Data))
	d.schedulerMu.Unlock()
}

func (d *DatagramIO) releaseResolverCredit() {
	select {
	case <-d.resolverCredits:
	default:
	}
}

func (d *DatagramIO) releaseQueuedResolverJobs() {
	for {
		select {
		case job := <-d.resolverJobs:
			d.releaseResolverJobMemory(job)
			d.releaseResolverCredit()
		default:
			return
		}
	}
}

func (d *DatagramIO) releasePendingResolverResults() {
	for {
		select {
		case <-d.resolverResults:
			d.schedulerMu.Lock()
			if d.scheduler.PendingResolverCompletions > 0 {
				d.scheduler.PendingResolverCompletions--
			}
			d.schedulerMu.Unlock()
			d.releaseResolverCredit()
		default:
			return
		}
	}
}

func (d *DatagramIO) closeAssociationBestEffort(token AssociationToken, reason CloseReason) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_, _ = d.registry.CloseAssociation(ctx, token, reason)
}
