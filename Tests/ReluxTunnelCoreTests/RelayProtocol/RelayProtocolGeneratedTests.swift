import ReluxTunnelCore
import Testing

/// Drift guard for the generated relay protocol v1 constants.
///
/// The parity test re-derives the canonical fingerprint lines from the typed
/// metadata; the Go side does the same over its own generated file. Both must
/// match the generator-embedded lines byte for byte, so a hand edit to any
/// constant, table, or the embedded fingerprint fails here even before
/// `make relay-protocol-check` compares files.
@Suite("RelayProtocol generated constants")
struct RelayProtocolGeneratedTests {
  private typealias P = RelayProtocolV1

  private func dash(_ value: String) -> String {
    value.isEmpty ? "-" : value
  }

  private func appendBitLines(
    _ lines: inout [String],
    label: String,
    bits: [P.BitAssignment],
    maskLabel: String,
    mask: UInt64
  ) {
    for bit in bits {
      let status = bit.isAllocated ? "allocated" : "reserved"
      lines.append(
        "\(label) bit=\(bit.bit) name=\(bit.name) status=\(status) "
          + "validOnMessage=\(dash(bit.validOnMessage)) "
          + "validDirection=\(dash(bit.validDirection)) "
          + "gatedByFeature=\(dash(bit.gatedByFeature))"
      )
    }
    lines.append("\(maskLabel) value=\(mask)")
  }

  private func renderParityLines() -> [String] {
    var lines: [String] = []
    lines.append(
      "protocol name=\(P.protocolName) wireVersion=\(P.wireVersion) "
        + "byteOrder=\(P.byteOrder) magic=\(P.magicASCII)"
    )
    for (peer, layout) in [("client", P.clientHelloLayout), ("server", P.serverHelloLayout)] {
      for field in layout {
        lines.append(
          "helloField peer=\(peer) name=\(field.name) offset=\(field.byteOffset) "
            + "width=\(field.byteWidth)"
        )
      }
    }
    lines.append("helloWidth client=\(P.clientHelloWidth) server=\(P.serverHelloWidth)")
    for field in P.envelopeLayout {
      lines.append(
        "envelopeField name=\(field.name) offset=\(field.byteOffset) width=\(field.byteWidth)"
      )
    }
    lines.append(
      "envelope prefixWidth=\(P.framePrefixWidth) headerWidth=\(P.envelopeHeaderWidth) "
        + "lengthCoverage=\(P.envelopeLengthCoverage) minFrameLength=\(P.minFrameLength) "
        + "maxLegalFrameBody=\(P.maxLegalFrameBody)"
    )
    for status in P.helloStatusNames {
      lines.append("helloStatus name=\(status.name) value=\(status.value)")
    }
    appendBitLines(
      &lines,
      label: "helloFlagBit",
      bits: P.helloFlagAssignments,
      maskLabel: "helloFlagsReservedMask",
      mask: UInt64(P.helloFlagsReservedMask)
    )
    appendBitLines(
      &lines,
      label: "featureBit",
      bits: P.featureAssignments,
      maskLabel: "featuresReservedMask",
      mask: UInt64(P.featuresReservedMask)
    )
    appendBitLines(
      &lines,
      label: "envelopeFlagBit",
      bits: P.envelopeFlagAssignments,
      maskLabel: "envelopeFlagsReservedMask",
      mask: UInt64(P.envelopeFlagsReservedMask)
    )
    for message in P.messageMetadata {
      lines.append(
        "messageType name=\(message.name) value=\(message.type.rawValue) "
          + "direction=\(message.direction.rawValue) "
          + "association=\(message.associationID.rawValue) "
          + "payload=\(message.payloadShape.rawValue) "
          + "fixedPayloadWidth=\(message.fixedPayloadWidth)"
      )
    }
    for range in P.reservedMessageTypeRanges {
      lines.append(
        "reservedMessageTypeRange first=\(range.first) last=\(range.last) "
          + "purpose=\(range.purpose)"
      )
    }
    for address in P.addressTypeMetadata {
      lines.append(
        "addressType name=\(address.name) value=\(address.type.rawValue) "
          + "lengthPrefixed=\(address.isLengthPrefixed) min=\(address.minAddressBytes) "
          + "max=\(address.maxAddressBytes)"
      )
    }
    for field in P.hevFixedPrefixLayout {
      lines.append(
        "hevField name=\(field.name) offset=\(field.byteOffset) width=\(field.byteWidth)"
      )
    }
    lines.append(
      "hev headerBaseWidth=\(P.hevHeaderBaseWidth) portWidth=\(P.hevPortWidth) "
        + "hdrlenIPv4=\(P.hevHDRLENIPv4) hdrlenIPv6=\(P.hevHDRLENIPv6) "
        + "hdrlenDomainBase=\(P.hevHDRLENDomainBase) "
        + "minDomainWireBytes=\(P.minDomainWireBytes) "
        + "maxDomainWireBytes=\(P.maxDomainWireBytes) "
        + "maxRecordWidth=\(P.maxHEVRecordWidth)"
    )
    for code in P.udpErrorCodeNames {
      lines.append("udpErrorCode name=\(code.name) value=\(code.value)")
    }
    for limit in P.limits {
      lines.append(
        "limit name=\(limit.name) class=\(limit.limitClass.rawValue) "
          + "width=\(limit.byteWidth) unit=\(limit.unit) "
          + "clientDefault=\(limit.clientDefault) relayDefault=\(limit.relayDefault) "
          + "floor=\(limit.floor) clientHardCeiling=\(limit.clientHardCeiling) "
          + "relayHardCeiling=\(limit.relayHardCeiling)"
      )
    }
    return lines
  }

