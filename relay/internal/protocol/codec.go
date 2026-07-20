package protocol

import (
	"encoding/binary"
	"fmt"
	"math"
)

type EnvelopeDirection string

const (
	EnvelopeClientToRelay EnvelopeDirection = "clientToRelay"
	EnvelopeRelayToClient EnvelopeDirection = "relayToClient"
)

type Envelope struct {
	Type          MessageType
	Flags         uint8
	AssociationID uint32
	Payload       []byte
}

type EnvelopeMetadata struct {
	Type          MessageType
	Flags         uint8
	AssociationID uint32
	PayloadLength int
	Direction     EnvelopeDirection
}

// EnvelopeMetadataValidator admits or rejects bounded, privacy-safe envelope
// metadata. Its error text is never propagated to the wire, logs, or metrics.
type EnvelopeMetadataValidator func(EnvelopeMetadata) error

type CodecErrorCode string

const (
	CodecInvalidConfiguration CodecErrorCode = "invalidConfiguration"
	CodecLengthBelowMinimum   CodecErrorCode = "frameLengthBelowMinimum"
	CodecLengthExceedsMaximum CodecErrorCode = "frameLengthExceedsMaximum"
	CodecArithmeticOverflow   CodecErrorCode = "arithmeticOverflow"
	CodecUnknownMessageType   CodecErrorCode = "unknownMessageType"
	CodecReservedFlags        CodecErrorCode = "reservedFlags"
	CodecInvalidFlags         CodecErrorCode = "invalidFlags"
	CodecInvalidDirection     CodecErrorCode = "invalidDirection"
	CodecInvalidAssociationID CodecErrorCode = "invalidAssociationID"
	CodecInvalidPayloadLength CodecErrorCode = "invalidPayloadLength"
	CodecMetadataRejected     CodecErrorCode = "metadataRejected"
	CodecUnexpectedEOF        CodecErrorCode = "unexpectedEOF"
	CodecCancelled            CodecErrorCode = "cancelled"
	CodecMalformedState       CodecErrorCode = "malformedState"
)

type CodecPhase string

const (
	CodecPhaseConfiguration CodecPhase = "configuration"
	CodecPhaseEncoding      CodecPhase = "encoding"
	CodecPhasePrefix        CodecPhase = "prefix"
	CodecPhaseHeader        CodecPhase = "header"
	CodecPhaseMetadata      CodecPhase = "metadata"
	CodecPhaseBody          CodecPhase = "body"
	CodecPhaseTerminal      CodecPhase = "terminal"
)

type CodecError struct {
	Code        CodecErrorCode
	Phase       CodecPhase
	Scope       string
	Disposition string
}

func (e *CodecError) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf(
		"relayEnvelope code=%s phase=%s scope=%s disposition=%s",
		e.Code, e.Phase, e.Scope, e.Disposition,
	)
}

func codecFailure(code CodecErrorCode, phase CodecPhase) *CodecError {
	return &CodecError{
		Code:        code,
		Phase:       phase,
		Scope:       "session",
		Disposition: "closeSession",
	}
}

type CodecMetrics struct {
	InputBytes        uint64
	OutputBytes       uint64
	OutputFrames      uint64
	RetainedBytes     int
	PeakRetainedBytes int
	BodyAllocations   uint64
	DiscardedBytes    uint64
	Failures          uint64
}

// ValidateEnvelopeFrameLength performs the encoder's arithmetic and cap checks
// without requiring a payload allocation, which also makes overflow testable.
func ValidateEnvelopeFrameLength(payloadLength uint64, maximumFrame uint32) (uint32, *CodecError) {
	if maximumFrame < MinFrameLength || maximumFrame > MaxFrameHardCeiling {
		return 0, codecFailure(CodecInvalidConfiguration, CodecPhaseConfiguration)
	}
	if payloadLength > math.MaxUint32-uint64(EnvelopeHeaderWidth) {
		return 0, codecFailure(CodecArithmeticOverflow, CodecPhaseEncoding)
	}
	length := payloadLength + uint64(EnvelopeHeaderWidth)
	if length > uint64(maximumFrame) {
		return 0, codecFailure(CodecLengthExceedsMaximum, CodecPhaseEncoding)
	}
	return uint32(length), nil
}

