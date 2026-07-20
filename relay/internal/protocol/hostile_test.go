package protocol

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

type hostileCorpus struct {
	Algorithm         string                      `json:"algorithm"`
	BaseInputs        []hostileBaseInput          `json:"baseInputs"`
	FormatVersion     int                         `json:"formatVersion"`
	MaximumChunkBytes int                         `json:"maximumChunkBytes"`
	MaximumInputBytes int                         `json:"maximumInputBytes"`
	ProtocolVersion   uint16                      `json:"protocolVersion"`
	Reproduction      hostileReproductionCommands `json:"reproductionCommands"`
	Seeds             []hostileSeed               `json:"seeds"`
}

type hostileBaseInput struct {
	ID       string `json:"id"`
	InputHex string `json:"inputHex"`
}

type hostileReproductionCommands struct {
	Go     string `json:"go"`
	GoFuzz string `json:"goFuzz"`
	Swift  string `json:"swift"`
}

type hostileSeed struct {
	ExpectedSemanticDigest string `json:"expectedSemanticDigest"`
	ID                     string `json:"id"`
	Iterations             int    `json:"iterations"`
	Value                  string `json:"value"`
}

type hostileGenerator struct {
	state uint64
}

func (g *hostileGenerator) next() uint64 {
	g.state = g.state*6364136223846793005 + 1442695040888963407
	return g.state
}

type hostileDigest struct {
	value uint64
}

func newHostileDigest() hostileDigest {
	return hostileDigest{value: 14695981039346656037}
}

func (d *hostileDigest) add(token string) {
	for _, value := range []byte(token) {
		d.value ^= uint64(value)
		d.value *= 1099511628211
	}
	d.value ^= 0xff
	d.value *= 1099511628211
}

type hostileSummary struct {
	cases                               int
	inputBytes                          uint64
	maximumAllocations                  uint64
	maximumChunkCount                   int
	maximumDiagnostic                   int
	maximumProcessingIterations         uint64
	maximumProcessingIterationCeiling   uint64
	maximumResetOutstandingBodyBytes    int
	maximumResetRetainedBytes           int
	maximumTerminalOutstandingBodyBytes int
	maximumTerminalRetainedBytes        int
	peakAllocatedBodyBytes              int
	peakRetainedBytes                   int
}

func TestHostileInputCorpus(t *testing.T) {
	corpus := loadHostileCorpus(t)
	start := time.Now()
	summary := hostileSummary{}

	for _, seed := range corpus.Seeds {
		seed := seed
		t.Run(seed.ID, func(t *testing.T) {
			state, err := parseHostileSeed(seed.Value)
			if err != nil {
				t.Fatal(err)
			}
			generator := hostileGenerator{state: state}
			digest := newHostileDigest()
			for iteration := 0; iteration < seed.Iterations; iteration++ {
				input := mutateHostileInput(t, corpus, &generator)
				for _, direction := range []EnvelopeDirection{EnvelopeClientToRelay, EnvelopeRelayToClient} {
					_ = runHostileEnvelopeCase(t, input, direction, corpus, &generator, &digest, &summary)
				}
				if iteration%32 == 0 {
					runHostileCancellationCase(t, &digest, &summary)
				}
			}
			runHostileDeclaredLengthBoundaryCases(t, corpus, &digest, &summary)
			got := fmt.Sprintf("%016x", digest.value)
			fmt.Printf(
				"relay-hostile-seed language=go id=%s value=%s semanticDigest=%s\n",
				seed.ID, seed.Value, got,
			)
			if got != seed.ExpectedSemanticDigest {
				t.Fatalf("semantic digest %s, want %s", got, seed.ExpectedSemanticDigest)
			}
		})
	}

	duration := time.Since(start)
	fmt.Printf(
		"relay-hostile-summary language=go seeds=%d cases=%d inputBytes=%d peakRetainedBytes=%d peakAllocatedBodyBytes=%d maximumBodyAllocations=%d maximumProcessingIterations=%d maximumProcessingIterationCeiling=%d maximumChunkCount=%d maximumDiagnosticBytes=%d terminalRetainedBytes=%d terminalOutstandingBodyBytes=%d resetRetainedBytes=%d resetOutstandingBodyBytes=%d durationMilliseconds=%d\n",
		len(corpus.Seeds), summary.cases, summary.inputBytes, summary.peakRetainedBytes,
		summary.peakAllocatedBodyBytes, summary.maximumAllocations,
		summary.maximumProcessingIterations, summary.maximumProcessingIterationCeiling,
		summary.maximumChunkCount, summary.maximumDiagnostic,
		summary.maximumTerminalRetainedBytes, summary.maximumTerminalOutstandingBodyBytes,
		summary.maximumResetRetainedBytes, summary.maximumResetOutstandingBodyBytes,
		duration.Milliseconds(),
	)
}

