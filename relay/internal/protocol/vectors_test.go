package protocol

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"testing"
)

type vectorCorpus struct {
	FormatVersion   *int             `json:"formatVersion"`
	ProtocolVersion *uint16          `json:"protocolVersion"`
	Provenance      vectorProvenance `json:"provenance"`
	Vectors         []protocolVector `json:"vectors"`
}

type rawVectorCorpus struct {
	FormatVersion   *int              `json:"formatVersion"`
	ProtocolVersion *uint16           `json:"protocolVersion"`
	Provenance      vectorProvenance  `json:"provenance"`
	Vectors         []json.RawMessage `json:"vectors"`
}

type vectorProvenance struct {
	Generator              string             `json:"generator"`
	GeneratorFormatVersion *int               `json:"generatorFormatVersion"`
	GeneratorSHA256        string             `json:"generatorSHA256"`
	Privacy                string             `json:"privacy"`
	RegenerateCommand      string             `json:"regenerateCommand"`
	ReviewPolicy           vectorReviewPolicy `json:"reviewPolicy"`
	SchemaSHA256           string             `json:"schemaSHA256"`
	Sources                []string           `json:"sources"`
	Task                   string             `json:"task"`
}

type vectorReviewPolicy struct {
	Compatibility     string   `json:"compatibility"`
	Identifiers       string   `json:"identifiers"`
	RequiredConsumers []string `json:"requiredConsumers"`
}

type protocolVector struct {
	Chunks          []int          `json:"chunks"`
	Covers          []string       `json:"covers"`
	Direction       string         `json:"direction"`
	Expected        vectorExpected `json:"expected"`
	Features        []string       `json:"features"`
	ID              string         `json:"id"`
	InputHex        string         `json:"inputHex"`
	Kind            string         `json:"kind"`
	LimitReferences []string       `json:"limitRefs"`
	ProtocolVersion *uint16        `json:"protocolVersion"`
}

type vectorExpected struct {
	AddressHex  *string               `json:"addressHex,omitempty"`
	AddressType *string               `json:"addressType,omitempty"`
	Code        *string               `json:"code,omitempty"`
	DataHex     *string               `json:"dataHex,omitempty"`
	Disposition *string               `json:"disposition,omitempty"`
	Features    *uint32               `json:"features,omitempty"`
	Flags       *uint16               `json:"flags,omitempty"`
	Frames      []vectorExpectedFrame `json:"frames,omitempty"`
	MaxFrame    *uint32               `json:"maxFrame,omitempty"`
	Outcome     string                `json:"outcome"`
	Phase       *string               `json:"phase,omitempty"`
	Port        *uint16               `json:"port,omitempty"`
	Scope       *string               `json:"scope,omitempty"`
	Status      *uint16               `json:"status,omitempty"`
	Version     *uint16               `json:"version,omitempty"`
}

type vectorExpectedFrame struct {
	AssociationID uint32 `json:"associationID"`
	Flags         uint8  `json:"flags"`
	MessageType   string `json:"messageType"`
	PayloadHex    string `json:"payloadHex"`
}

type vectorHarnessError struct {
	VectorID string
	Reason   string
}

func (e *vectorHarnessError) Error() string {
	return fmt.Sprintf("relay vector %s: %s", e.VectorID, e.Reason)
}

func TestCanonicalVectorCorpusSchemaAndCoverage(t *testing.T) {
	corpus := loadVectorCorpus(t)
	if *corpus.FormatVersion != 1 || *corpus.ProtocolVersion != WireVersion {
		t.Fatal("canonical vector corpus version mismatch")
	}
	if corpus.Provenance.SchemaSHA256 != SchemaSHA256 {
		t.Fatal("canonical vector schema digest mismatch")
	}
	if len(corpus.Vectors) == 0 {
		t.Fatal("canonical vector corpus is empty")
	}
}