type EncodedEnvelope struct {
	header  [FramePrefixWidth + EnvelopeHeaderWidth]byte
	payload []byte
}

// WriteSlices returns a header slice followed by the caller-owned payload.
// A writer can retry an unwritten suffix without copying the payload first.
func (e *EncodedEnvelope) WriteSlices() [][]byte {
	if len(e.payload) == 0 {
		return [][]byte{e.header[:]}
	}
	return [][]byte{e.header[:], e.payload}
}

func (e *EncodedEnvelope) ByteCount() int {
	return len(e.header) + len(e.payload)
}

func (e *EncodedEnvelope) Bytes() []byte {
	result := make([]byte, 0, e.ByteCount())
	result = append(result, e.header[:]...)
	return append(result, e.payload...)
}

type EnvelopeEncoder struct {
	maximumFrame      uint32
	direction         EnvelopeDirection
	negotiatedFeature FeatureSet
	validator         EnvelopeMetadataValidator
	metrics           CodecMetrics
}

func NewEnvelopeEncoder(
	maximumFrame uint32,
	direction EnvelopeDirection,
	negotiatedFeatures FeatureSet,
	validator EnvelopeMetadataValidator,
) (*EnvelopeEncoder, *CodecError) {
	if _, failure := ValidateEnvelopeFrameLength(0, maximumFrame); failure != nil {
		return nil, failure
	}
	if !validEnvelopeDirection(direction) || uint32(negotiatedFeatures)&FeaturesReservedMask != 0 {
		return nil, codecFailure(CodecInvalidConfiguration, CodecPhaseConfiguration)
	}
	return &EnvelopeEncoder{
		maximumFrame:      maximumFrame,
		direction:         direction,
		negotiatedFeature: negotiatedFeatures,
		validator:         validator,
	}, nil
}

func (e *EnvelopeEncoder) Metrics() CodecMetrics {
	return e.metrics
}

func (e *EnvelopeEncoder) Encode(frame Envelope) (*EncodedEnvelope, *CodecError) {
	length, failure := ValidateEnvelopeFrameLength(uint64(len(frame.Payload)), e.maximumFrame)
	if failure != nil {
		e.metrics.Failures++
		return nil, failure
	}
	metadata := EnvelopeMetadata{
		Type:          frame.Type,
		Flags:         frame.Flags,
		AssociationID: frame.AssociationID,
		PayloadLength: len(frame.Payload),
		Direction:     e.direction,
	}
	if failure = validateEnvelopeMetadata(metadata, e.negotiatedFeature, e.validator, CodecPhaseEncoding); failure != nil {
		e.metrics.Failures++
		return nil, failure
	}

	encoded := &EncodedEnvelope{payload: frame.Payload}
	binary.BigEndian.PutUint32(encoded.header[0:FramePrefixWidth], length)
	encoded.header[4] = byte(frame.Type)
	encoded.header[5] = frame.Flags
	binary.BigEndian.PutUint32(encoded.header[6:10], frame.AssociationID)
	e.metrics.OutputFrames++
	e.metrics.OutputBytes += uint64(encoded.ByteCount())
	return encoded, nil
}

type decoderState uint8

const (
	decoderReceiving decoderState = iota
	decoderEnded
	decoderFailed
)

type EnvelopeDecoder struct {
	maximumFrame      uint32
	direction         EnvelopeDirection
	negotiatedFeature FeatureSet
	validator         EnvelopeMetadataValidator
	state             decoderState
	failure           *CodecError
	prefix            [FramePrefixWidth]byte
	prefixLength      int
	body              []byte
	bodyLength        int
	headerValidated   bool
	metrics           CodecMetrics
}