func runHostileDeclaredLengthBoundaryCases(
	t *testing.T,
	corpus hostileCorpus,
	digest *hostileDigest,
	summary *hostileSummary,
) {
	t.Helper()
	atCeiling := hostileBaseInputByID(t, corpus, "declared-length-at-ceiling")
	overCeiling := hostileBaseInputByID(t, corpus, "declared-length-over-ceiling")
	generator := hostileGenerator{state: 0}

	for _, direction := range []EnvelopeDirection{EnvelopeClientToRelay, EnvelopeRelayToClient} {
		acceptedMetrics := runHostileEnvelopeCase(
			t, atCeiling, direction, corpus, &generator, digest, summary,
		)
		if acceptedMetrics.BodyAllocations != 1 ||
			acceptedMetrics.PeakAllocatedBodyBytes != int(MaxFrameDefault) {
			t.Fatalf("at-ceiling body allocation metrics: %#v", acceptedMetrics)
		}

		rejectedMetrics := runHostileEnvelopeCase(
			t, overCeiling, direction, corpus, &generator, digest, summary,
		)
		if rejectedMetrics.BodyAllocations != 0 || rejectedMetrics.PeakAllocatedBodyBytes != 0 {
			t.Fatalf("over-ceiling body allocation metrics: %#v", rejectedMetrics)
		}
	}
}

