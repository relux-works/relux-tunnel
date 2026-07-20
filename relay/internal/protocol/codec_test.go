package protocol

import (
	"bytes"
	"encoding/binary"
	"errors"
	"math"
	"strings"
	"testing"
)

func TestEnvelopeEncoderExactWireAndWriteSlices(t *testing.T) {
	encoder := mustEnvelopeEncoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
	frame := Envelope{
		Type:          MessageTypeUDPDatagram,
		Flags:         EnvelopeFlagDNSPriority,
		AssociationID: 0x01020304,
		Payload:       []byte{0xaa, 0xbb, 0xcc},
	}
	encoded, failure := encoder.Encode(frame)
	if failure != nil {
		t.Fatal(failure)
	}
	if got := len(encoded.WriteSlices()); got != 2 {
		t.Fatalf("write slice count %d, want 2", got)
	}
	want := []byte{
		0x00, 0x00, 0x00, 0x09,
		0x10, 0x01,
		0x01, 0x02, 0x03, 0x04,
		0xaa, 0xbb, 0xcc,
	}
	if got := encoded.Bytes(); !bytes.Equal(got, want) {
		t.Fatalf("encoded bytes %x, want %x", got, want)
	}
	metrics := encoder.Metrics()
	if metrics.OutputFrames != 1 || metrics.OutputBytes != uint64(len(want)) || metrics.Failures != 0 {
		t.Fatalf("unexpected encoder metrics: %#v", metrics)
	}
}

func TestEnvelopeEncoderEveryLegalPayloadSize(t *testing.T) {
	maximumFrame := MaxFrameFloor
	for payloadLength := 0; payloadLength <= int(maximumFrame)-EnvelopeHeaderWidth; payloadLength++ {
		encoder := mustEnvelopeEncoder(t, maximumFrame, EnvelopeClientToRelay, 0, nil)
		encoded, failure := encoder.Encode(Envelope{
			Type:          MessageTypeUDPDatagram,
			AssociationID: 1,
			Payload:       bytes.Repeat([]byte{byte(payloadLength)}, payloadLength),
		})
		if failure != nil {
			t.Fatalf("payload length %d: %v", payloadLength, failure)
		}
		wantLength := uint32(EnvelopeHeaderWidth + payloadLength)
		if got := binary.BigEndian.Uint32(encoded.Bytes()[:4]); got != wantLength {
			t.Fatalf("payload length %d encoded frame length %d, want %d", payloadLength, got, wantLength)
		}
		if encoded.ByteCount() != FramePrefixWidth+int(wantLength) {
			t.Fatalf("payload length %d byte count %d", payloadLength, encoded.ByteCount())
		}
	}
}

func TestEnvelopeEncoderArithmeticAndCapFailures(t *testing.T) {
	cases := []struct {
		name        string
		payload     uint64
		maximum     uint32
		failureCode CodecErrorCode
	}{
		{"overflow", math.MaxUint64, MaxFrameHardCeiling, CodecArithmeticOverflow},
		{"over cap", uint64(MaxFrameDefault), MaxFrameDefault, CodecLengthExceedsMaximum},
		{"invalid cap", 0, MinFrameLength - 1, CodecInvalidConfiguration},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			if _, failure := ValidateEnvelopeFrameLength(test.payload, test.maximum); failure == nil || failure.Code != test.failureCode {
				t.Fatalf("failure %#v, want %s", failure, test.failureCode)
			}
		})
	}
}

func TestEnvelopeDecoderEverySplitAndCoalescedFrames(t *testing.T) {
	frames := legalClientEnvelopes()
	wire := encodeEnvelopes(t, frames, MaxFrameDefault, EnvelopeClientToRelay)

	for split := 0; split <= len(wire); split++ {
		decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
		first, failure := decoder.Consume(wire[:split])
		if failure != nil {
			t.Fatalf("split %d first: %v", split, failure)
		}
		second, failure := decoder.Consume(wire[split:])
		if failure != nil {
			t.Fatalf("split %d second: %v", split, failure)
		}
		assertEnvelopesEqual(t, append(first, second...), frames)
		if failure = decoder.EndOfStream(); failure != nil {
			t.Fatalf("split %d EOF: %v", split, failure)
		}
		assertCodecMetricsReconcile(t, decoder.Metrics())
	}

	oneByte := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
	var decoded []Envelope
	for _, value := range wire {
		frames, failure := oneByte.Consume([]byte{value})
		if failure != nil {
			t.Fatal(failure)
		}
		decoded = append(decoded, frames...)
	}
	assertEnvelopesEqual(t, decoded, frames)
	assertCodecMetricsReconcile(t, oneByte.Metrics())
}