func NewEnvelopeDecoder(
	maximumFrame uint32,
	direction EnvelopeDirection,
	negotiatedFeatures FeatureSet,
	validator EnvelopeMetadataValidator,
) (*EnvelopeDecoder, *CodecError) {
	if _, failure := ValidateEnvelopeFrameLength(0, maximumFrame); failure != nil {
		return nil, failure
	}
	if !validEnvelopeDirection(direction) || uint32(negotiatedFeatures)&FeaturesReservedMask != 0 {
		return nil, codecFailure(CodecInvalidConfiguration, CodecPhaseConfiguration)
	}
	return &EnvelopeDecoder{
		maximumFrame:      maximumFrame,
		direction:         direction,
		negotiatedFeature: negotiatedFeatures,
		validator:         validator,
		state:             decoderReceiving,
	}, nil
}

func (d *EnvelopeDecoder) Metrics() CodecMetrics {
	return d.metrics
}

// AtFrameBoundary reports whether the next byte begins a fresh frame-length
// prefix. Session policy uses it to classify a post-handshake RLXR prefix
// without handshake lookahead or a transport barrier.
func (d *EnvelopeDecoder) AtFrameBoundary() bool {
	return d.state == decoderReceiving && d.prefixLength == 0 && d.body == nil && d.bodyLength == 0
}

func (d *EnvelopeDecoder) Consume(input []byte) ([]Envelope, *CodecError) {
	if d.state == decoderFailed {
		return nil, d.failure
	}
	if d.state == decoderEnded {
		if len(input) == 0 {
			return nil, nil
		}
		d.metrics.InputBytes += uint64(len(input))
		return nil, d.terminal(codecFailure(CodecMalformedState, CodecPhaseTerminal))
	}
	if len(input) == 0 {
		return nil, nil
	}

	d.metrics.InputBytes += uint64(len(input))
	outputBytesBeforeConsume := d.metrics.OutputBytes
	outputFramesBeforeConsume := d.metrics.OutputFrames
	frames := make([]Envelope, 0, 1)
	for _, value := range input {
		if d.body == nil {
			d.prefix[d.prefixLength] = value
			d.prefixLength++
			d.updateRetainedMetrics()
			if d.prefixLength == FramePrefixWidth {
				if failure := d.acceptPrefix(); failure != nil {
					return nil, d.failConsume(failure, outputBytesBeforeConsume, outputFramesBeforeConsume)
				}
			}
			continue
		}

		if d.bodyLength >= len(d.body) {
			return nil, d.failConsume(codecFailure(CodecMalformedState, CodecPhaseBody), outputBytesBeforeConsume, outputFramesBeforeConsume)
		}
		d.body[d.bodyLength] = value
		d.bodyLength++
		d.updateRetainedMetrics()
		if !d.headerValidated && d.bodyLength == EnvelopeHeaderWidth {
			if failure := d.validateCurrentHeader(); failure != nil {
				return nil, d.failConsume(failure, outputBytesBeforeConsume, outputFramesBeforeConsume)
			}
			d.headerValidated = true
		}
		if d.bodyLength == len(d.body) {
			frame, failure := d.finishCurrentFrame()
			if failure != nil {
				return nil, d.failConsume(failure, outputBytesBeforeConsume, outputFramesBeforeConsume)
			}
			frames = append(frames, frame)
		}
	}
	return frames, nil
}

func (d *EnvelopeDecoder) EndOfStream() *CodecError {
	if d.state == decoderFailed {
		return d.failure
	}
	if d.state == decoderEnded {
		return nil
	}
	if d.prefixLength != 0 || d.body != nil || d.bodyLength != 0 {
		return d.terminal(codecFailure(CodecUnexpectedEOF, CodecPhaseTerminal))
	}
	d.state = decoderEnded
	return nil
}

func (d *EnvelopeDecoder) Cancel() *CodecError {
	if d.state == decoderFailed {
		return d.failure
	}
	if d.state == decoderEnded {
		return nil
	}
	return d.terminal(codecFailure(CodecCancelled, CodecPhaseTerminal))
}