  @Test("parity lines re-derived from typed metadata match the embedded fingerprint")
  func parityLinesMatchTypedMetadata() {
    let derived = renderParityLines()
    #expect(derived.count == P.parityLines.count)
    for (index, (got, want)) in zip(derived, P.parityLines).enumerated() {
      #expect(got == want, "parity line \(index) diverged")
    }
    #expect(P.paritySHA256.count == 64)
    #expect(P.schemaSHA256.count == 64)
  }

  @Test("hello and envelope layouts are contiguous with frozen exact widths")
  func layoutsAreContiguous() {
    for (layout, expectedWidth) in [
      (P.clientHelloLayout, P.clientHelloWidth),
      (P.serverHelloLayout, P.serverHelloWidth),
      (P.envelopeLayout, P.framePrefixWidth + P.envelopeHeaderWidth),
      (P.hevFixedPrefixLayout, P.hevHeaderBaseWidth - P.hevPortWidth),
    ] {
      var offset = 0
      for field in layout {
        #expect(field.byteOffset == offset, "field \(field.name) is not contiguous")
        #expect(field.byteWidth > 0)
        offset += field.byteWidth
      }
      #expect(offset == expectedWidth)
    }
    #expect(P.clientHelloWidth == 12)
    #expect(P.serverHelloWidth == 16)
    #expect(P.minFrameLength == UInt32(P.envelopeHeaderWidth))
    #expect(P.maxLegalFrameBody == 1733)
  }

  @Test("message metadata covers every message type case exactly once")
  func messageMetadataCoversEveryCase() {
    #expect(P.messageMetadata.count == P.MessageType.allCases.count)
    var seen: Set<UInt8> = []
    for message in P.messageMetadata {
      #expect(seen.insert(message.type.rawValue).inserted, "duplicate \(message.name)")
      if message.payloadShape == .fixed {
        #expect(message.fixedPayloadWidth >= 0)
      } else {
        #expect(message.fixedPayloadWidth == -1)
      }
    }
    let byName = Dictionary(
      uniqueKeysWithValues: P.messageMetadata.map { ($0.name, $0) }
    )
    #expect(byName["UDP_ERROR"]?.fixedPayloadWidth == 2)
    #expect(byName["PING"]?.fixedPayloadWidth == 8)
    #expect(byName["PONG"]?.fixedPayloadWidth == byName["PING"]?.fixedPayloadWidth)
    #expect(byName["CLOSE_ASSOCIATION"]?.fixedPayloadWidth == 0)
    #expect(byName["CLOSE_SESSION"]?.fixedPayloadWidth == 0)
  }