func TestEnvelopeDecoderEveryMaximumFrameSplitIsBounded(t *testing.T) {
	maximumFrame := MaxFrameFloor
	frame := Envelope{
		Type:          MessageTypeUDPDatagram,
		AssociationID: math.MaxUint32,
		Payload:       bytes.Repeat([]byte{0xa5}, int(maximumFrame)-EnvelopeHeaderWidth),
	}
	wire := encodeEnvelopes(t, []Envelope{frame}, maximumFrame, EnvelopeClientToRelay)

	for split := 0; split <= len(wire); split++ {
		decoder := mustEnvelopeDecoder(t, maximumFrame, EnvelopeClientToRelay, 0, nil)
		first, failure := decoder.Consume(wire[:split])
		if failure != nil {
			t.Fatalf("split %d first: %v", split, failure)
		}
		second, failure := decoder.Consume(wire[split:])
		if failure != nil {
			t.Fatalf("split %d second: %v", split, failure)
		}
		assertEnvelopesEqual(t, append(first, second...), []Envelope{frame})
		metrics := decoder.Metrics()
		if metrics.PeakRetainedBytes > int(maximumFrame)+FramePrefixWidth {
			t.Fatalf("split %d retained peak %d above bound", split, metrics.PeakRetainedBytes)
		}
		assertCodecMetricsReconcile(t, metrics)
	}
}

func TestEnvelopeDecoderTerminalValidationFailures(t *testing.T) {
	expectDecodeFailure(t, CodecLengthBelowMinimum, framePrefix(5), EnvelopeClientToRelay, 0, nil)
	expectDecodeFailure(t, CodecUnknownMessageType, rawEnvelope(0xff, 0, 1, nil), EnvelopeClientToRelay, 0, nil)
	expectDecodeFailure(t, CodecReservedFlags, rawEnvelope(byte(MessageTypeCloseAssociation), 0x02, 1, nil), EnvelopeClientToRelay, 0, nil)
	expectDecodeFailure(t, CodecInvalidFlags, rawEnvelope(byte(MessageTypeCloseAssociation), EnvelopeFlagDNSPriority, 1, nil), EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
	expectDecodeFailure(t, CodecInvalidDirection, rawEnvelope(byte(MessageTypePong), 0, 0, make([]byte, 8)), EnvelopeClientToRelay, 0, nil)
	expectDecodeFailure(t, CodecInvalidAssociationID, rawEnvelope(byte(MessageTypeUDPDatagram), 0, 0, nil), EnvelopeClientToRelay, 0, nil)
	expectDecodeFailure(t, CodecInvalidPayloadLength, rawEnvelope(byte(MessageTypePing), 0, 0, make([]byte, 7)), EnvelopeClientToRelay, 0, nil)

	decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, 0, nil)
	validThenInvalid := append(
		encodeEnvelopes(t, []Envelope{{Type: MessageTypeCloseSession}}, MaxFrameDefault, EnvelopeClientToRelay),
		framePrefix(5)...,
	)
	decoded, failure := decoder.Consume(validThenInvalid)
	assertCodecFailure(t, failure, CodecLengthBelowMinimum)
	if len(decoded) != 0 {
		t.Fatalf("terminal consume returned %d transactional frames", len(decoded))
	}
	metrics := decoder.Metrics()
	if metrics.OutputFrames != 0 || metrics.OutputBytes != 0 || metrics.DiscardedBytes != uint64(len(validThenInvalid)) {
		t.Fatalf("transactional failure metrics %#v", metrics)
	}
}