func (d *EnvelopeDecoder) Reset() {
	d.state = decoderReceiving
	d.failure = nil
	d.clearScratch()
	d.metrics = CodecMetrics{}
}

func (d *EnvelopeDecoder) acceptPrefix() *CodecError {
	if d.prefixLength != FramePrefixWidth {
		return codecFailure(CodecMalformedState, CodecPhasePrefix)
	}
	length := binary.BigEndian.Uint32(d.prefix[:])
	if length < MinFrameLength {
		return codecFailure(CodecLengthBelowMinimum, CodecPhasePrefix)
	}
	if length > d.maximumFrame {
		return codecFailure(CodecLengthExceedsMaximum, CodecPhasePrefix)
	}
	if uint64(length) > uint64(maxInt()) {
		return codecFailure(CodecArithmeticOverflow, CodecPhasePrefix)
	}
	d.body = make([]byte, int(length))
	d.metrics.BodyAllocations++
	return nil
}

func (d *EnvelopeDecoder) validateCurrentHeader() *CodecError {
	if d.body == nil || d.bodyLength != EnvelopeHeaderWidth || len(d.body) < EnvelopeHeaderWidth {
		return codecFailure(CodecMalformedState, CodecPhaseHeader)
	}
	typeValue := MessageType(d.body[0])
	if _, ok := messageMetadata(typeValue); !ok {
		return codecFailure(CodecUnknownMessageType, CodecPhaseHeader)
	}
	metadata := EnvelopeMetadata{
		Type:          typeValue,
		Flags:         d.body[1],
		AssociationID: binary.BigEndian.Uint32(d.body[2:6]),
		PayloadLength: len(d.body) - EnvelopeHeaderWidth,
		Direction:     d.direction,
	}
	return validateEnvelopeMetadata(
		metadata,
		d.negotiatedFeature,
		d.validator,
		CodecPhaseHeader,
	)
}

func (d *EnvelopeDecoder) finishCurrentFrame() (Envelope, *CodecError) {
	if d.body == nil || d.bodyLength != len(d.body) || !d.headerValidated {
		return Envelope{}, codecFailure(CodecMalformedState, CodecPhaseBody)
	}
	frameBody := d.body
	frame := Envelope{
		Type:          MessageType(frameBody[0]),
		Flags:         frameBody[1],
		AssociationID: binary.BigEndian.Uint32(frameBody[2:6]),
		Payload:       frameBody[EnvelopeHeaderWidth:],
	}
	d.metrics.OutputFrames++
	d.metrics.OutputBytes += uint64(FramePrefixWidth + len(frameBody))
	d.clearScratch()
	d.updateRetainedMetrics()
	return frame, nil
}

func (d *EnvelopeDecoder) terminal(failure *CodecError) *CodecError {
	d.state = decoderFailed
	d.failure = failure
	d.clearScratch()
	d.metrics.RetainedBytes = 0
	d.metrics.DiscardedBytes = d.metrics.InputBytes - d.metrics.OutputBytes
	d.metrics.Failures++
	return failure
}

func (d *EnvelopeDecoder) failConsume(
	failure *CodecError,
	outputBytesBeforeConsume uint64,
	outputFramesBeforeConsume uint64,
) *CodecError {
	d.metrics.OutputBytes = outputBytesBeforeConsume
	d.metrics.OutputFrames = outputFramesBeforeConsume
	return d.terminal(failure)
}

func (d *EnvelopeDecoder) clearScratch() {
	d.prefix = [FramePrefixWidth]byte{}
	d.prefixLength = 0
	d.body = nil
	d.bodyLength = 0
	d.headerValidated = false
}

func (d *EnvelopeDecoder) updateRetainedMetrics() {
	d.metrics.RetainedBytes = d.prefixLength + d.bodyLength
	if d.metrics.RetainedBytes > d.metrics.PeakRetainedBytes {
		d.metrics.PeakRetainedBytes = d.metrics.RetainedBytes
	}
}

