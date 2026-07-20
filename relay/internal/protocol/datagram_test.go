package protocol

import (
	"bytes"
	"math"
	"testing"
)

func TestDatagramHEVGoldenVectors(t *testing.T) {
	for _, endpoint := range hevVectorEndpoints() {
		for _, data := range hevVectorPayloads() {
			datagram := Datagram{Endpoint: endpoint.endpoint, Data: data}
			expected := hevOracle(endpoint.headerTail, data)
			codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)

			encoded, failure := codec.Encode(datagram)
			if failure != nil {
				t.Fatalf("%s DATA=%d: %v", endpoint.name, len(data), failure)
			}
			if !bytes.Equal(encoded, expected) {
				t.Fatalf("%s DATA=%d wire mismatch", endpoint.name, len(data))
			}
			decoded, failure := codec.Decode(encoded)
			if failure != nil {
				t.Fatalf("%s DATA=%d decode: %v", endpoint.name, len(data), failure)
			}
			assertDatagramEqual(t, decoded, datagram)
			if len(encoded) != len(endpoint.headerTail)+2+len(data) {
				t.Fatalf("%s DATA=%d length=%d", endpoint.name, len(data), len(encoded))
			}
		}
	}
}

func TestDatagramEveryPermittedDataSize(t *testing.T) {
	for _, endpoint := range hevVectorEndpoints() {
		codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
		for length := 0; length <= int(MaxUDPPayloadRelayHardCeiling); length++ {
			data := hevPatternedData(length)
			datagram := Datagram{Endpoint: endpoint.endpoint, Data: data}
			encoded, failure := codec.Encode(datagram)
			if failure != nil {
				t.Fatalf("%s DATA=%d: %v", endpoint.name, length, failure)
			}
			if !bytes.Equal(encoded, hevOracle(endpoint.headerTail, data)) {
				t.Fatalf("%s DATA=%d wire mismatch", endpoint.name, length)
			}
			decoded, failure := codec.Decode(encoded)
			if failure != nil {
				t.Fatalf("%s DATA=%d decode: %v", endpoint.name, length, failure)
			}
			assertDatagramEqual(t, decoded, datagram)
			if len(encoded) > MaxHEVRecordWidth {
				t.Fatalf("%s DATA=%d record=%d", endpoint.name, length, len(encoded))
			}
		}
	}
}

func TestDatagramMaximumRecordWidth(t *testing.T) {
	domain := make([]byte, MaxDomainWireBytes)
	for index := range domain {
		domain[index] = byte(index)
	}
	datagram := Datagram{
		Endpoint: DatagramEndpoint{
			Address: DatagramAddress{Type: AddressTypeDomain, Bytes: domain},
			Port:    math.MaxUint16,
		},
		Data: hevPatternedData(int(MaxUDPPayloadRelayHardCeiling)),
	}
	codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	encoded, failure := codec.Encode(datagram)
	if failure != nil {
		t.Fatal(failure)
	}
	if len(encoded) != MaxHEVRecordWidth || encoded[2] != math.MaxUint8 || encoded[4] != MaxDomainWireBytes {
		t.Fatalf("maximum record shape len=%d hdr=%d domain=%d", len(encoded), encoded[2], encoded[4])
	}
	decoded, failure := codec.Decode(encoded)
	if failure != nil {
		t.Fatal(failure)
	}
	assertDatagramEqual(t, decoded, datagram)
}

func TestDatagramOpaqueDomainPolicy(t *testing.T) {
	datagram := Datagram{
		Endpoint: DatagramEndpoint{
			Address: DatagramAddress{Type: AddressTypeDomain, Bytes: []byte{0x00, 0x2E, 0x7F, 0x80, 0xFF}},
			Port:    5353,
		},
		Data: []byte{0x00, 0xFF},
	}
	codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	encoded, failure := codec.Encode(datagram)
	if failure != nil {
		t.Fatal(failure)
	}
	if !bytes.Equal(encoded[:5], []byte{0x00, 0x02, 0x0C, 0x03, 0x05}) {
		t.Fatalf("prefix %x", encoded[:5])
	}
	decoded, failure := codec.Decode(encoded)
	if failure != nil {
		t.Fatal(failure)
	}
	assertDatagramEqual(t, decoded, datagram)
}