func TestEnvelopeRelayToClientDirectionMatrix(t *testing.T) {
	frames := []Envelope{
		{Type: MessageTypeUDPError, AssociationID: 1, Payload: []byte{0, 1}},
		{Type: MessageTypePong, Payload: bytes.Repeat([]byte{7}, 8)},
		{Type: MessageTypeCloseAssociation, AssociationID: 1},
		{Type: MessageTypeCloseSession},
	}
	wire := encodeEnvelopes(t, frames, MaxFrameDefault, EnvelopeRelayToClient)
	decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeRelayToClient, 0, nil)
	decoded, failure := decoder.Consume(wire)
	if failure != nil {
		t.Fatal(failure)
	}
	assertEnvelopesEqual(t, decoded, frames)

	encoder := mustEnvelopeEncoder(t, MaxFrameDefault, EnvelopeRelayToClient, 0, nil)
	if _, failure = encoder.Encode(legalClientEnvelopes()[1]); failure == nil || failure.Code != CodecInvalidDirection {
		t.Fatalf("failure %#v, want %s", failure, CodecInvalidDirection)
	}
}

func TestEnvelopeDecoderOversizedPrefixDoesNotAllocateBody(t *testing.T) {
	decoder := mustEnvelopeDecoder(t, 32, EnvelopeClientToRelay, 0, nil)
	wire := framePrefix(33)
	if _, failure := decoder.Consume(wire); failure == nil || failure.Code != CodecLengthExceedsMaximum {
		t.Fatalf("failure %#v, want %s", failure, CodecLengthExceedsMaximum)
	}
	metrics := decoder.Metrics()
	if metrics.BodyAllocations != 0 {
		t.Fatalf("attacker-sized prefix caused %d body allocations", metrics.BodyAllocations)
	}
	if metrics.PeakRetainedBytes != FramePrefixWidth || metrics.RetainedBytes != 0 {
		t.Fatalf("unexpected retained metrics: %#v", metrics)
	}
	if metrics.DiscardedBytes != uint64(len(wire)) || metrics.Failures != 1 {
		t.Fatalf("unexpected failure metrics: %#v", metrics)
	}
}

func TestEnvelopeDecoderEOFIsCancellationResetAndMalformedState(t *testing.T) {
	prefixEOF := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, 0, nil)
	if _, failure := prefixEOF.Consume([]byte{0, 0, 0}); failure != nil {
		t.Fatal(failure)
	}
	failure := prefixEOF.EndOfStream()
	assertCodecFailure(t, failure, CodecUnexpectedEOF)
	if _, repeated := prefixEOF.Consume([]byte{1}); repeated != failure {
		t.Fatalf("terminal failure was not stable: first=%p repeated=%p", failure, repeated)
	}
	if prefixEOF.Metrics().Failures != 1 {
		t.Fatalf("repeated terminal event changed failure count: %#v", prefixEOF.Metrics())
	}

	ping := legalClientEnvelopes()[1]
	pingWire := encodeEnvelopes(t, []Envelope{ping}, MaxFrameDefault, EnvelopeClientToRelay)
	bodyEOF := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, 0, nil)
	if _, failure = bodyEOF.Consume(pingWire[:len(pingWire)-1]); failure != nil {
		t.Fatal(failure)
	}
	assertCodecFailure(t, bodyEOF.EndOfStream(), CodecUnexpectedEOF)

	cancelled := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, 0, nil)
	if _, failure = cancelled.Consume(pingWire[:5]); failure != nil {
		t.Fatal(failure)
	}
	assertCodecFailure(t, cancelled.Cancel(), CodecCancelled)
	if metrics := cancelled.Metrics(); metrics.RetainedBytes != 0 || metrics.DiscardedBytes != 5 {
		t.Fatalf("cancel metrics %#v", metrics)
	}
	cancelled.Reset()
	if cancelled.Metrics() != (CodecMetrics{}) {
		t.Fatalf("reset metrics %#v", cancelled.Metrics())
	}
	decoded, failure := cancelled.Consume(pingWire)
	if failure != nil {
		t.Fatal(failure)
	}
	assertEnvelopesEqual(t, decoded, []Envelope{ping})

	ended := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, 0, nil)
	if failure = ended.EndOfStream(); failure != nil {
		t.Fatal(failure)
	}
	if failure = ended.EndOfStream(); failure != nil {
		t.Fatal(failure)
	}
	if decoded, failure = ended.Consume(nil); failure != nil || len(decoded) != 0 {
		t.Fatalf("empty post-EOF consume = %#v, %v", decoded, failure)
	}
	_, failure = ended.Consume([]byte{0})
	assertCodecFailure(t, failure, CodecMalformedState)
}

