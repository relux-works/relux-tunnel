// Handwritten drift guard for generated_v1.go (TASK-260715-2azda7).
//
// The parity test re-derives the canonical fingerprint lines from the typed
// metadata; the Swift side does the same over its own generated file. Both
// must match the generator-embedded lines byte for byte, so a hand edit to
// any constant, table, or the embedded fingerprint fails here even before
// make relay-protocol-check compares files.
package protocol

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"testing"
)

func orDash(value string) string {
	if value == "" {
		return "-"
	}
	return value
}

func bitStatus(allocated bool) string {
	if allocated {
		return "allocated"
	}
	return "reserved"
}

func appendBitLines(lines []string, label string, bits []BitAssignment, maskLabel string, mask uint64) []string {
	for _, bit := range bits {
		lines = append(lines, fmt.Sprintf(
			"%s bit=%d name=%s status=%s validOnMessage=%s validDirection=%s gatedByFeature=%s",
			label, bit.Bit, bit.Name, bitStatus(bit.IsAllocated),
			orDash(bit.ValidOnMessage), orDash(bit.ValidDirection), orDash(bit.GatedByFeature)))
	}
	return append(lines, fmt.Sprintf("%s value=%d", maskLabel, mask))
}

func renderParityLines() []string {
	lines := []string{fmt.Sprintf(
		"protocol name=%s wireVersion=%d byteOrder=%s magic=%s",
		ProtocolName, WireVersion, ByteOrder, MagicASCII)}
	for _, peer := range []struct {
		name   string
		layout []WireField
	}{{"client", ClientHelloLayout}, {"server", ServerHelloLayout}} {
		for _, field := range peer.layout {
			lines = append(lines, fmt.Sprintf(
				"helloField peer=%s name=%s offset=%d width=%d",
				peer.name, field.Name, field.ByteOffset, field.ByteWidth))
		}
	}
	lines = append(lines, fmt.Sprintf("helloWidth client=%d server=%d", ClientHelloWidth, ServerHelloWidth))
	for _, field := range EnvelopeLayout {
		lines = append(lines, fmt.Sprintf(
			"envelopeField name=%s offset=%d width=%d", field.Name, field.ByteOffset, field.ByteWidth))
	}
	lines = append(lines, fmt.Sprintf(
		"envelope prefixWidth=%d headerWidth=%d lengthCoverage=%s minFrameLength=%d maxLegalFrameBody=%d",
		FramePrefixWidth, EnvelopeHeaderWidth, EnvelopeLengthCoverage, MinFrameLength, MaxLegalFrameBody))
	for _, status := range HelloStatusNames {
		lines = append(lines, fmt.Sprintf("helloStatus name=%s value=%d", status.Name, status.Value))
	}
	lines = appendBitLines(lines, "helloFlagBit", HelloFlagAssignments,
		"helloFlagsReservedMask", uint64(HelloFlagsReservedMask))
	lines = appendBitLines(lines, "featureBit", FeatureAssignments,
		"featuresReservedMask", uint64(FeaturesReservedMask))
	lines = appendBitLines(lines, "envelopeFlagBit", EnvelopeFlagAssignments,
		"envelopeFlagsReservedMask", uint64(EnvelopeFlagsReservedMask))
	for _, message := range MessageMetadataTable {
		lines = append(lines, fmt.Sprintf(
			"messageType name=%s value=%d direction=%s association=%s payload=%s fixedPayloadWidth=%d",
			message.Name, message.Type, message.Direction, message.AssociationID,
			message.PayloadShape, message.FixedPayloadWidth))
	}
	for _, reserved := range ReservedMessageTypeRanges {
		lines = append(lines, fmt.Sprintf(
			"reservedMessageTypeRange first=%d last=%d purpose=%s",
			reserved.First, reserved.Last, reserved.Purpose))
	}
	for _, address := range AddressTypeMetadataTable {
		lines = append(lines, fmt.Sprintf(
			"addressType name=%s value=%d lengthPrefixed=%t min=%d max=%d",
			address.Name, address.Type, address.IsLengthPrefixed,
			address.MinAddressBytes, address.MaxAddressBytes))
	}
	for _, field := range HEVFixedPrefixLayout {
		lines = append(lines, fmt.Sprintf(
			"hevField name=%s offset=%d width=%d", field.Name, field.ByteOffset, field.ByteWidth))
	}
	lines = append(lines, fmt.Sprintf(
		"hev headerBaseWidth=%d portWidth=%d hdrlenIPv4=%d hdrlenIPv6=%d hdrlenDomainBase=%d "+
			"minDomainWireBytes=%d maxDomainWireBytes=%d maxRecordWidth=%d",
		HEVHeaderBaseWidth, HEVPortWidth, HEVHDRLENIPv4, HEVHDRLENIPv6, HEVHDRLENDomainBase,
		MinDomainWireBytes, MaxDomainWireBytes, MaxHEVRecordWidth))
	for _, code := range UDPErrorCodeNames {
		lines = append(lines, fmt.Sprintf("udpErrorCode name=%s value=%d", code.Name, code.Value))
	}
	for _, limit := range Limits {
		lines = append(lines, fmt.Sprintf(
			"limit name=%s class=%s width=%d unit=%s clientDefault=%d relayDefault=%d floor=%d "+
				"clientHardCeiling=%d relayHardCeiling=%d",
			limit.Name, limit.Class, limit.ByteWidth, limit.Unit,
			limit.ClientDefault, limit.RelayDefault, limit.Floor,
			limit.ClientHardCeiling, limit.RelayHardCeiling))
	}
	return lines
}