func loadHostileCorpus(t testing.TB) hostileCorpus {
	t.Helper()
	data, err := os.ReadFile(hostileCorpusPath(t))
	if err != nil {
		t.Fatal(err)
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var corpus hostileCorpus
	if err := decoder.Decode(&corpus); err != nil {
		t.Fatalf("hostile corpus schema mismatch: %v", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		t.Fatal("hostile corpus has trailing JSON values")
	}
	validateHostileCorpus(t, corpus)
	return corpus
}

func validateHostileCorpus(t testing.TB, corpus hostileCorpus) {
	t.Helper()
	if corpus.FormatVersion != 1 || corpus.ProtocolVersion != WireVersion || corpus.Algorithm != "lcg64-v1" {
		t.Fatal("hostile corpus identity mismatch")
	}
	if corpus.MaximumInputBytes < 1 || corpus.MaximumInputBytes > int(MaxFrameDefault) ||
		corpus.MaximumChunkBytes < 1 || corpus.MaximumChunkBytes > corpus.MaximumInputBytes {
		t.Fatal("hostile corpus bounds are invalid")
	}
	if len(corpus.BaseInputs) == 0 || len(corpus.Seeds) == 0 {
		t.Fatal("hostile corpus must contain bases and seeds")
	}
	identifiers := make(map[string]struct{})
	for _, base := range corpus.BaseInputs {
		if !validHostileIdentifier(base.ID) || base.InputHex != strings.ToLower(base.InputHex) {
			t.Fatal("invalid hostile base metadata")
		}
		decoded, err := hex.DecodeString(base.InputHex)
		if err != nil || len(decoded) == 0 || len(decoded) > corpus.MaximumInputBytes {
			t.Fatal("invalid hostile base input")
		}
		if _, exists := identifiers[base.ID]; exists {
			t.Fatal("duplicate hostile identifier")
		}
		identifiers[base.ID] = struct{}{}
	}
	if got := hostileBaseInputByID(t, corpus, "declared-length-at-ceiling"); !bytes.Equal(got, []byte{0, 0, 0x10, 0}) {
		t.Fatal("declared-length-at-ceiling corpus case drifted")
	}
	if got := hostileBaseInputByID(t, corpus, "declared-length-over-ceiling"); !bytes.Equal(got, []byte{0, 0, 0x10, 1}) {
		t.Fatal("declared-length-over-ceiling corpus case drifted")
	}
	for _, seed := range corpus.Seeds {
		if !validHostileIdentifier(seed.ID) || seed.Iterations < 1 || seed.Iterations > 4096 ||
			len(seed.ExpectedSemanticDigest) != 16 {
			t.Fatal("invalid hostile seed metadata")
		}
		if _, err := hex.DecodeString(seed.ExpectedSemanticDigest); err != nil {
			t.Fatal("invalid hostile seed digest")
		}
		if _, err := parseHostileSeed(seed.Value); err != nil {
			t.Fatal("invalid hostile seed value")
		}
		if _, exists := identifiers[seed.ID]; exists {
			t.Fatal("duplicate hostile identifier")
		}
		identifiers[seed.ID] = struct{}{}
	}
	if corpus.Reproduction.Go == "" || corpus.Reproduction.GoFuzz == "" || corpus.Reproduction.Swift == "" {
		t.Fatal("hostile corpus reproduction commands are missing")
	}
}

func FuzzHostileInputDecoder(f *testing.F) {
	corpus := loadHostileCorpus(f)
	for index, base := range corpus.BaseInputs {
		input, err := hex.DecodeString(base.InputHex)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(input, uint8(index+1), index%2 == 0)
	}
	f.Add([]byte{}, uint8(1), false)
	f.Add([]byte{0xff, 0xff, 0xff, 0xff}, uint8(31), true)

	f.Fuzz(func(t *testing.T, input []byte, chunkSelector uint8, relayToClient bool) {
		if len(input) > corpus.MaximumInputBytes {
			input = input[:corpus.MaximumInputBytes]
		}
		direction := EnvelopeClientToRelay
		if relayToClient {
			direction = EnvelopeRelayToClient
		}
		decoder := mustEnvelopeDecoder(t, MaxFrameDefault, direction, FeatureSetDNSPriorityHint, nil)
		width := int(chunkSelector)%corpus.MaximumChunkBytes + 1
		failed := false
		for offset := 0; offset < len(input); {
			end := min(offset+width, len(input))
			frames, failure := decoder.Consume(input[offset:end])
			offset = end
			if failure != nil {
				failed = true
				break
			}
			for _, frame := range frames {
				if frame.Type != MessageTypeUDPDatagram {
					continue
				}
				codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
				_, datagramFailure := codec.Decode(frame.Payload)
				if datagramFailure != nil && codec.Metrics().DecodedMaterializedBytes != 0 {
					t.Fatal("failed fuzz datagram materialized bytes")
				}
			}
		}
		if !failed {
			_ = decoder.EndOfStream()
		}
		metrics := decoder.Metrics()
		if metrics.RetainedBytes != 0 || metrics.PeakRetainedBytes > int(MaxFrameDefault)+FramePrefixWidth ||
			metrics.AllocatedBodyBytes != 0 || metrics.PeakAllocatedBodyBytes > int(MaxFrameDefault) ||
			metrics.BodyAllocations > uint64(len(input)/10+1) || metrics.InputBytes > uint64(len(input)) ||
			metrics.ProcessingIterations > hostileProcessingIterationCeiling(metrics) {
			t.Fatalf("fuzz decoder bounds violated: %#v", metrics)
		}
		decoder.Reset()
		if decoder.Metrics() != (CodecMetrics{}) || !decoder.AtFrameBoundary() {
			t.Fatal("fuzz decoder reset retained state")
		}
	})
}

func hostileCorpusPath(t testing.TB) string {
	t.Helper()
	if root := os.Getenv("RELUX_TUNNEL_REPO_ROOT"); root != "" {
		return filepath.Join(root, "Protocol", "Relay", "Fuzz", "v1", "regression-seeds.json")
	}
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot resolve hostile corpus path")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..", "..", "..", "Protocol", "Relay", "Fuzz", "v1", "regression-seeds.json"))
}

func mutateHostileInput(t testing.TB, corpus hostileCorpus, generator *hostileGenerator) []byte {
	t.Helper()
	base := corpus.BaseInputs[int(generator.next()%uint64(len(corpus.BaseInputs)))]
	input, err := hex.DecodeString(base.InputHex)
	if err != nil {
		t.Fatal("checked hostile base input became invalid")
	}
	input = append([]byte(nil), input...)
	switch generator.next() % 8 {
	case 0:
	case 1:
		index := int(generator.next() % uint64(len(input)))
		input[index] ^= byte(generator.next())
	case 2:
		input = input[:int(generator.next()%uint64(len(input)+1))]
	case 3:
		count := int(generator.next() % 17)
		for range count {
			input = append(input, byte(generator.next()))
		}
	case 4:
		for len(input) < FramePrefixWidth {
			input = append(input, 0)
		}
		length := uint32(generator.next())
		input[0] = byte(length >> 24)
		input[1] = byte(length >> 16)
		input[2] = byte(length >> 8)
		input[3] = byte(length)
	case 5:
		other := corpus.BaseInputs[int(generator.next()%uint64(len(corpus.BaseInputs)))]
		decoded, err := hex.DecodeString(other.InputHex)
		if err != nil {
			t.Fatal("checked hostile base input became invalid")
		}
		input = append(input, decoded...)
	case 6:
		input = make([]byte, int(generator.next()%uint64(corpus.MaximumInputBytes+1)))
		for index := range input {
			input[index] = byte(generator.next())
		}
	case 7:
		input = append([]byte("RLXR"), input...)
	}
	if len(input) > corpus.MaximumInputBytes {
		input = input[:corpus.MaximumInputBytes]
	}
	return input
}