  @Test("limit bounds are ordered and fit their declared widths")
  func limitBoundsAreOrdered() {
    #expect(!P.limits.isEmpty)
    for limit in P.limits {
      let widthBound = limit.byteWidth == 8 ? UInt64.max : (UInt64(1) << (limit.byteWidth * 8)) - 1
      for value in [
        limit.clientDefault, limit.relayDefault, limit.floor,
        limit.clientHardCeiling, limit.relayHardCeiling,
      ] {
        #expect(value <= widthBound, "\(limit.name) value \(value) overflows width")
      }
      #expect(limit.floor <= limit.clientDefault)
      #expect(limit.clientDefault <= limit.clientHardCeiling)
      #expect(limit.floor <= limit.relayDefault)
      #expect(limit.relayDefault <= limit.relayHardCeiling)
      if limit.limitClass == .fixedWireConstant {
        #expect(limit.clientDefault == limit.relayDefault)
        #expect(limit.clientDefault == limit.clientHardCeiling)
        #expect(limit.clientDefault == limit.relayHardCeiling)
      }
    }
  }

  @Test("reserved message type ranges exclude every allocated type")
  func reservedRangesExcludeAllocatedTypes() {
    #expect(!P.reservedMessageTypeRanges.isEmpty)
    for range in P.reservedMessageTypeRanges {
      #expect(range.first <= range.last)
      for message in P.messageMetadata {
        let value = message.type.rawValue
        #expect(
          value < range.first || value > range.last,
          "\(message.name) overlaps reserved range"
        )
      }
    }
  }

  @Test("reserved masks exclude exactly the allocated bits")
  func masksExcludeAllocatedBits() {
    let groups: [(bits: [P.BitAssignment], mask: UInt64, widthBits: Int)] = [
      (P.helloFlagAssignments, UInt64(P.helloFlagsReservedMask), 16),
      (P.featureAssignments, UInt64(P.featuresReservedMask), 32),
      (P.envelopeFlagAssignments, UInt64(P.envelopeFlagsReservedMask), 8),
    ]
    for group in groups {
      let fullMask: UInt64 = (UInt64(1) << group.widthBits) - 1
      var allocated: UInt64 = 0
      for bit in group.bits where bit.isAllocated {
        allocated |= UInt64(1) << bit.bit
      }
      #expect(group.mask & allocated == 0)
      #expect(group.mask | allocated == fullMask)
    }
    #expect(UInt64(P.helloFlagDNSPriorityHint) == 1)
    #expect(UInt64(P.featureDNSPriorityHint) == 1)
    #expect(UInt64(P.envelopeFlagDNSPriority) == 1)
  }

  @Test("frozen v1 wire values match the accepted binding and limit decisions")
  func frozenWireSpotValues() {
    #expect(P.magicASCII == "RLXR")
    #expect(P.magic == [0x52, 0x4C, 0x58, 0x52])
    #expect(P.wireVersion == 1)
    #expect(P.byteOrder == "big-endian")
    #expect(P.maxFrameFloor == 2048)
    #expect(P.maxFrameDefault == 4096)
    #expect(P.maxFrameHardCeiling == 65536)
    #expect(P.maxUDPPayload == 1472)
    #expect(P.maxUDPPayloadLocalFloor == 512)
    #expect(P.helloStatusNames.count == 5)
    #expect(P.messageMetadata.count == 6)
    #expect(P.udpErrorCodeNames.count == 10)
    #expect(P.addressTypeMetadata.count == 3)
    #expect(P.limits.count == 8)
    #expect(P.hevHDRLENIPv4 == 10)
    #expect(P.hevHDRLENIPv6 == 22)
    #expect(P.hevHDRLENDomainBase == 7)
    #expect(P.maxDomainWireBytes == 248)
  }
}