func TestEnvelopeMetadataHookAndErrorsArePrivacySafe(t *testing.T) {
	hookError := errors.New("remote destination and payload must remain secret")
	decoder := mustEnvelopeDecoder(
		t,
		MaxFrameDefault,
		EnvelopeClientToRelay,
		0,
		func(metadata EnvelopeMetadata) error {
			if metadata.PayloadLength != 8 || metadata.AssociationID != 0 {
				t.Fatalf("unexpected hook metadata: %#v", metadata)
			}
			return hookError
		},
	)
	wire := encodeEnvelopes(t, []Envelope{legalClientEnvelopes()[1]}, MaxFrameDefault, EnvelopeClientToRelay)
	_, failure := decoder.Consume(wire)
	assertCodecFailure(t, failure, CodecMetadataRejected)
	for _, forbidden := range []string{"remote", "destination", "payload", hookError.Error()} {
		if strings.Contains(failure.Error(), forbidden) {
			t.Fatalf("privacy-safe failure contains %q: %s", forbidden, failure)
		}
	}
}

func TestEnvelopeDecoderDeterministicChunkProperties(t *testing.T) {
	frames := legalClientEnvelopes()
	wire := encodeEnvelopes(t, frames, MaxFrameDefault, EnvelopeClientToRelay)
	for seed := uint64(1); seed <= 64; seed++ {
		state := seed
		decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
		var output []Envelope
		for offset := 0; offset < len(wire); {
			state = state*6364136223846793005 + 1
			width := min(int(state%17)+1, len(wire)-offset)
			decoded, failure := decoder.Consume(wire[offset : offset+width])
			if failure != nil {
				t.Fatalf("seed %d offset %d: %v", seed, offset, failure)
			}
			output = append(output, decoded...)
			offset += width
			assertCodecMetricsReconcile(t, decoder.Metrics())
		}
		assertEnvelopesEqual(t, output, frames)
		if metrics := decoder.Metrics(); metrics.OutputFrames != uint64(len(frames)) || metrics.Failures != 0 {
			t.Fatalf("seed %d metrics %#v", seed, metrics)
		}
	}
}

func FuzzEnvelopeDecoderChunking(f *testing.F) {
	f.Add([]byte{1})
	f.Add([]byte{1, 2, 3, 5, 8, 13})
	f.Fuzz(func(t *testing.T, chunks []byte) {
		frames := legalClientEnvelopes()
		wire := encodeEnvelopes(t, frames, MaxFrameDefault, EnvelopeClientToRelay)
		decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
		var output []Envelope
		for offset, chunkIndex := 0, 0; offset < len(wire); chunkIndex++ {
			width := 1
			if len(chunks) != 0 {
				width = int(chunks[chunkIndex%len(chunks)])%31 + 1
			}
			width = min(width, len(wire)-offset)
			decoded, failure := decoder.Consume(wire[offset : offset+width])
			if failure != nil {
				t.Fatal(failure)
			}
			output = append(output, decoded...)
			offset += width
		}
		assertEnvelopesEqual(t, output, frames)
		assertCodecMetricsReconcile(t, decoder.Metrics())
	})
}

func legalClientEnvelopes() []Envelope {
	return []Envelope{
		{Type: MessageTypeUDPDatagram, Flags: EnvelopeFlagDNSPriority, AssociationID: 0x01020304, Payload: []byte{1, 2, 3, 4, 5}},
		{Type: MessageTypePing, AssociationID: 0, Payload: []byte{0, 1, 2, 3, 4, 5, 6, 7}},
		{Type: MessageTypeCloseAssociation, AssociationID: math.MaxUint32},
		{Type: MessageTypeCloseSession, AssociationID: 0},
	}
}