func runHostileEnvelopeCase(
	t *testing.T,
	input []byte,
	direction EnvelopeDirection,
	corpus hostileCorpus,
	generator *hostileGenerator,
	digest *hostileDigest,
	summary *hostileSummary,
) CodecMetrics {
	t.Helper()
	decoder := mustEnvelopeDecoder(t, MaxFrameDefault, direction, FeatureSetDNSPriorityHint, nil)
	directionToken := "C"
	if direction == EnvelopeRelayToClient {
		directionToken = "R"
	}
	failed := false
	chunkCount := 0
	for offset := 0; offset < len(input); {
		width := int(generator.next()%uint64(corpus.MaximumChunkBytes)) + 1
		width = min(width, len(input)-offset)
		frames, failure := decoder.Consume(input[offset : offset+width])
		offset += width
		chunkCount++
		if failure != nil {
			recordHostileCodecFailure(t, directionToken, failure, digest, summary)
			failed = true
			break
		}
		for _, frame := range frames {
			digest.add(fmt.Sprintf("frame/%s/%d", directionToken, frame.Type))
			if frame.Type == MessageTypeUDPDatagram {
				codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
				_, datagramFailure := codec.Decode(frame.Payload)
				if datagramFailure == nil {
					digest.add("datagram/" + directionToken + "/ok")
				} else {
					recordHostileDatagramFailure(t, directionToken, datagramFailure, digest, summary)
					if codec.Metrics().DecodedMaterializedBytes != 0 {
						t.Fatal("failed hostile datagram materialized bytes")
					}
				}
			}
		}
	}
	if !failed {
		if failure := decoder.EndOfStream(); failure != nil {
			recordHostileCodecFailure(t, directionToken, failure, digest, summary)
		} else {
			digest.add("eof/" + directionToken + "/ok")
		}
	}
	metrics := decoder.Metrics()
	if metrics.RetainedBytes != 0 || metrics.PeakRetainedBytes > int(MaxFrameDefault)+FramePrefixWidth ||
		metrics.AllocatedBodyBytes != 0 || metrics.PeakAllocatedBodyBytes > int(MaxFrameDefault) ||
		metrics.BodyAllocations > uint64(len(input)/10+1) ||
		metrics.InputBytes > uint64(len(input)) ||
		metrics.ProcessingIterations > hostileProcessingIterationCeiling(metrics) {
		t.Fatalf("hostile decoder bounds violated: %#v", metrics)
	}
	summary.recordTerminal(metrics, chunkCount)
	decoder.Reset()
	if decoder.Metrics() != (CodecMetrics{}) || !decoder.AtFrameBoundary() {
		t.Fatal("hostile decoder reset retained state")
	}
	summary.recordReset(decoder.Metrics())
	return metrics
}

func runHostileCancellationCase(t *testing.T, digest *hostileDigest, summary *hostileSummary) {
	t.Helper()
	decoder := mustEnvelopeDecoder(t, MaxFrameDefault, EnvelopeClientToRelay, FeatureSetDNSPriorityHint, nil)
	if _, failure := decoder.Consume([]byte{0, 0, 0, 14, byte(MessageTypePing)}); failure != nil {
		t.Fatal(failure)
	}
	failure := decoder.Cancel()
	if failure == nil || failure.Code != CodecCancelled || decoder.Metrics().RetainedBytes != 0 ||
		decoder.Metrics().AllocatedBodyBytes != 0 {
		t.Fatal("hostile cancellation did not release state")
	}
	recordHostileCodecFailure(t, "C", failure, digest, summary)
	if decoder.Metrics().ProcessingIterations > hostileProcessingIterationCeiling(decoder.Metrics()) {
		t.Fatalf("hostile cancellation iteration bound violated: %#v", decoder.Metrics())
	}
	summary.recordTerminal(decoder.Metrics(), 1)
	decoder.Reset()
	if decoder.Metrics() != (CodecMetrics{}) || !decoder.AtFrameBoundary() {
		t.Fatal("cancelled decoder reset retained state")
	}
	summary.recordReset(decoder.Metrics())
}