func validateEnvelopeMetadata(
	metadata EnvelopeMetadata,
	negotiatedFeatures FeatureSet,
	validator EnvelopeMetadataValidator,
	phase CodecPhase,
) *CodecError {
	if metadata.Flags&EnvelopeFlagsReservedMask != 0 {
		return codecFailure(CodecReservedFlags, phase)
	}
	if metadata.Flags != 0 && (metadata.Flags != EnvelopeFlagDNSPriority ||
		metadata.Type != MessageTypeUDPDatagram ||
		metadata.Direction != EnvelopeClientToRelay ||
		negotiatedFeatures&FeatureSetDNSPriorityHint == 0) {
		return codecFailure(CodecInvalidFlags, phase)
	}
	generated, ok := messageMetadata(metadata.Type)
	if !ok {
		return codecFailure(CodecUnknownMessageType, phase)
	}
	if generated.Direction == MessageDirectionClientToRelay && metadata.Direction != EnvelopeClientToRelay ||
		generated.Direction == MessageDirectionRelayToClient && metadata.Direction != EnvelopeRelayToClient {
		return codecFailure(CodecInvalidDirection, phase)
	}
	if generated.AssociationID == AssociationIDRuleZero && metadata.AssociationID != 0 ||
		generated.AssociationID == AssociationIDRuleNonzero && metadata.AssociationID == 0 {
		return codecFailure(CodecInvalidAssociationID, phase)
	}
	if generated.PayloadShape == PayloadShapeFixed && metadata.PayloadLength != generated.FixedPayloadWidth {
		return codecFailure(CodecInvalidPayloadLength, phase)
	}
	if validator != nil {
		if err := validator(metadata); err != nil {
			return codecFailure(CodecMetadataRejected, CodecPhaseMetadata)
		}
	}
	return nil
}

func messageMetadata(messageType MessageType) (MessageMetadata, bool) {
	for _, metadata := range MessageMetadataTable {
		if metadata.Type == messageType {
			return metadata, true
		}
	}
	return MessageMetadata{}, false
}

func validEnvelopeDirection(direction EnvelopeDirection) bool {
	return direction == EnvelopeClientToRelay || direction == EnvelopeRelayToClient
}

func maxInt() int {
	return int(^uint(0) >> 1)
}

// DatagramAddress is a byte-preserving SOCKS/HEV address. Domain bytes are
// opaque here; DNS presentation-form validation belongs to the resolver gate.
type DatagramAddress struct {
	Type  AddressType
	Bytes []byte
}

// DatagramEndpoint is the destination on client requests and the
// relay-observed source on responses. The codec never resolves or substitutes
// an endpoint.
type DatagramEndpoint struct {
	Address DatagramAddress
	Port    uint16
}

type Datagram struct {
	Endpoint DatagramEndpoint
	Data     []byte
}

type DatagramErrorCode string

const (
	DatagramInvalidConfiguration              DatagramErrorCode = "invalidConfiguration"
	DatagramArithmeticOverflow                DatagramErrorCode = "arithmeticOverflow"
	DatagramTruncatedFixedHeader              DatagramErrorCode = "truncatedFixedHeader"
	DatagramUnknownAddressType                DatagramErrorCode = "unknownAddressType"
	DatagramInvalidAddressLength              DatagramErrorCode = "invalidAddressLength"
	DatagramHeaderLengthMismatch              DatagramErrorCode = "headerLengthMismatch"
	DatagramTruncatedAddress                  DatagramErrorCode = "truncatedAddress"
	DatagramTruncatedPort                     DatagramErrorCode = "truncatedPort"
	DatagramInvalidPort                       DatagramErrorCode = "invalidPort"
	DatagramMessageLengthExceedsProtocolLimit DatagramErrorCode = "messageLengthExceedsProtocolMaximum"
	DatagramMessageLengthExceedsLocalLimit    DatagramErrorCode = "messageLengthExceedsLocalMaximum"
	DatagramMessageLengthMismatch             DatagramErrorCode = "messageLengthMismatch"
	DatagramOuterLengthMismatch               DatagramErrorCode = "outerLengthMismatch"
)