func TestCanonicalVectorLoaderReportsIdentifierWithoutBytes(t *testing.T) {
	data, err := os.ReadFile(vectorCorpusPath(t))
	if err != nil {
		t.Fatal(err)
	}
	var root map[string]any
	if err := json.Unmarshal(data, &root); err != nil {
		t.Fatal(err)
	}
	vectors := root["vectors"].([]any)
	first := vectors[0].(map[string]any)
	identifier := first["id"].(string)
	inputHex := first["inputHex"].(string)
	first["unknownSchemaField"] = true
	mutated, err := json.Marshal(root)
	if err != nil {
		t.Fatal(err)
	}
	_, failure := decodeVectorCorpus(mutated)
	if failure == nil || failure.VectorID != identifier {
		t.Fatalf("loader failure identifier mismatch: got %v", failure)
	}
	if !strings.Contains(failure.Error(), identifier) || strings.Contains(failure.Error(), inputHex) {
		t.Fatal("loader failure did not preserve the privacy-safe identifier contract")
	}
}

func TestGoCodecsConsumeCanonicalVectors(t *testing.T) {
	corpus := loadVectorCorpus(t)
	for _, vector := range corpus.Vectors {
		vector := vector
		t.Run(vector.ID, func(t *testing.T) {
			if failure := consumeProtocolVector(vector); failure != nil {
				t.Fatal(failure)
			}
		})
	}
}

func loadVectorCorpus(t *testing.T) vectorCorpus {
	t.Helper()
	data, err := os.ReadFile(vectorCorpusPath(t))
	if err != nil {
		t.Fatal(err)
	}
	corpus, failure := decodeVectorCorpus(data)
	if failure != nil {
		t.Fatal(failure)
	}
	return corpus
}

func vectorCorpusPath(t *testing.T) string {
	t.Helper()
	if root := os.Getenv("RELUX_TUNNEL_REPO_ROOT"); root != "" {
		return filepath.Join(root, "Protocol", "Relay", "Vectors", "v1", "corpus.json")
	}
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot resolve vector test source path")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..", "..", "..", "Protocol", "Relay", "Vectors", "v1", "corpus.json"))
}

func decodeVectorCorpus(data []byte) (vectorCorpus, *vectorHarnessError) {
	var raw rawVectorCorpus
	if err := decodeStrictJSON(data, &raw); err != nil {
		return vectorCorpus{}, &vectorHarnessError{VectorID: "<corpus>", Reason: "top-level schema mismatch"}
	}
	corpus := vectorCorpus{
		FormatVersion:   raw.FormatVersion,
		ProtocolVersion: raw.ProtocolVersion,
		Provenance:      raw.Provenance,
		Vectors:         make([]protocolVector, 0, len(raw.Vectors)),
	}
	for _, encoded := range raw.Vectors {
		var identity struct {
			ID string `json:"id"`
		}
		_ = json.Unmarshal(encoded, &identity)
		if identity.ID == "" {
			identity.ID = "<unknown>"
		}
		var vector protocolVector
		if err := decodeStrictJSON(encoded, &vector); err != nil {
			return vectorCorpus{}, &vectorHarnessError{VectorID: identity.ID, Reason: "vector schema mismatch"}
		}
		corpus.Vectors = append(corpus.Vectors, vector)
	}
	if failure := validateVectorCorpus(corpus); failure != nil {
		return vectorCorpus{}, failure
	}
	return corpus, nil
}

func decodeStrictJSON(data []byte, destination any) error {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return err
	}
	if decoder.More() {
		return fmt.Errorf("trailing JSON value")
	}
	return nil
}