func (s *hostileSummary) recordTerminal(metrics CodecMetrics, chunkCount int) {
	s.cases++
	s.inputBytes += metrics.InputBytes
	s.maximumAllocations = max(s.maximumAllocations, metrics.BodyAllocations)
	s.maximumChunkCount = max(s.maximumChunkCount, chunkCount)
	s.maximumProcessingIterations = max(s.maximumProcessingIterations, metrics.ProcessingIterations)
	s.maximumProcessingIterationCeiling = max(
		s.maximumProcessingIterationCeiling,
		hostileProcessingIterationCeiling(metrics),
	)
	s.maximumTerminalOutstandingBodyBytes = max(
		s.maximumTerminalOutstandingBodyBytes,
		metrics.AllocatedBodyBytes,
	)
	s.maximumTerminalRetainedBytes = max(s.maximumTerminalRetainedBytes, metrics.RetainedBytes)
	s.peakAllocatedBodyBytes = max(s.peakAllocatedBodyBytes, metrics.PeakAllocatedBodyBytes)
	s.peakRetainedBytes = max(s.peakRetainedBytes, metrics.PeakRetainedBytes)
}

func (s *hostileSummary) recordReset(metrics CodecMetrics) {
	s.maximumResetOutstandingBodyBytes = max(s.maximumResetOutstandingBodyBytes, metrics.AllocatedBodyBytes)
	s.maximumResetRetainedBytes = max(s.maximumResetRetainedBytes, metrics.RetainedBytes)
}

func hostileProcessingIterationCeiling(metrics CodecMetrics) uint64 {
	return metrics.InputBytes + metrics.BodyAllocations*3 + 1
}

func hostileBaseInputByID(t testing.TB, corpus hostileCorpus, id string) []byte {
	t.Helper()
	for _, base := range corpus.BaseInputs {
		if base.ID != id {
			continue
		}
		input, err := hex.DecodeString(base.InputHex)
		if err != nil {
			t.Fatal("checked hostile base input became invalid")
		}
		return input
	}
	t.Fatalf("hostile base input %s is missing", id)
	return nil
}

func recordHostileCodecFailure(
	t testing.TB,
	direction string,
	failure *CodecError,
	digest *hostileDigest,
	summary *hostileSummary,
) {
	t.Helper()
	description := failure.Error()
	validateHostileDiagnostic(t, description, "relayEnvelope", summary)
	digest.add(fmt.Sprintf(
		"envelope/%s/%s/%s/%s/%s",
		direction, failure.Code, failure.Phase, failure.Scope, failure.Disposition,
	))
}

func recordHostileDatagramFailure(
	t testing.TB,
	direction string,
	failure *DatagramError,
	digest *hostileDigest,
	summary *hostileSummary,
) {
	t.Helper()
	description := failure.Error()
	validateHostileDiagnostic(t, description, "relayDatagram", summary)
	digest.add(fmt.Sprintf(
		"datagram/%s/%s/%s/%s/%s",
		direction, failure.Code, failure.Phase, failure.Scope, failure.Disposition,
	))
}

func validateHostileDiagnostic(t testing.TB, description, prefix string, summary *hostileSummary) {
	t.Helper()
	if len(description) > 160 || !strings.HasPrefix(description, prefix+" code=") ||
		strings.Contains(description, "inputHex") || strings.Contains(description, "RLXR") {
		t.Fatalf("hostile diagnostic escaped finite schema: %q", description)
	}
	summary.maximumDiagnostic = max(summary.maximumDiagnostic, len(description))
}

func parseHostileSeed(value string) (uint64, error) {
	if !strings.HasPrefix(value, "0x") || len(value) != 18 || value != strings.ToLower(value) {
		return 0, fmt.Errorf("noncanonical hostile seed")
	}
	return strconv.ParseUint(value[2:], 16, 64)
}

func validHostileIdentifier(value string) bool {
	if value == "" {
		return false
	}
	for _, character := range value {
		if character != '-' && (character < 'a' || character > 'z') && (character < '0' || character > '9') {
			return false
		}
	}
	return true
}