type DatagramPhase string

const (
	DatagramPhaseConfiguration DatagramPhase = "configuration"
	DatagramPhaseEncoding      DatagramPhase = "encoding"
	DatagramPhaseFixedHeader   DatagramPhase = "fixedHeader"
	DatagramPhaseAddress       DatagramPhase = "address"
	DatagramPhasePort          DatagramPhase = "port"
	DatagramPhaseData          DatagramPhase = "data"
	DatagramPhaseOuterLength   DatagramPhase = "outerLength"
)

type DatagramError struct {
	Code        DatagramErrorCode
	Phase       DatagramPhase
	Scope       string
	Disposition string
}

func (e *DatagramError) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf(
		"relayDatagram code=%s phase=%s scope=%s disposition=%s",
		e.Code, e.Phase, e.Scope, e.Disposition,
	)
}

type DatagramCodecMetrics struct {
	InputRecords             uint64
	InputBytes               uint64
	DecodedRecords           uint64
	EncodedRecords           uint64
	EncodedBytes             uint64
	DecodedMaterializedBytes uint64
	Failures                 uint64
}

type DatagramCodec struct {
	maximumPayloadLength uint16
	metrics              DatagramCodecMetrics
}

func NewDatagramCodec(maximumPayloadLength uint16) (*DatagramCodec, *DatagramError) {
	if failure := validateDatagramMaximumPayloadLength(maximumPayloadLength); failure != nil {
		return nil, failure
	}
	return &DatagramCodec{maximumPayloadLength: maximumPayloadLength}, nil
}

func (c *DatagramCodec) MaximumPayloadLength() uint16 {
	return c.maximumPayloadLength
}

func (c *DatagramCodec) Metrics() DatagramCodecMetrics {
	return c.metrics
}

// ValidateDatagramEncodedLength computes and validates the exact HEV record
// size before allocating an output buffer.
func ValidateDatagramEncodedLength(
	endpoint DatagramEndpoint,
	dataLength uint64,
	maximumPayloadLength uint16,
) (int, *DatagramError) {
	if failure := validateDatagramMaximumPayloadLength(maximumPayloadLength); failure != nil {
		return 0, failure
	}
	headerLength, failure := validateDatagramEndpoint(endpoint, DatagramPhaseEncoding)
	if failure != nil {
		return 0, failure
	}
	if dataLength > ^uint64(0)-uint64(headerLength) ||
		dataLength+uint64(headerLength) > uint64(maxInt()) {
		return 0, datagramEncodingFailure(DatagramArithmeticOverflow, DatagramPhaseEncoding)
	}
	if dataLength > uint64(MaxUDPPayloadRelayHardCeiling) {
		return 0, datagramEncodingFailure(
			DatagramMessageLengthExceedsProtocolLimit,
			DatagramPhaseData,
		)
	}
	if dataLength > uint64(maximumPayloadLength) {
		return 0, datagramEncodingFailure(
			DatagramMessageLengthExceedsLocalLimit,
			DatagramPhaseData,
		)
	}
	recordLength := dataLength + uint64(headerLength)
	if recordLength > uint64(MaxHEVRecordWidth) {
		return 0, datagramEncodingFailure(DatagramArithmeticOverflow, DatagramPhaseEncoding)
	}
	return int(recordLength), nil
}