func validateVectorCorpus(corpus vectorCorpus) *vectorHarnessError {
	if corpus.FormatVersion == nil || *corpus.FormatVersion != 1 ||
		corpus.ProtocolVersion == nil || *corpus.ProtocolVersion != WireVersion {
		return &vectorHarnessError{VectorID: "<corpus>", Reason: "unsupported corpus version"}
	}
	provenance := corpus.Provenance
	if provenance.Generator != "scripts/relay-protocol-vectors.py" ||
		provenance.GeneratorFormatVersion == nil || *provenance.GeneratorFormatVersion != 1 ||
		len(provenance.GeneratorSHA256) != 64 ||
		provenance.Privacy != "synthetic-only-rfc-reserved-endpoints" ||
		provenance.RegenerateCommand != "make relay-protocol-vectors-generate" ||
		provenance.SchemaSHA256 != SchemaSHA256 || provenance.Task != "TASK-260715-1q7u14" ||
		provenance.ReviewPolicy.Compatibility == "" || provenance.ReviewPolicy.Identifiers == "" ||
		len(provenance.Sources) == 0 {
		return &vectorHarnessError{VectorID: "<corpus>", Reason: "invalid provenance"}
	}
	wantConsumers := []string{"Go relay/internal/protocol", "Swift ReluxTunnelCoreTests"}
	gotConsumers := append([]string(nil), provenance.ReviewPolicy.RequiredConsumers...)
	sort.Strings(gotConsumers)
	if !equalStrings(gotConsumers, wantConsumers) {
		return &vectorHarnessError{VectorID: "<corpus>", Reason: "consumer provenance mismatch"}
	}

	identifiers := make(map[string]struct{}, len(corpus.Vectors))
	coverage := make(map[string]struct{})
	for _, vector := range corpus.Vectors {
		if !validVectorIdentifier(vector.ID) {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "invalid identifier"}
		}
		if _, exists := identifiers[vector.ID]; exists {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "duplicate identifier"}
		}
		identifiers[vector.ID] = struct{}{}
		if vector.ProtocolVersion == nil || *vector.ProtocolVersion != *corpus.ProtocolVersion {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "protocol version mismatch"}
		}
		input, err := hex.DecodeString(vector.InputHex)
		if err != nil || vector.InputHex != strings.ToLower(vector.InputHex) {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "noncanonical input hex"}
		}
		if len(vector.Chunks) != 0 {
			total := 0
			for _, size := range vector.Chunks {
				if size <= 0 {
					return &vectorHarnessError{VectorID: vector.ID, Reason: "invalid chunk plan"}
				}
				total += size
			}
			if total != len(input) {
				return &vectorHarnessError{VectorID: vector.ID, Reason: "invalid chunk plan"}
			}
		}
		for _, reference := range vector.LimitReferences {
			if _, ok := resolveVectorLimit(reference); !ok {
				return &vectorHarnessError{VectorID: vector.ID, Reason: "invalid limit reference"}
			}
		}
		for _, feature := range vector.Features {
			if feature != "dnsPriorityHint" {
				return &vectorHarnessError{VectorID: vector.ID, Reason: "unknown feature"}
			}
		}
		if failure := validateVectorExpected(vector); failure != nil {
			return failure
		}
		for _, tag := range vector.Covers {
			coverage[tag] = struct{}{}
		}
	}
	for tag := range requiredVectorCoverage() {
		if _, ok := coverage[tag]; !ok {
			return &vectorHarnessError{VectorID: "<corpus>", Reason: "required coverage missing"}
		}
	}
	return nil
}

func validateVectorExpected(vector protocolVector) *vectorHarnessError {
	expected := vector.Expected
	if expected.Outcome == "failure" {
		if expected.Code == nil || expected.Phase == nil || expected.Scope == nil || expected.Disposition == nil ||
			expected.Version != nil || expected.Frames != nil || expected.AddressType != nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "invalid failure expectation"}
		}
		return nil
	}
	if expected.Outcome != "success" {
		return &vectorHarnessError{VectorID: vector.ID, Reason: "unknown outcome"}
	}
	switch vector.Kind {
	case "clientHello":
		if expected.Version == nil || expected.Flags == nil || expected.MaxFrame == nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "incomplete client hello expectation"}
		}
	case "serverHello":
		if expected.Version == nil || expected.Status == nil || expected.Features == nil || expected.MaxFrame == nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "incomplete server hello expectation"}
		}
	case "envelope", "stream":
		if expected.Frames == nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "missing frame expectation"}
		}
	case "datagram":
		if expected.AddressType == nil || expected.AddressHex == nil || expected.Port == nil || expected.DataHex == nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "incomplete datagram expectation"}
		}
	case "envelopeDatagram":
		if expected.Frames == nil || expected.AddressType == nil || expected.AddressHex == nil || expected.Port == nil || expected.DataHex == nil {
			return &vectorHarnessError{VectorID: vector.ID, Reason: "incomplete envelope datagram expectation"}
		}
	default:
		return &vectorHarnessError{VectorID: vector.ID, Reason: "unknown kind"}
	}
	return nil
}