func TestDatagramResponseSourceEndpointIsPreserved(t *testing.T) {
	originalDestination := DatagramEndpoint{
		Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2, 44}},
		Port:    443,
	}
	observedSource := DatagramEndpoint{
		Address: DatagramAddress{
			Type:  AddressTypeIPv6,
			Bytes: []byte{0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x2A},
		},
		Port: 8443,
	}
	codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	encoded, failure := codec.Encode(Datagram{Endpoint: observedSource, Data: []byte{0xCA, 0xFE}})
	if failure != nil {
		t.Fatal(failure)
	}
	decoded, failure := codec.Decode(encoded)
	if failure != nil {
		t.Fatal(failure)
	}
	if !datagramEndpointsEqual(decoded.Endpoint, observedSource) {
		t.Fatal("response source endpoint changed")
	}
	if datagramEndpointsEqual(decoded.Endpoint, originalDestination) {
		t.Fatal("response source endpoint was replaced by original destination")
	}
}

func TestDatagramMalformedRecordsFailBeforeMaterialization(t *testing.T) {
	tests := []struct {
		name   string
		record []byte
		code   DatagramErrorCode
	}{
		{"empty", nil, DatagramTruncatedFixedHeader},
		{"short MSGLEN", []byte{0x00}, DatagramTruncatedFixedHeader},
		{"short HDRLEN", []byte{0x00, 0x00}, DatagramTruncatedFixedHeader},
		{"short ATYP", []byte{0x00, 0x00, 0x0A}, DatagramTruncatedFixedHeader},
		{"unknown ATYP", []byte{0x00, 0x00, 0x0A, 0xFF}, DatagramUnknownAddressType},
		{"domain length missing", []byte{0x00, 0x00, 0x07, 0x03}, DatagramTruncatedAddress},
		{"empty domain", []byte{0x00, 0x00, 0x07, 0x03, 0x00, 0x00, 0x35}, DatagramInvalidAddressLength},
		{"domain too long", []byte{0x00, 0x00, 0xFF, 0x03, 0xF9}, DatagramInvalidAddressLength},
		{"wrong IPv4 HDRLEN", []byte{0x00, 0x00, 0x09, 0x01, 192, 0, 2, 1, 0, 53}, DatagramHeaderLengthMismatch},
		{"truncated IPv4", []byte{0x00, 0x00, 0x0A, 0x01, 192}, DatagramTruncatedAddress},
		{"truncated port", []byte{0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0}, DatagramTruncatedPort},
		{"zero port", []byte{0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0, 0}, DatagramInvalidPort},
		{"protocol-sized declaration with truncated DATA", []byte{0x05, 0xC1, 0x0A, 0x01, 192, 0, 2, 1, 0, 53}, DatagramMessageLengthMismatch},
		{"inner exceeds outer", []byte{0x00, 0x01, 0x0A, 0x01, 192, 0, 2, 1, 0, 53}, DatagramMessageLengthMismatch},
		{"outer exceeds inner", []byte{0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0, 53, 0xAA}, DatagramMessageLengthMismatch},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
			_, failure := codec.Decode(test.record)
			assertDatagramFailure(t, failure, test.code, "association", "closeAssociation")
			metrics := codec.Metrics()
			if metrics.DecodedMaterializedBytes != 0 || metrics.DecodedRecords != 0 || metrics.Failures != 1 {
				t.Fatalf("failure allocated or escaped: %#v", metrics)
			}
		})
	}
}