func (c *DatagramCodec) Encode(datagram Datagram) ([]byte, *DatagramError) {
	recordLength, failure := ValidateDatagramEncodedLength(
		datagram.Endpoint,
		uint64(len(datagram.Data)),
		c.maximumPayloadLength,
	)
	if failure != nil {
		c.metrics.Failures++
		return nil, failure
	}
	headerLength := recordLength - len(datagram.Data)
	record := make([]byte, recordLength)
	binary.BigEndian.PutUint16(record[0:2], uint16(len(datagram.Data)))
	record[2] = byte(headerLength)
	record[3] = byte(datagram.Endpoint.Address.Type)

	addressOffset := 4
	if datagram.Endpoint.Address.Type == AddressTypeDomain {
		record[4] = byte(len(datagram.Endpoint.Address.Bytes))
		addressOffset++
	}
	addressEnd := addressOffset + len(datagram.Endpoint.Address.Bytes)
	copy(record[addressOffset:addressEnd], datagram.Endpoint.Address.Bytes)
	binary.BigEndian.PutUint16(record[addressEnd:addressEnd+HEVPortWidth], datagram.Endpoint.Port)
	copy(record[headerLength:], datagram.Data)

	c.metrics.EncodedRecords++
	c.metrics.EncodedBytes += uint64(len(record))
	return record, nil
}

// Decode validates one complete envelope payload. It validates HEV structure
// before payload-limit policy and finishes every check before slicing or
// allocating decoded bytes.
func (c *DatagramCodec) Decode(record []byte) (Datagram, *DatagramError) {
	c.metrics.InputRecords++
	c.metrics.InputBytes += uint64(len(record))
	layout, failure := c.validateDatagramRecordLayout(record)
	if failure != nil {
		c.metrics.Failures++
		return Datagram{}, failure
	}

	addressBytes := append([]byte(nil), record[layout.addressOffset:layout.addressEnd]...)
	data := append([]byte(nil), record[layout.headerLength:]...)
	result := Datagram{
		Endpoint: DatagramEndpoint{
			Address: DatagramAddress{Type: layout.addressType, Bytes: addressBytes},
			Port:    layout.port,
		},
		Data: data,
	}
	c.metrics.DecodedRecords++
	c.metrics.DecodedMaterializedBytes += uint64(len(addressBytes) + len(data))
	return result, nil
}

type datagramRecordLayout struct {
	addressType   AddressType
	addressOffset int
	addressEnd    int
	headerLength  int
	port          uint16
}

func (c *DatagramCodec) validateDatagramRecordLayout(record []byte) (datagramRecordLayout, *DatagramError) {
	if len(record) < 4 {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramTruncatedFixedHeader,
			DatagramPhaseFixedHeader,
		)
	}
	messageLength := int(binary.BigEndian.Uint16(record[0:2]))
	headerLength := int(record[2])
	addressType := AddressType(record[3])
	if addressType != AddressTypeIPv4 && addressType != AddressTypeIPv6 && addressType != AddressTypeDomain {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramUnknownAddressType,
			DatagramPhaseAddress,
		)
	}
	addressOffset := 4
	addressLength := 0
	expectedHeaderLength := 0
	switch addressType {
	case AddressTypeIPv4:
		addressLength = 4
		expectedHeaderLength = HEVHDRLENIPv4
	case AddressTypeIPv6:
		addressLength = 16
		expectedHeaderLength = HEVHDRLENIPv6
	case AddressTypeDomain:
		if len(record) < 5 {
			return datagramRecordLayout{}, datagramDecodingFailure(
				DatagramTruncatedAddress,
				DatagramPhaseAddress,
			)
		}
		addressOffset = 5
		addressLength = int(record[4])
		if addressLength < MinDomainWireBytes || addressLength > MaxDomainWireBytes {
			return datagramRecordLayout{}, datagramDecodingFailure(
				DatagramInvalidAddressLength,
				DatagramPhaseAddress,
			)
		}
		expectedHeaderLength = HEVHDRLENDomainBase + addressLength
	}
	if headerLength != expectedHeaderLength {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramHeaderLengthMismatch,
			DatagramPhaseFixedHeader,
		)
	}
	addressEnd := addressOffset + addressLength
	if len(record) < addressEnd {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramTruncatedAddress,
			DatagramPhaseAddress,
		)
	}
	portEnd := addressEnd + HEVPortWidth
	if len(record) < portEnd {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramTruncatedPort,
			DatagramPhasePort,
		)
	}
	if portEnd != headerLength {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramHeaderLengthMismatch,
			DatagramPhaseFixedHeader,
		)
	}
	port := binary.BigEndian.Uint16(record[addressEnd:portEnd])
	if port == 0 {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramInvalidPort,
			DatagramPhasePort,
		)
	}
	availableDataLength := len(record) - headerLength
	if availableDataLength != messageLength {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramMessageLengthMismatch,
			DatagramPhaseData,
		)
	}
	if messageLength > maxInt()-headerLength {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramArithmeticOverflow,
			DatagramPhaseOuterLength,
		)
	}
	if headerLength+messageLength != len(record) {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramOuterLengthMismatch,
			DatagramPhaseOuterLength,
		)
	}
	if messageLength > int(MaxUDPPayloadRelayHardCeiling) {
		return datagramRecordLayout{}, datagramDecodingFailure(
			DatagramMessageLengthExceedsProtocolLimit,
			DatagramPhaseData,
		)
	}
	if messageLength > int(c.maximumPayloadLength) {
		return datagramRecordLayout{}, datagramLocalLimitFailure()
	}
	return datagramRecordLayout{
		addressType:   addressType,
		addressOffset: addressOffset,
		addressEnd:    addressEnd,
		headerLength:  headerLength,
		port:          port,
	}, nil
}