func consumeProtocolVector(vector protocolVector) *vectorHarnessError {
	input, err := hex.DecodeString(vector.InputHex)
	if err != nil {
		return vectorFailure(vector, "invalid hex")
	}
	switch vector.Kind {
	case "clientHello":
		return consumeClientHelloVector(vector, input)
	case "serverHello":
		return consumeServerHelloVector(vector, input)
	case "envelope", "stream", "envelopeDatagram":
		return consumeEnvelopeVector(vector, input)
	case "datagram":
		return consumeDatagramVector(vector, input)
	default:
		return vectorFailure(vector, "unknown kind")
	}
}

func consumeClientHelloVector(vector protocolVector, input []byte) *vectorHarnessError {
	hello, failure := DecodeClientHelloExact(input, DefaultServerHandshakeConfig())
	if failure != nil {
		return compareHandshakeVectorFailure(vector, failure)
	}
	if vector.Expected.Outcome != "success" {
		return vectorFailure(vector, "expected failure")
	}
	if hello.Version != *vector.Expected.Version || hello.Flags != *vector.Expected.Flags || hello.MaxFrame != *vector.Expected.MaxFrame {
		return vectorFailure(vector, "decoded client hello mismatch")
	}
	return nil
}

func consumeServerHelloVector(vector protocolVector, input []byte) *vectorHarnessError {
	// Go owns the server side and has no server-hello decoder. The strict loader
	// and independent Python oracle audit hostile server hellos; successful
	// server outputs are byte-compared against the production encoder here.
	if vector.Expected.Outcome != "success" {
		return nil
	}
	encoded := EncodeServerHello(
		*vector.Expected.Version,
		HelloStatus(*vector.Expected.Status),
		FeatureSet(*vector.Expected.Features),
		*vector.Expected.MaxFrame,
	)
	if !bytes.Equal(encoded[:], input) {
		return vectorFailure(vector, "server hello encoder mismatch")
	}
	return nil
}

func consumeEnvelopeVector(vector protocolVector, input []byte) *vectorHarnessError {
	maximumFrame, ok := resolveVectorLimit(vector.LimitReferences[0])
	if !ok || maximumFrame > uint64(^uint32(0)) {
		return vectorFailure(vector, "invalid maxFrame reference")
	}
	direction, ok := vectorEnvelopeDirection(vector.Direction)
	if !ok {
		return vectorFailure(vector, "invalid direction")
	}
	decoder, codecFailure := NewEnvelopeDecoder(uint32(maximumFrame), direction, vectorFeatureSet(vector.Features), nil)
	if codecFailure != nil {
		return vectorFailure(vector, "decoder configuration failure")
	}
	chunks, chunkFailure := vectorChunks(input, vector.Chunks)
	if chunkFailure != nil {
		return vectorFailure(vector, "invalid chunk plan")
	}
	frames := make([]Envelope, 0)
	for _, chunk := range chunks {
		decoded, failure := decoder.Consume(chunk)
		if failure != nil {
			return compareCodecVectorFailure(vector, failure)
		}
		frames = append(frames, decoded...)
	}
	if failure := decoder.EndOfStream(); failure != nil {
		return compareCodecVectorFailure(vector, failure)
	}
	encoder, codecFailure := NewEnvelopeEncoder(uint32(maximumFrame), direction, vectorFeatureSet(vector.Features), nil)
	if codecFailure != nil {
		return vectorFailure(vector, "encoder configuration failure")
	}
	if vector.Kind == "envelopeDatagram" && vector.Expected.Outcome == "failure" {
		if len(frames) != 1 {
			return vectorFailure(vector, "frame count mismatch")
		}
		encoded, failure := encoder.Encode(frames[0])
		if failure != nil || !bytes.Equal(encoded.Bytes(), input) {
			return vectorFailure(vector, "envelope encoder mismatch")
		}
		return consumeDatagramVector(vector, frames[0].Payload)
	}
	if vector.Expected.Outcome != "success" || len(frames) != len(vector.Expected.Frames) {
		return vectorFailure(vector, "frame outcome mismatch")
	}
	reencoded := make([]byte, 0, len(input))
	for index, frame := range frames {
		if failure := compareExpectedFrame(vector, frame, vector.Expected.Frames[index]); failure != nil {
			return failure
		}
		encoded, failure := encoder.Encode(frame)
		if failure != nil {
			return vectorFailure(vector, "envelope encode failure")
		}
		reencoded = append(reencoded, encoded.Bytes()...)
	}
	if !bytes.Equal(reencoded, input) {
		return vectorFailure(vector, "envelope encoder mismatch")
	}
	if vector.Kind == "envelopeDatagram" {
		return consumeDatagramVector(vector, frames[0].Payload)
	}
	return nil
}

