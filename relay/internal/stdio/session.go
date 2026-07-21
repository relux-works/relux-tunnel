// Package stdio owns the relay protocol's bounded process streams. It starts
// no listener, daemon, or child process.
package stdio

import (
	"context"
	"errors"
	"io"
	"sync"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

const (
	defaultReadChunkBytes = 4096
	defaultHandshakeTime  = 10 * time.Second
	defaultWorkerShutdown = 100 * time.Millisecond
	maximumWorkerShutdown = time.Second
	sessionGeneration     = uint64(1)
)

type ErrorCode string

const (
	ErrorInvalidConfiguration ErrorCode = "invalidConfiguration"
	ErrorProtocolRejected     ErrorCode = "protocolRejected"
	ErrorStreamFailure        ErrorCode = "streamFailure"
	ErrorCancelled            ErrorCode = "cancelled"
)

// Error is finite and privacy-safe. It deliberately does not wrap reader,
// writer, payload, destination, or operating-system error text.
type Error struct {
	Code ErrorCode
}

func (e *Error) Error() string {
	if e == nil {
		return ""
	}
	return "relayStdio code=" + string(e.Code)
}

type Config struct {
	Handshake          protocol.ServerHandshakeConfig
	HandshakeTime      time.Duration
	ReadChunkBytes     int
	WorkerShutdownTime time.Duration
}

func DefaultConfig() Config {
	return Config{
		Handshake:          protocol.DefaultServerHandshakeConfig(),
		HandshakeTime:      defaultHandshakeTime,
		ReadChunkBytes:     defaultReadChunkBytes,
		WorkerShutdownTime: defaultWorkerShutdown,
	}
}

type readEvent struct {
	data []byte
	err  error
}

type writeRequest struct {
	data   []byte
	result chan error
}

// Run owns input and output until it returns. Exactly one goroutine reads
// input and exactly one goroutine writes output. Joining is bounded because
// inherited fd 0 is not guaranteed to unblock when another goroutine closes it;
// the CLI exits immediately after Run returns.
func Run(ctx context.Context, input io.ReadCloser, output io.WriteCloser, config Config) *Error {
	if input == nil || output == nil || config.HandshakeTime <= 0 ||
		config.ReadChunkBytes <= 0 || config.ReadChunkBytes > int(protocol.MaxFrameRelayHardCeiling) ||
		config.WorkerShutdownTime <= 0 || config.WorkerShutdownTime > maximumWorkerShutdown {
		return &Error{Code: ErrorInvalidConfiguration}
	}
	handshake, failure := protocol.NewServerHandshake(
		sessionGeneration,
		config.Handshake,
		time.Now(),
		config.HandshakeTime,
	)
	if failure != nil {
		return &Error{Code: ErrorInvalidConfiguration}
	}

	workerContext, cancelWorkers := context.WithCancel(ctx)
	reads := make(chan readEvent, 1)
	writes := make(chan writeRequest, 1)
	var workers sync.WaitGroup
	workers.Add(2)
	go readLoop(workerContext, input, config.ReadChunkBytes, reads, &workers)
	go writeLoop(workerContext, output, writes, &workers)
	defer func() {
		cancelWorkers()
		if deadlineInput, ok := input.(interface{ SetReadDeadline(time.Time) error }); ok {
			_ = deadlineInput.SetReadDeadline(time.Now())
		}
		if deadlineOutput, ok := output.(interface{ SetWriteDeadline(time.Time) error }); ok {
			_ = deadlineOutput.SetWriteDeadline(time.Now())
		}
		_ = input.Close()
		_ = output.Close()
		close(writes)
		workersDone := make(chan struct{})
		go func() {
			workers.Wait()
			close(workersDone)
		}()
		shutdownTimer := time.NewTimer(config.WorkerShutdownTime)
		defer shutdownTimer.Stop()
		select {
		case <-workersDone:
		case <-shutdownTimer.C:
		}
	}()

	timer := time.NewTimer(config.HandshakeTime)
	defer timer.Stop()
	var relaySession *protocol.Session
	var encoder *protocol.EnvelopeEncoder

	for {
		select {
		case <-ctx.Done():
			if relaySession == nil {
				handshake.Cancel(sessionGeneration)
			} else {
				relaySession.Cancel(sessionGeneration)
			}
			return &Error{Code: ErrorCancelled}
		case <-timer.C:
			if relaySession == nil {
				handshake.Timeout(sessionGeneration)
				return &Error{Code: ErrorProtocolRejected}
			}
		case event := <-reads:
			if event.err != nil {
				if errors.Is(event.err, io.EOF) {
					if relaySession == nil {
						handshake.EndOfStream(sessionGeneration)
						return &Error{Code: ErrorProtocolRejected}
					}
					relaySession.EndOfStream(sessionGeneration)
					return nil
				}
				if ctx.Err() != nil {
					if relaySession != nil {
						relaySession.Cancel(sessionGeneration)
					}
					return &Error{Code: ErrorCancelled}
				}
				if relaySession != nil {
					relaySession.TransportFailed(sessionGeneration)
				}
				return &Error{Code: ErrorStreamFailure}
			}

			if relaySession == nil {
				step := handshake.Consume(sessionGeneration, time.Now(), event.data)
				if len(step.Reply) > 0 {
					if writeFailure := writeBytes(ctx, writes, step.Reply); writeFailure != nil {
						return writeFailure
					}
				}
				if step.Failure != nil {
					return &Error{Code: ErrorProtocolRejected}
				}
				if step.Result == nil {
					continue
				}
				if !timer.Stop() {
					select {
					case <-timer.C:
					default:
					}
				}
				var sessionFailure *protocol.SessionError
				relaySession, sessionFailure = protocol.NewSession(
					sessionGeneration,
					protocol.SessionPeerRelay,
					step.Result.Summary.EffectiveLimits,
					step.Result.Summary.NegotiatedFeatures,
					nil,
					nil,
				)
				if sessionFailure != nil {
					return &Error{Code: ErrorProtocolRejected}
				}
				var encoderFailure *protocol.CodecError
				encoder, encoderFailure = protocol.NewEnvelopeEncoder(
					step.Result.Summary.EffectiveLimits.EffectiveMaxFrame,
					protocol.EnvelopeRelayToClient,
					step.Result.Summary.NegotiatedFeatures,
					nil,
				)
				if encoderFailure != nil {
					return &Error{Code: ErrorProtocolRejected}
				}
				if len(step.Remaining) == 0 {
					continue
				}
				event.data = step.Remaining
			}

			step := relaySession.Consume(sessionGeneration, event.data)
			for _, frame := range step.Outbound {
				encoded, encodeFailure := encoder.Encode(frame)
				if encodeFailure != nil {
					return &Error{Code: ErrorProtocolRejected}
				}
				if writeFailure := writeBytes(ctx, writes, encoded.Bytes()); writeFailure != nil {
					return writeFailure
				}
			}
			if step.Failure != nil {
				return &Error{Code: ErrorProtocolRejected}
			}
			if step.State == protocol.SessionClosed {
				return nil
			}
		}
	}
}

func readLoop(ctx context.Context, input io.Reader, chunkBytes int, events chan<- readEvent, workers *sync.WaitGroup) {
	defer workers.Done()
	buffer := make([]byte, chunkBytes)
	for {
		count, err := input.Read(buffer)
		if count > 0 {
			data := append([]byte(nil), buffer[:count]...)
			select {
			case events <- readEvent{data: data}:
			case <-ctx.Done():
				return
			}
		}
		if err != nil {
			select {
			case events <- readEvent{err: err}:
			case <-ctx.Done():
			}
			return
		}
		if count == 0 {
			select {
			case events <- readEvent{err: io.ErrNoProgress}:
			case <-ctx.Done():
			}
			return
		}
	}
}

func writeLoop(ctx context.Context, output io.Writer, requests <-chan writeRequest, workers *sync.WaitGroup) {
	defer workers.Done()
	for {
		select {
		case <-ctx.Done():
			return
		case request, ok := <-requests:
			if !ok {
				return
			}
			request.result <- writeAll(output, request.data)
		}
	}
}

func writeBytes(ctx context.Context, requests chan<- writeRequest, data []byte) *Error {
	request := writeRequest{
		data:   append([]byte(nil), data...),
		result: make(chan error, 1),
	}
	select {
	case requests <- request:
	case <-ctx.Done():
		return &Error{Code: ErrorCancelled}
	}
	select {
	case err := <-request.result:
		if err != nil {
			return &Error{Code: ErrorStreamFailure}
		}
		return nil
	case <-ctx.Done():
		return &Error{Code: ErrorCancelled}
	}
}

func writeAll(output io.Writer, data []byte) error {
	for len(data) > 0 {
		written, err := output.Write(data)
		if err != nil {
			return err
		}
		if written <= 0 || written > len(data) {
			return io.ErrShortWrite
		}
		data = data[written:]
	}
	return nil
}
