package stdio

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"io"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

type closeBuffer struct {
	bytes.Buffer
	closed bool
}

func (b *closeBuffer) Close() error {
	b.closed = true
	return nil
}

func clientHello(flags uint16) []byte {
	result := make([]byte, protocol.ClientHelloWidth)
	copy(result, protocol.Magic[:])
	binary.BigEndian.PutUint16(result[4:6], protocol.WireVersion)
	binary.BigEndian.PutUint16(result[6:8], flags)
	binary.BigEndian.PutUint32(result[8:12], protocol.MaxFrameDefault)
	return result
}

func clientFrame(messageType protocol.MessageType, payload []byte) []byte {
	result := make([]byte, 10+len(payload))
	binary.BigEndian.PutUint32(result[:4], uint32(protocol.EnvelopeHeaderWidth+len(payload)))
	result[4] = byte(messageType)
	copy(result[10:], payload)
	return result
}

func TestRunOwnsHandshakeFramesAndCleanEOF(t *testing.T) {
	ping := []byte("12345678")
	inputBytes := append(clientHello(0), clientFrame(protocol.MessageTypePing, ping)...)
	inputBytes = append(inputBytes, clientFrame(protocol.MessageTypeCloseSession, nil)...)
	input := io.NopCloser(bytes.NewReader(inputBytes))
	output := &closeBuffer{}

	if failure := Run(context.Background(), input, output, DefaultConfig()); failure != nil {
		t.Fatal(failure)
	}
	serverHello := protocol.EncodeServerHello(
		protocol.WireVersion,
		protocol.HelloStatusAccepted,
		0,
		protocol.MaxFrameDefault,
	)
	want := append(serverHello[:], relayFrame(protocol.MessageTypePong, ping)...)
	want = append(want, relayFrame(protocol.MessageTypeCloseSession, nil)...)
	if !bytes.Equal(output.Bytes(), want) {
		t.Fatalf("protocol stdout mismatch: got %x want %x", output.Bytes(), want)
	}
	if !output.closed {
		t.Fatal("owned stdout was not closed")
	}
}

func relayFrame(messageType protocol.MessageType, payload []byte) []byte {
	result := clientFrame(messageType, payload)
	return result
}

func TestRunEOFBeforeAndAfterHandshake(t *testing.T) {
	for _, test := range []struct {
		name            string
		inputBytes      []byte
		wantFailure     ErrorCode
		wantOutputBytes int
	}{
		{"before", nil, ErrorProtocolRejected, 0},
		{"partial", clientHello(0)[:5], ErrorProtocolRejected, 0},
		{"after", clientHello(0), "", protocol.ServerHelloWidth},
	} {
		t.Run(test.name, func(t *testing.T) {
			output := &closeBuffer{}
			failure := Run(
				context.Background(),
				io.NopCloser(bytes.NewReader(test.inputBytes)),
				output,
				DefaultConfig(),
			)
			if test.wantFailure == "" && failure != nil {
				t.Fatal(failure)
			}
			if test.wantFailure != "" && (failure == nil || failure.Code != test.wantFailure) {
				t.Fatalf("failure = %#v", failure)
			}
			if output.Len() != test.wantOutputBytes {
				t.Fatalf("stdout bytes = %d", output.Len())
			}
		})
	}
}

func TestRunRejectsMalformedHelloWithOnlyWireReply(t *testing.T) {
	hello := clientHello(0)
	hello[0] = 'X'
	output := &closeBuffer{}
	failure := Run(
		context.Background(),
		io.NopCloser(bytes.NewReader(hello)),
		output,
		DefaultConfig(),
	)
	if failure == nil || failure.Code != ErrorProtocolRejected {
		t.Fatalf("failure = %#v", failure)
	}
	want := protocol.EncodeServerHello(
		protocol.WireVersion,
		protocol.HelloStatusInvalidClientHello,
		0,
		0,
	)
	if !bytes.Equal(output.Bytes(), want[:]) {
		t.Fatalf("unexpected rejection bytes: %x", output.Bytes())
	}
}

type failingWriteCloser struct{}

func (failingWriteCloser) Write([]byte) (int, error) {
	return 0, errors.New("payload destination credential")
}
func (failingWriteCloser) Close() error { return nil }

func TestRunMapsClosedOutputToFiniteFailure(t *testing.T) {
	failure := Run(
		context.Background(),
		io.NopCloser(bytes.NewReader(clientHello(0))),
		failingWriteCloser{},
		DefaultConfig(),
	)
	if failure == nil || failure.Code != ErrorStreamFailure {
		t.Fatalf("failure = %#v", failure)
	}
	if failure.Error() != "relayStdio code=streamFailure" {
		t.Fatalf("unsafe failure: %q", failure.Error())
	}
}

type blockingReadCloser struct {
	closed chan struct{}
	once   sync.Once
}

func newBlockingReadCloser() *blockingReadCloser {
	return &blockingReadCloser{closed: make(chan struct{})}
}

func (r *blockingReadCloser) Read([]byte) (int, error) {
	<-r.closed
	return 0, io.ErrClosedPipe
}

func (r *blockingReadCloser) Close() error {
	r.once.Do(func() { close(r.closed) })
	return nil
}

func TestRunCancellationJoinsReaderAndWriter(t *testing.T) {
	baseline := runtime.NumGoroutine()
	for iteration := 0; iteration < 20; iteration++ {
		ctx, cancel := context.WithCancel(context.Background())
		input := newBlockingReadCloser()
		output := &closeBuffer{}
		result := make(chan *Error, 1)
		go func() {
			result <- Run(ctx, input, output, DefaultConfig())
		}()
		cancel()
		select {
		case failure := <-result:
			if failure == nil || failure.Code != ErrorCancelled {
				t.Fatalf("iteration %d failure = %#v", iteration, failure)
			}
		case <-time.After(2 * time.Second):
			t.Fatalf("iteration %d did not exit", iteration)
		}
	}
	deadline := time.Now().Add(2 * time.Second)
	for runtime.NumGoroutine() > baseline+1 && time.Now().Before(deadline) {
		runtime.Gosched()
		time.Sleep(time.Millisecond)
	}
	if got := runtime.NumGoroutine(); got > baseline+1 {
		t.Fatalf("goroutines after repeated cancellation = %d, baseline = %d", got, baseline)
	}
}

func TestRunRejectsInvalidConfigurationWithoutStartingWorkers(t *testing.T) {
	config := DefaultConfig()
	config.ReadChunkBytes = 0
	output := &closeBuffer{}
	failure := Run(context.Background(), io.NopCloser(bytes.NewReader(nil)), output, config)
	if failure == nil || failure.Code != ErrorInvalidConfiguration {
		t.Fatalf("failure = %#v", failure)
	}
}