func validateDatagramMaximumPayloadLength(value uint16) *DatagramError {
	if value < MaxUDPPayloadFloor || value > MaxUDPPayloadRelayHardCeiling {
		return &DatagramError{
			Code:        DatagramInvalidConfiguration,
			Phase:       DatagramPhaseConfiguration,
			Scope:       "session",
			Disposition: "closeSession",
		}
	}
	return nil
}

func validateDatagramEndpoint(endpoint DatagramEndpoint, phase DatagramPhase) (int, *DatagramError) {
	if endpoint.Port == 0 {
		return 0, datagramEncodingFailure(DatagramInvalidPort, DatagramPhasePort)
	}
	switch endpoint.Address.Type {
	case AddressTypeIPv4:
		if len(endpoint.Address.Bytes) != 4 {
			return 0, datagramEncodingFailure(DatagramInvalidAddressLength, phase)
		}
		return HEVHDRLENIPv4, nil
	case AddressTypeIPv6:
		if len(endpoint.Address.Bytes) != 16 {
			return 0, datagramEncodingFailure(DatagramInvalidAddressLength, phase)
		}
		return HEVHDRLENIPv6, nil
	case AddressTypeDomain:
		if len(endpoint.Address.Bytes) < MinDomainWireBytes ||
			len(endpoint.Address.Bytes) > MaxDomainWireBytes {
			return 0, datagramEncodingFailure(DatagramInvalidAddressLength, phase)
		}
		return HEVHDRLENDomainBase + len(endpoint.Address.Bytes), nil
	default:
		return 0, datagramEncodingFailure(DatagramUnknownAddressType, phase)
	}
}

func datagramEncodingFailure(code DatagramErrorCode, phase DatagramPhase) *DatagramError {
	return &DatagramError{
		Code:        code,
		Phase:       phase,
		Scope:       "association",
		Disposition: "rejectDatagram",
	}
}

func datagramDecodingFailure(code DatagramErrorCode, phase DatagramPhase) *DatagramError {
	return &DatagramError{
		Code:        code,
		Phase:       phase,
		Scope:       "association",
		Disposition: "closeAssociation",
	}
}

func datagramLocalLimitFailure() *DatagramError {
	return &DatagramError{
		Code:        DatagramMessageLengthExceedsLocalLimit,
		Phase:       DatagramPhaseData,
		Scope:       "association",
		Disposition: "rejectDatagram",
	}
}