func TestParityLinesMatchTypedMetadata(t *testing.T) {
	derived := renderParityLines()
	if len(derived) != len(ParityLines) {
		t.Fatalf("derived %d parity lines, embedded %d", len(derived), len(ParityLines))
	}
	for index := range derived {
		if derived[index] != ParityLines[index] {
			t.Errorf("parity line %d diverged:\n got %q\nwant %q", index, derived[index], ParityLines[index])
		}
	}
}

func TestParityDigestMatches(t *testing.T) {
	sum := sha256.Sum256([]byte(strings.Join(ParityLines, "\n") + "\n"))
	if got := hex.EncodeToString(sum[:]); got != ParitySHA256 {
		t.Fatalf("parity digest %s does not match embedded %s", got, ParitySHA256)
	}
	if len(SchemaSHA256) != 64 {
		t.Fatalf("embedded schema digest %q is not a SHA-256 hex string", SchemaSHA256)
	}
}

func TestLayoutsAreContiguous(t *testing.T) {
	cases := []struct {
		name   string
		layout []WireField
		width  int
	}{
		{"clientHello", ClientHelloLayout, ClientHelloWidth},
		{"serverHello", ServerHelloLayout, ServerHelloWidth},
		{"envelope", EnvelopeLayout, FramePrefixWidth + EnvelopeHeaderWidth},
		{"hevFixedPrefix", HEVFixedPrefixLayout, HEVHeaderBaseWidth - HEVPortWidth},
	}
	for _, layout := range cases {
		offset := 0
		for _, field := range layout.layout {
			if field.ByteOffset != offset {
				t.Errorf("%s field %s offset %d, want %d", layout.name, field.Name, field.ByteOffset, offset)
			}
			if field.ByteWidth <= 0 {
				t.Errorf("%s field %s has non-positive width", layout.name, field.Name)
			}
			offset += field.ByteWidth
		}
		if offset != layout.width {
			t.Errorf("%s total width %d, want %d", layout.name, offset, layout.width)
		}
	}
	if ClientHelloWidth != 12 || ServerHelloWidth != 16 {
		t.Errorf("hello widths %d/%d, want frozen 12/16", ClientHelloWidth, ServerHelloWidth)
	}
	if MinFrameLength != uint32(EnvelopeHeaderWidth) {
		t.Errorf("MinFrameLength %d, want envelope header width %d", MinFrameLength, EnvelopeHeaderWidth)
	}
}

func TestMessageMetadataCoversEveryType(t *testing.T) {
	seen := map[MessageType]bool{}
	for _, message := range MessageMetadataTable {
		if seen[message.Type] {
			t.Errorf("duplicate metadata for %s", message.Name)
		}
		seen[message.Type] = true
		if message.PayloadShape == PayloadShapeFixed && message.FixedPayloadWidth < 0 {
			t.Errorf("%s: fixed payload without width", message.Name)
		}
		if message.PayloadShape != PayloadShapeFixed && message.FixedPayloadWidth != -1 {
			t.Errorf("%s: variable payload with fixed width", message.Name)
		}
	}
	if len(MessageMetadataTable) != 6 {
		t.Fatalf("message table has %d entries, want frozen 6", len(MessageMetadataTable))
	}
	byName := map[string]MessageMetadata{}
	for _, message := range MessageMetadataTable {
		byName[message.Name] = message
	}
	if byName["UDP_ERROR"].FixedPayloadWidth != 2 {
		t.Errorf("UDP_ERROR payload width %d, want 2", byName["UDP_ERROR"].FixedPayloadWidth)
	}
	if byName["PING"].FixedPayloadWidth != 8 || byName["PONG"].FixedPayloadWidth != 8 {
		t.Errorf("PING/PONG payload widths must both be 8")
	}
}