func TestDatagramStructuralValidationPrecedesPayloadLimits(t *testing.T) {
	limitTests := []struct {
		name                  string
		maximumPayloadLength  uint16
		declaredMessageLength uint16
	}{
		{"lowered local cap", MaxUDPPayloadFloor, MaxUDPPayloadFloor + 1},
		{"protocol ceiling", MaxUDPPayloadRelayDefault, MaxUDPPayloadRelayHardCeiling + 1},
	}

	for _, limitTest := range limitTests {
		t.Run(limitTest.name, func(t *testing.T) {
			for _, malformed := range datagramMalformedStructuralRecords(limitTest.declaredMessageLength) {
				t.Run(malformed.name, func(t *testing.T) {
					codec := mustDatagramCodec(t, limitTest.maximumPayloadLength)
					_, failure := codec.Decode(malformed.record)
					assertDatagramFailure(t, failure, malformed.code, "association", "closeAssociation")
					metrics := codec.Metrics()
					if metrics.DecodedMaterializedBytes != 0 || metrics.DecodedRecords != 0 || metrics.Failures != 1 {
						t.Fatalf("failure allocated or escaped: %#v", metrics)
					}
				})
			}
		})
	}

	t.Run("structurally valid protocol violation", func(t *testing.T) {
		data := hevPatternedData(int(MaxUDPPayloadRelayHardCeiling) + 1)
		record := hevOracle(hevVectorEndpoints()[0].headerTail, data)
		codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
		_, failure := codec.Decode(record)
		assertDatagramFailure(
			t,
			failure,
			DatagramMessageLengthExceedsProtocolLimit,
			"association",
			"closeAssociation",
		)
		if codec.Metrics().DecodedMaterializedBytes != 0 {
			t.Fatal("protocol violation materialized bytes")
		}
	})
}

func TestDatagramLocalCapDisposition(t *testing.T) {
	data := hevPatternedData(int(MaxUDPPayloadFloor) + 1)
	record := hevOracle(hevVectorEndpoints()[0].headerTail, data)
	codec := mustDatagramCodec(t, MaxUDPPayloadFloor)
	_, failure := codec.Decode(record)
	assertDatagramFailure(
		t,
		failure,
		DatagramMessageLengthExceedsLocalLimit,
		"association",
		"rejectDatagram",
	)
	if codec.Metrics().DecodedMaterializedBytes != 0 {
		t.Fatal("local-limit drop materialized bytes")
	}
}

func TestDatagramEncoderValidation(t *testing.T) {
	valid := DatagramEndpoint{
		Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}},
		Port:    53,
	}
	_, failure := ValidateDatagramEncodedLength(valid, math.MaxUint64, MaxUDPPayloadRelayDefault)
	assertDatagramFailure(t, failure, DatagramArithmeticOverflow, "association", "rejectDatagram")
	_, failure = ValidateDatagramEncodedLength(
		valid,
		uint64(MaxUDPPayloadRelayHardCeiling)+1,
		MaxUDPPayloadRelayDefault,
	)
	assertDatagramFailure(
		t,
		failure,
		DatagramMessageLengthExceedsProtocolLimit,
		"association",
		"rejectDatagram",
	)
	_, failure = ValidateDatagramEncodedLength(
		valid,
		uint64(MaxUDPPayloadFloor)+1,
		MaxUDPPayloadFloor,
	)
	assertDatagramFailure(
		t,
		failure,
		DatagramMessageLengthExceedsLocalLimit,
		"association",
		"rejectDatagram",
	)

	invalid := []struct {
		endpoint DatagramEndpoint
		code     DatagramErrorCode
	}{
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2}}, Port: 53}, DatagramInvalidAddressLength},
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressTypeIPv6, Bytes: make([]byte, 15)}, Port: 53}, DatagramInvalidAddressLength},
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressTypeDomain}, Port: 53}, DatagramInvalidAddressLength},
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressTypeDomain, Bytes: make([]byte, 249)}, Port: 53}, DatagramInvalidAddressLength},
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}}}, DatagramInvalidPort},
		{DatagramEndpoint{Address: DatagramAddress{Type: AddressType(0xFF), Bytes: []byte{1}}, Port: 53}, DatagramUnknownAddressType},
	}
	for _, test := range invalid {
		_, failure := ValidateDatagramEncodedLength(test.endpoint, 0, MaxUDPPayloadRelayDefault)
		assertDatagramFailure(t, failure, test.code, "association", "rejectDatagram")
	}
}