func encodeEnvelopes(t testing.TB, frames []Envelope, maximumFrame uint32, direction EnvelopeDirection) []byte {
	t.Helper()
	encoder := mustEnvelopeEncoder(t, maximumFrame, direction, FeatureSetDNSPriorityHint, nil)
	var wire []byte
	for _, frame := range frames {
		encoded, failure := encoder.Encode(frame)
		if failure != nil {
			t.Fatal(failure)
		}
		wire = append(wire, encoded.Bytes()...)
	}
	return wire
}

func rawEnvelope(messageType, flags byte, associationID uint32, payload []byte) []byte {
	wire := make([]byte, FramePrefixWidth+EnvelopeHeaderWidth+len(payload))
	binary.BigEndian.PutUint32(wire[:4], uint32(EnvelopeHeaderWidth+len(payload)))
	wire[4] = messageType
	wire[5] = flags
	binary.BigEndian.PutUint32(wire[6:10], associationID)
	copy(wire[10:], payload)
	return wire
}

func framePrefix(length uint32) []byte {
	wire := make([]byte, FramePrefixWidth)
	binary.BigEndian.PutUint32(wire, length)
	return wire
}

func expectDecodeFailure(
	t testing.TB,
	code CodecErrorCode,
	wire []byte,
	direction EnvelopeDirection,
	features FeatureSet,
	validator EnvelopeMetadataValidator,
) {
	t.Helper()
	decoder := mustEnvelopeDecoder(t, MaxFrameDefault, direction, features, validator)
	_, failure := decoder.Consume(wire)
	assertCodecFailure(t, failure, code)
	metrics := decoder.Metrics()
	if metrics.Failures != 1 || metrics.RetainedBytes != 0 || metrics.InputBytes != metrics.DiscardedBytes {
		t.Fatalf("failure metrics %#v", metrics)
	}
}

func mustEnvelopeEncoder(
	t testing.TB,
	maximumFrame uint32,
	direction EnvelopeDirection,
	features FeatureSet,
	validator EnvelopeMetadataValidator,
) *EnvelopeEncoder {
	t.Helper()
	encoder, failure := NewEnvelopeEncoder(maximumFrame, direction, features, validator)
	if failure != nil {
		t.Fatal(failure)
	}
	return encoder
}

func mustEnvelopeDecoder(
	t testing.TB,
	maximumFrame uint32,
	direction EnvelopeDirection,
	features FeatureSet,
	validator EnvelopeMetadataValidator,
) *EnvelopeDecoder {
	t.Helper()
	decoder, failure := NewEnvelopeDecoder(maximumFrame, direction, features, validator)
	if failure != nil {
		t.Fatal(failure)
	}
	return decoder
}

func assertCodecFailure(t testing.TB, failure *CodecError, code CodecErrorCode) {
	t.Helper()
	if failure == nil || failure.Code != code {
		t.Fatalf("failure %#v, want %s", failure, code)
	}
	if failure.Scope != "session" || failure.Disposition != "closeSession" {
		t.Fatalf("failure boundary %#v", failure)
	}
}

func assertEnvelopesEqual(t testing.TB, got, want []Envelope) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("got %d envelopes, want %d", len(got), len(want))
	}
	for index := range want {
		if got[index].Type != want[index].Type ||
			got[index].Flags != want[index].Flags ||
			got[index].AssociationID != want[index].AssociationID ||
			!bytes.Equal(got[index].Payload, want[index].Payload) {
			t.Fatalf("envelope %d = %#v, want %#v", index, got[index], want[index])
		}
	}
}

func assertCodecMetricsReconcile(t testing.TB, metrics CodecMetrics) {
	t.Helper()
	if metrics.InputBytes != metrics.OutputBytes+uint64(metrics.RetainedBytes)+metrics.DiscardedBytes {
		t.Fatalf("metrics do not reconcile: %#v", metrics)
	}
}