func TestLimitBoundsAreOrdered(t *testing.T) {
	if len(Limits) != 8 {
		t.Fatalf("limit table has %d entries, want 8", len(Limits))
	}
	for _, limit := range Limits {
		bound := uint64(1)<<(8*limit.ByteWidth) - 1
		for _, value := range []uint64{
			limit.ClientDefault, limit.RelayDefault, limit.Floor,
			limit.ClientHardCeiling, limit.RelayHardCeiling,
		} {
			if value > bound {
				t.Errorf("%s value %d overflows width %d", limit.Name, value, limit.ByteWidth)
			}
		}
		if limit.Floor > limit.ClientDefault || limit.ClientDefault > limit.ClientHardCeiling {
			t.Errorf("%s client default outside [floor, ceiling]", limit.Name)
		}
		if limit.Floor > limit.RelayDefault || limit.RelayDefault > limit.RelayHardCeiling {
			t.Errorf("%s relay default outside [floor, ceiling]", limit.Name)
		}
		if limit.Class == LimitClassFixedWireConstant {
			if limit.ClientDefault != limit.RelayDefault ||
				limit.ClientDefault != limit.ClientHardCeiling ||
				limit.ClientDefault != limit.RelayHardCeiling {
				t.Errorf("%s: fixed wire constant values diverge", limit.Name)
			}
		}
	}
}

func TestReservedRangesExcludeAllocatedTypes(t *testing.T) {
	if len(ReservedMessageTypeRanges) == 0 {
		t.Fatal("no reserved message type ranges")
	}
	for _, reserved := range ReservedMessageTypeRanges {
		if reserved.First > reserved.Last {
			t.Errorf("reserved range [%d, %d] inverted", reserved.First, reserved.Last)
		}
		for _, message := range MessageMetadataTable {
			value := uint8(message.Type)
			if value >= reserved.First && value <= reserved.Last {
				t.Errorf("%s overlaps reserved range [%d, %d]", message.Name, reserved.First, reserved.Last)
			}
		}
	}
}

func TestMasksExcludeAllocatedBits(t *testing.T) {
	groups := []struct {
		name      string
		bits      []BitAssignment
		mask      uint64
		widthBits uint
	}{
		{"helloFlags", HelloFlagAssignments, uint64(HelloFlagsReservedMask), 16},
		{"features", FeatureAssignments, uint64(FeaturesReservedMask), 32},
		{"envelopeFlags", EnvelopeFlagAssignments, uint64(EnvelopeFlagsReservedMask), 8},
	}
	for _, group := range groups {
		full := uint64(1)<<group.widthBits - 1
		allocated := uint64(0)
		for _, bit := range group.bits {
			if bit.IsAllocated {
				allocated |= uint64(1) << bit.Bit
			}
		}
		if group.mask&allocated != 0 {
			t.Errorf("%s reserved mask includes allocated bits", group.name)
		}
		if group.mask|allocated != full {
			t.Errorf("%s reserved mask plus allocated bits does not cover the field", group.name)
		}
	}
}

func TestFrozenWireSpotValues(t *testing.T) {
	if MagicASCII != "RLXR" || Magic != [4]byte{0x52, 0x4C, 0x58, 0x52} {
		t.Error("magic diverged from frozen RLXR")
	}
	if WireVersion != 1 || ByteOrder != "big-endian" {
		t.Error("protocol identity diverged from frozen v1 big-endian")
	}
	if MaxFrameFloor != 2048 || MaxFrameDefault != 4096 || MaxFrameHardCeiling != 65536 {
		t.Error("maxFrame bounds diverged from TASK-260715-18owh7")
	}
	if MaxUDPPayload != 1472 || MaxUDPPayloadLocalFloor != 512 {
		t.Error("maxUDPPayload constants diverged from TASK-260715-18owh7")
	}
	if MaxLegalFrameBody != 1733 || MaxHEVRecordWidth != 1727 {
		t.Error("derived frame bounds diverged from TASK-260715-18owh7")
	}
	if len(UDPErrorCodeNames) != 10 || len(HelloStatusNames) != 5 || len(AddressTypeMetadataTable) != 3 {
		t.Error("frozen vocabulary sizes diverged")
	}
	if HEVHDRLENIPv4 != 10 || HEVHDRLENIPv6 != 22 || HEVHDRLENDomainBase != 7 || MaxDomainWireBytes != 248 {
		t.Error("HEV header constants diverged from the binding ADR")
	}
}