func TestDatagramConfigurationAndDiagnostics(t *testing.T) {
	_, failure := NewDatagramCodec(MaxUDPPayloadFloor - 1)
	assertDatagramFailure(t, failure, DatagramInvalidConfiguration, "session", "closeSession")
	_, failure = NewDatagramCodec(MaxUDPPayloadRelayHardCeiling + 1)
	assertDatagramFailure(t, failure, DatagramInvalidConfiguration, "session", "closeSession")

	codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	_, failure = codec.Decode([]byte{0x00, 0x00, 0x07, 0x03, 0x00})
	assertDatagramFailure(t, failure, DatagramInvalidAddressLength, "association", "closeAssociation")
	want := "relayDatagram code=invalidAddressLength phase=address scope=association disposition=closeAssociation"
	if failure.Error() != want {
		t.Fatalf("diagnostic %q, want %q", failure.Error(), want)
	}
}

var datagramAllocationSink Datagram
var datagramWireAllocationSink []byte

func TestDatagramAllocationsAreBounded(t *testing.T) {
	maxRecord := hevOracle(hevVectorEndpoints()[2].headerTail, hevPatternedData(int(MaxUDPPayloadRelayHardCeiling)))
	decoder := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	decodeAllocs := testing.AllocsPerRun(100, func() {
		decoded, failure := decoder.Decode(maxRecord)
		if failure != nil {
			panic(failure)
		}
		datagramAllocationSink = decoded
	})
	if decodeAllocs > 2 {
		t.Fatalf("decode allocations %.1f, want <= 2", decodeAllocs)
	}

	encoder := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	datagram := Datagram{
		Endpoint: hevVectorEndpoints()[2].endpoint,
		Data:     hevPatternedData(int(MaxUDPPayloadRelayHardCeiling)),
	}
	encodeAllocs := testing.AllocsPerRun(100, func() {
		encoded, failure := encoder.Encode(datagram)
		if failure != nil {
			panic(failure)
		}
		datagramWireAllocationSink = encoded
	})
	if encodeAllocs > 1 {
		t.Fatalf("encode allocations %.1f, want <= 1", encodeAllocs)
	}
}

func FuzzDatagramCodec(f *testing.F) {
	for _, endpoint := range hevVectorEndpoints() {
		for _, data := range hevVectorPayloads() {
			f.Add(hevOracle(endpoint.headerTail, data))
		}
	}
	f.Add([]byte{})
	f.Add([]byte{0x00, 0x00, 0x0A, 0xFF})
	f.Add([]byte{0x05, 0xC1, 0x0A, 0x01, 192, 0, 2, 1, 0, 53})

	f.Fuzz(func(t *testing.T, record []byte) {
		codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
		decoded, failure := codec.Decode(record)
		if failure != nil {
			if codec.Metrics().DecodedMaterializedBytes != 0 {
				t.Fatal("failed decode materialized bytes")
			}
			return
		}
		encoded, encodeFailure := codec.Encode(decoded)
		if encodeFailure != nil {
			t.Fatalf("decoded value did not re-encode: %v", encodeFailure)
		}
		if !bytes.Equal(encoded, record) {
			t.Fatal("accepted record was not canonical byte exact")
		}
		if len(encoded) > MaxHEVRecordWidth || len(decoded.Data) > int(MaxUDPPayloadRelayHardCeiling) {
			t.Fatal("accepted record exceeded a generated bound")
		}
	})
}

type hevVectorEndpoint struct {
	name       string
	endpoint   DatagramEndpoint
	headerTail []byte
}

type datagramMalformedStructuralRecord struct {
	name   string
	record []byte
	code   DatagramErrorCode
}