func consumeDatagramVector(vector protocolVector, input []byte) *vectorHarnessError {
	referenceIndex := 0
	if vector.Kind == "envelopeDatagram" {
		referenceIndex = 1
	}
	maximumPayload, ok := resolveVectorLimit(vector.LimitReferences[referenceIndex])
	if !ok || maximumPayload > uint64(^uint16(0)) {
		return vectorFailure(vector, "invalid payload limit reference")
	}
	codec, failure := NewDatagramCodec(uint16(maximumPayload))
	if failure != nil {
		return vectorFailure(vector, "datagram codec configuration failure")
	}
	datagram, datagramFailure := codec.Decode(input)
	if datagramFailure != nil {
		return compareDatagramVectorFailure(vector, datagramFailure)
	}
	if vector.Expected.Outcome != "success" {
		return vectorFailure(vector, "expected failure")
	}
	address, err := hex.DecodeString(*vector.Expected.AddressHex)
	if err != nil {
		return vectorFailure(vector, "invalid expected address")
	}
	addressType, ok := vectorAddressType(*vector.Expected.AddressType)
	if !ok || datagram.Endpoint.Address.Type != addressType ||
		!bytes.Equal(datagram.Endpoint.Address.Bytes, address) || datagram.Endpoint.Port != *vector.Expected.Port {
		return vectorFailure(vector, "decoded datagram endpoint mismatch")
	}
	payload, err := hex.DecodeString(*vector.Expected.DataHex)
	if err != nil || !bytes.Equal(datagram.Data, payload) {
		return vectorFailure(vector, "decoded datagram payload mismatch")
	}
	encoded, failure := codec.Encode(datagram)
	if failure != nil || !bytes.Equal(encoded, input) {
		return vectorFailure(vector, "datagram encoder mismatch")
	}
	return nil
}

func compareExpectedFrame(vector protocolVector, frame Envelope, expected vectorExpectedFrame) *vectorHarnessError {
	messageType, ok := vectorMessageType(expected.MessageType)
	if !ok || frame.Type != messageType || frame.Flags != expected.Flags || frame.AssociationID != expected.AssociationID {
		return vectorFailure(vector, "decoded frame metadata mismatch")
	}
	payload, err := hex.DecodeString(expected.PayloadHex)
	if err != nil || !bytes.Equal(frame.Payload, payload) {
		return vectorFailure(vector, "decoded frame payload mismatch")
	}
	return nil
}

func compareHandshakeVectorFailure(vector protocolVector, failure *HandshakeError) *vectorHarnessError {
	if vector.Expected.Outcome != "failure" || vector.Expected.Code == nil ||
		string(failure.Code) != *vector.Expected.Code || string(failure.Phase) != *vector.Expected.Phase ||
		failure.Scope != *vector.Expected.Scope || failure.Disposition != *vector.Expected.Disposition {
		return vectorFailure(vector, "handshake failure mismatch")
	}
	return nil
}

func compareCodecVectorFailure(vector protocolVector, failure *CodecError) *vectorHarnessError {
	if vector.Expected.Outcome != "failure" || vector.Expected.Code == nil ||
		string(failure.Code) != *vector.Expected.Code || string(failure.Phase) != *vector.Expected.Phase ||
		failure.Scope != *vector.Expected.Scope || failure.Disposition != *vector.Expected.Disposition {
		return vectorFailure(vector, "envelope failure mismatch")
	}
	return nil
}

func compareDatagramVectorFailure(vector protocolVector, failure *DatagramError) *vectorHarnessError {
	if vector.Expected.Outcome != "failure" || vector.Expected.Code == nil ||
		string(failure.Code) != *vector.Expected.Code || string(failure.Phase) != *vector.Expected.Phase ||
		failure.Scope != *vector.Expected.Scope || failure.Disposition != *vector.Expected.Disposition {
		return vectorFailure(vector, "datagram failure mismatch")
	}
	return nil
}