func datagramMalformedStructuralRecords(messageLength uint16) []datagramMalformedStructuralRecord {
	high := byte(messageLength >> 8)
	low := byte(messageLength)
	return []datagramMalformedStructuralRecord{
		{"unknown ATYP", []byte{high, low, 0x0A, 0xFF}, DatagramUnknownAddressType},
		{"wrong IPv4 HDRLEN", []byte{high, low, 0x09, 0x01, 192, 0, 2, 1, 0, 53}, DatagramHeaderLengthMismatch},
		{"truncated IPv4 address", []byte{high, low, 0x0A, 0x01, 192}, DatagramTruncatedAddress},
		{"truncated port", []byte{high, low, 0x0A, 0x01, 192, 0, 2, 1, 0}, DatagramTruncatedPort},
		{"zero port", []byte{high, low, 0x0A, 0x01, 192, 0, 2, 1, 0, 0}, DatagramInvalidPort},
		{"outer length mismatch", []byte{high, low, 0x0A, 0x01, 192, 0, 2, 1, 0, 53}, DatagramMessageLengthMismatch},
	}
}

func hevVectorEndpoints() []hevVectorEndpoint {
	return []hevVectorEndpoint{
		{
			name: "IPv4",
			endpoint: DatagramEndpoint{
				Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}},
				Port:    0x2035,
			},
			headerTail: []byte{0x0A, 0x01, 0xC0, 0x00, 0x02, 0x01, 0x20, 0x35},
		},
		{
			name: "IPv6",
			endpoint: DatagramEndpoint{
				Address: DatagramAddress{
					Type:  AddressTypeIPv6,
					Bytes: []byte{0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
				},
				Port: 0xBEEF,
			},
			headerTail: []byte{
				0x16, 0x04,
				0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0,
				0, 0, 0, 0, 0, 0, 0, 1,
				0xBE, 0xEF,
			},
		},
		{
			name: "domain",
			endpoint: DatagramEndpoint{
				Address: DatagramAddress{Type: AddressTypeDomain, Bytes: []byte("example.test")},
				Port:    443,
			},
			headerTail: []byte{
				0x13, 0x03, 0x0C, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C,
				0x65, 0x2E, 0x74, 0x65, 0x73, 0x74, 0x01, 0xBB,
			},
		},
	}
}

func hevVectorPayloads() [][]byte {
	return [][]byte{
		nil,
		{0x00, 0x7F, 0x80, 0xFE, 0xFF},
		hevPatternedData(int(MaxUDPPayloadRelayHardCeiling)),
	}
}

func hevPatternedData(count int) []byte {
	data := make([]byte, count)
	for index := range data {
		data[index] = byte(index*31 + 7)
	}
	return data
}

// Independent HEV oracle: the header tails above are literal recorded layout
// bytes, and only unsigned network-order MSGLEN is inserted here.
func hevOracle(headerTail, data []byte) []byte {
	wire := make([]byte, 0, 2+len(headerTail)+len(data))
	wire = append(wire, byte(len(data)>>8), byte(len(data)))
	wire = append(wire, headerTail...)
	wire = append(wire, data...)
	return wire
}

func mustDatagramCodec(t testing.TB, maximumPayloadLength uint16) *DatagramCodec {
	t.Helper()
	codec, failure := NewDatagramCodec(maximumPayloadLength)
	if failure != nil {
		t.Fatal(failure)
	}
	return codec
}

func assertDatagramFailure(
	t testing.TB,
	failure *DatagramError,
	code DatagramErrorCode,
	scope string,
	disposition string,
) {
	t.Helper()
	if failure == nil || failure.Code != code || failure.Scope != scope || failure.Disposition != disposition {
		t.Fatalf("failure %#v, want code=%s scope=%s disposition=%s", failure, code, scope, disposition)
	}
}

func assertDatagramEqual(t testing.TB, got, want Datagram) {
	t.Helper()
	if !datagramEndpointsEqual(got.Endpoint, want.Endpoint) || !bytes.Equal(got.Data, want.Data) {
		t.Fatalf("datagram %#v, want %#v", got, want)
	}
}

func datagramEndpointsEqual(got, want DatagramEndpoint) bool {
	return got.Address.Type == want.Address.Type &&
		bytes.Equal(got.Address.Bytes, want.Address.Bytes) &&
		got.Port == want.Port
}