func vectorFailure(vector protocolVector, reason string) *vectorHarnessError {
	return &vectorHarnessError{VectorID: vector.ID, Reason: reason}
}

func resolveVectorLimit(reference string) (uint64, bool) {
	parts := strings.SplitN(reference, ".", 2)
	if len(parts) != 2 {
		return 0, false
	}
	for _, limit := range Limits {
		if limit.Name != parts[0] {
			continue
		}
		switch parts[1] {
		case "floor":
			return limit.Floor, true
		case "clientDefault":
			return limit.ClientDefault, true
		case "relayDefault":
			return limit.RelayDefault, true
		case "clientHardCeiling":
			return limit.ClientHardCeiling, true
		case "relayHardCeiling":
			return limit.RelayHardCeiling, true
		default:
			return 0, false
		}
	}
	return 0, false
}

func vectorFeatureSet(names []string) FeatureSet {
	for _, name := range names {
		if name == "dnsPriorityHint" {
			return FeatureSetDNSPriorityHint
		}
	}
	return 0
}

func vectorEnvelopeDirection(raw string) (EnvelopeDirection, bool) {
	switch raw {
	case "clientToRelay":
		return EnvelopeClientToRelay, true
	case "relayToClient":
		return EnvelopeRelayToClient, true
	default:
		return "", false
	}
}

func vectorAddressType(name string) (AddressType, bool) {
	for _, metadata := range AddressTypeMetadataTable {
		if metadata.Name == name {
			return metadata.Type, true
		}
	}
	return 0, false
}

func vectorMessageType(name string) (MessageType, bool) {
	for _, metadata := range MessageMetadataTable {
		if metadata.Name == name {
			return metadata.Type, true
		}
	}
	return 0, false
}

func vectorChunks(input []byte, plan []int) ([][]byte, error) {
	if len(plan) == 0 {
		return [][]byte{input}, nil
	}
	result := make([][]byte, 0, len(plan))
	offset := 0
	for _, size := range plan {
		if size <= 0 || size > len(input)-offset {
			return nil, fmt.Errorf("invalid chunk")
		}
		result = append(result, input[offset:offset+size])
		offset += size
	}
	if offset != len(input) {
		return nil, fmt.Errorf("incomplete chunk plan")
	}
	return result, nil
}

func validVectorIdentifier(identifier string) bool {
	if !strings.HasPrefix(identifier, "v1.") {
		return false
	}
	for _, value := range identifier {
		if value >= 'a' && value <= 'z' || value >= '0' && value <= '9' || value == '.' || value == '-' {
			continue
		}
		return false
	}
	return true
}

func requiredVectorCoverage() map[string]struct{} {
	required := map[string]struct{}{
		"hello:client": {}, "hello:server": {}, "chunk:fragmented": {}, "chunk:coalesced": {},
		"failureScope:session.closeSession": {}, "failureScope:association.closeAssociation": {},
		"failureScope:association.rejectDatagram": {}, "boundary:frameBody:maximumLegal": {},
		"boundary:frameBody:aboveMaximumLegal": {}, "boundary:maxFrame:belowFloor": {},
		"boundary:maxFrame:floor": {}, "boundary:maxFrame:ceiling": {},
		"boundary:maxFrame:aboveCeiling": {}, "boundary:payload:zero": {},
		"boundary:payload:maximum": {}, "boundary:payload:aboveMaximum": {},
		"boundary:domain:minimum": {}, "boundary:domain:maximum": {}, "boundary:domain:aboveMaximum": {},
	}
	for _, metadata := range MessageMetadataTable {
		required["messageType:"+metadata.Name] = struct{}{}
		directions := []string{string(metadata.Direction)}
		if metadata.Direction == MessageDirectionBoth {
			directions = []string{"clientToRelay", "relayToClient"}
		}
		for _, direction := range directions {
			required["direction:"+metadata.Name+":"+direction] = struct{}{}
		}
	}
	for _, metadata := range AddressTypeMetadataTable {
		required["addressType:"+metadata.Name] = struct{}{}
	}
	for _, status := range HelloStatusNames {
		required["helloStatus:"+status.Name] = struct{}{}
	}
	for _, code := range UDPErrorCodeNames {
		required["udpError:"+code.Name] = struct{}{}
	}
	return required
}

func equalStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}
