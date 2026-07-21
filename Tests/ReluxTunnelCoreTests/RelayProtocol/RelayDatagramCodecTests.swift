import Foundation
import ReluxTunnelCore
import Testing

@Suite("RelayProtocol v1 HEV datagram codec")
struct RelayProtocolDatagramCodecTests {
  private typealias P = RelayProtocolV1

  @Test("HEV IPv4, IPv6, and domain vectors are byte exact at zero, typical, and maximum DATA")
  func exactHEVVectors() throws {
    for endpoint in vectorEndpoints() {
      for data in vectorPayloads() {
        let datagram = RelayDatagram(endpoint: endpoint.endpoint, data: data)
        let expected = hevOracle(headerTail: endpoint.headerTail, data: data)
        var codec = try RelayDatagramCodec()

        let encoded = try codec.encode(datagram)
        #expect(encoded == expected, "\(endpoint.name), DATA=\(data.count)")
        #expect(try codec.decode(encoded) == datagram)
        #expect(encoded.count == endpoint.headerTail.count + 2 + data.count)
      }
    }
  }

  @Test("every permitted DATA size round-trips for every address form")
  func everyPermittedDataSize() throws {
    for endpoint in vectorEndpoints() {
      var codec = try RelayDatagramCodec()
      for length in 0...Int(P.maxUDPPayloadClientHardCeiling) {
        let data = patternedData(count: length)
        let datagram = RelayDatagram(endpoint: endpoint.endpoint, data: data)
        let encoded = try codec.encode(datagram)
        #expect(encoded == hevOracle(headerTail: endpoint.headerTail, data: data))
        #expect(try codec.decode(encoded) == datagram)
        #expect(encoded.count <= P.maxHEVRecordWidth)
      }
    }
  }

  @Test("maximum domain and DATA lengths produce the generated maximum record width")
  func maximumRecordWidth() throws {
    let domain = Data((0..<P.maxDomainWireBytes).map { UInt8(truncatingIfNeeded: $0) })
    let datagram = RelayDatagram(
      endpoint: RelayDatagramEndpoint(address: .domain(domain), port: UInt16.max),
      data: patternedData(count: Int(P.maxUDPPayloadClientHardCeiling))
    )
    var codec = try RelayDatagramCodec()

    let encoded = try codec.encode(datagram)
    #expect(encoded.count == P.maxHEVRecordWidth)
    #expect(encoded.byte(at: 2) == UInt8.max)
    #expect(encoded.byte(at: 4) == UInt8(P.maxDomainWireBytes))
    #expect(try codec.decode(encoded) == datagram)
  }

  @Test("domain bytes are opaque and preserved without IDNA or DNS normalization")
  func opaqueDomainPolicy() throws {
    let rawDomain = Data([0x00, 0x2E, 0x7F, 0x80, 0xFF])
    let datagram = RelayDatagram(
      endpoint: RelayDatagramEndpoint(address: .domain(rawDomain), port: 5353),
      data: Data([0x00, 0xFF])
    )
    var codec = try RelayDatagramCodec()

    let encoded = try codec.encode(datagram)
    #expect(Array(encoded.prefix(5)) == [0x00, 0x02, 0x0C, 0x03, 0x05])
    #expect(try codec.decode(encoded) == datagram)
  }

  @Test("response encoding preserves the relay-observed source endpoint")
  func responseSourceEndpointIsPreserved() throws {
    let originalDestination = RelayDatagramEndpoint(
      address: .ipv4(Data([192, 0, 2, 44])),
      port: 443
    )
    let observedSource = RelayDatagramEndpoint(
      address: .ipv6(
        Data([0x20, 0x01, 0x0D, 0xB8] + Array(repeating: 0, count: 11) + [0x2A])
      ),
      port: 8443
    )
    #expect(originalDestination != observedSource)
    var codec = try RelayDatagramCodec()

    let wire = try codec.encode(
      RelayDatagram(endpoint: observedSource, data: Data([0xCA, 0xFE]))
    )
    let decoded = try codec.decode(wire)
    #expect(decoded.endpoint == observedSource)
    #expect(decoded.endpoint != originalDestination)
  }

  @Test("malformed inner lengths, address forms, and ports fail before materialization")
  func malformedRecords() throws {
    let cases: [(String, Data, RelayDatagramFailureCode)] = [
      ("empty", Data(), .truncatedFixedHeader),
      ("short MSGLEN", Data([0x00]), .truncatedFixedHeader),
      ("short HDRLEN", Data([0x00, 0x00]), .truncatedFixedHeader),
      ("short ATYP", Data([0x00, 0x00, 0x0A]), .truncatedFixedHeader),
      ("unknown ATYP", Data([0x00, 0x00, 0x0A, 0xFF]), .unknownAddressType),
      ("domain length missing", Data([0x00, 0x00, 0x07, 0x03]), .truncatedAddress),
      (
        "empty domain",
        Data([0x00, 0x00, 0x07, 0x03, 0x00, 0x00, 0x35]),
        .invalidAddressLength
      ),
      (
        "domain too long",
        Data([0x00, 0x00, 0xFF, 0x03, 0xF9]),
        .invalidAddressLength
      ),
      (
        "wrong IPv4 HDRLEN",
        Data([0x00, 0x00, 0x09, 0x01, 192, 0, 2, 1, 0, 53]),
        .headerLengthMismatch
      ),
      ("truncated IPv4", Data([0x00, 0x00, 0x0A, 0x01, 192]), .truncatedAddress),
      (
        "truncated port",
        Data([0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0]),
        .truncatedPort
      ),
      (
        "zero port",
        Data([0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0, 0]),
        .invalidPort
      ),
      (
        "protocol-sized declaration with truncated DATA",
        Data([0x05, 0xC1, 0x0A, 0x01, 192, 0, 2, 1, 0, 53]),
        .messageLengthMismatch
      ),
      (
        "inner length exceeds outer",
        Data([0x00, 0x01, 0x0A, 0x01, 192, 0, 2, 1, 0, 53]),
        .messageLengthMismatch
      ),
      (
        "outer length exceeds inner",
        Data([0x00, 0x00, 0x0A, 0x01, 192, 0, 2, 1, 0, 53, 0xAA]),
        .messageLengthMismatch
      ),
    ]

    for (name, record, code) in cases {
      var codec = try RelayDatagramCodec()
      expectFailure(code, scope: .association, disposition: .closeAssociation) {
        _ = try codec.decode(record)
      }
      #expect(codec.metrics.decodedMaterializedBytes == 0, "\(name)")
      #expect(codec.metrics.decodedRecords == 0, "\(name)")
      #expect(codec.metrics.failures == 1, "\(name)")
    }
  }

  @Test("bounded HEV header validation does not require declared DATA bytes")
  func boundedHeaderValidation() throws {
    let complete = hevOracle(
      headerTail: vectorEndpoints()[2].headerTail,
      data: patternedData(count: Int(P.maxUDPPayloadClientHardCeiling) + 1)
    )
    let headerLength = Int(complete.byte(at: 2))
    let header = Data(complete.prefix(headerLength))
    try RelayDatagramWire.validateHeader(header)

    var zeroPort = header
    zeroPort[zeroPort.index(before: zeroPort.endIndex)] = 0
    zeroPort[zeroPort.index(zeroPort.endIndex, offsetBy: -2)] = 0
    expectFailure(.invalidPort, scope: .association, disposition: .closeAssociation) {
      try RelayDatagramWire.validateHeader(zeroPort)
    }
  }

  @Test("HEV structure is validated before local and protocol DATA limits")
  func structuralValidationPrecedesPayloadLimits() throws {
    let limitCases: [(String, UInt16, UInt16)] = [
      ("lowered local cap", P.maxUDPPayloadFloor, P.maxUDPPayloadFloor + 1),
      (
        "protocol ceiling",
        P.maxUDPPayloadClientDefault,
        P.maxUDPPayloadClientHardCeiling + 1
      ),
    ]

    for (limitName, maximumPayloadLength, declaredMessageLength) in limitCases {
      for malformed in malformedStructuralRecords(messageLength: declaredMessageLength) {
        var codec = try RelayDatagramCodec(maximumPayloadLength: maximumPayloadLength)
        expectFailure(
          malformed.code,
          scope: .association,
          disposition: .closeAssociation
        ) {
          _ = try codec.decode(malformed.record)
        }
        #expect(
          codec.metrics.decodedMaterializedBytes == 0,
          "\(limitName): \(malformed.name)"
        )
        #expect(codec.metrics.decodedRecords == 0, "\(limitName): \(malformed.name)")
        #expect(codec.metrics.failures == 1, "\(limitName): \(malformed.name)")
      }
    }

    let protocolOversizedData = patternedData(
      count: Int(P.maxUDPPayloadClientHardCeiling) + 1
    )
    let structurallyValidRecord = hevOracle(
      headerTail: vectorEndpoints()[0].headerTail,
      data: protocolOversizedData
    )
    var codec = try RelayDatagramCodec()
    expectFailure(
      .messageLengthExceedsProtocolMaximum,
      scope: .association,
      disposition: .closeAssociation
    ) {
      _ = try codec.decode(structurallyValidRecord)
    }
    #expect(codec.metrics.decodedMaterializedBytes == 0)
  }

  @Test("a valid wire record over a lowered local cap is dropped without materialization")
  func localCapDisposition() throws {
    let data = patternedData(count: Int(P.maxUDPPayloadFloor) + 1)
    let record = hevOracle(headerTail: vectorEndpoints()[0].headerTail, data: data)
    var codec = try RelayDatagramCodec(maximumPayloadLength: P.maxUDPPayloadFloor)

    expectFailure(
      .messageLengthExceedsLocalMaximum,
      scope: .association,
      disposition: .rejectDatagram
    ) {
      _ = try codec.decode(record)
    }
    #expect(codec.metrics.decodedMaterializedBytes == 0)
  }

  @Test("encoder size arithmetic and endpoint validation are bounded and typed")
  func encoderFailures() throws {
    let valid = RelayDatagramEndpoint(address: .ipv4(Data([192, 0, 2, 1])), port: 53)
    expectFailure(.arithmeticOverflow, scope: .association, disposition: .rejectDatagram) {
      _ = try RelayDatagramWire.encodedLength(endpoint: valid, dataLength: UInt64.max)
    }
    expectFailure(
      .messageLengthExceedsProtocolMaximum,
      scope: .association,
      disposition: .rejectDatagram
    ) {
      _ = try RelayDatagramWire.encodedLength(
        endpoint: valid,
        dataLength: UInt64(P.maxUDPPayloadClientHardCeiling) + 1
      )
    }
    expectFailure(
      .messageLengthExceedsLocalMaximum,
      scope: .association,
      disposition: .rejectDatagram
    ) {
      _ = try RelayDatagramWire.encodedLength(
        endpoint: valid,
        dataLength: UInt64(P.maxUDPPayloadFloor) + 1,
        maximumPayloadLength: P.maxUDPPayloadFloor
      )
    }

    let invalidEndpoints: [(RelayDatagramEndpoint, RelayDatagramFailureCode)] = [
      (RelayDatagramEndpoint(address: .ipv4(Data([192, 0, 2])), port: 53), .invalidAddressLength),
      (
        RelayDatagramEndpoint(address: .ipv6(Data(repeating: 0, count: 15)), port: 53),
        .invalidAddressLength
      ),
      (RelayDatagramEndpoint(address: .domain(Data()), port: 53), .invalidAddressLength),
      (
        RelayDatagramEndpoint(address: .domain(Data(repeating: 0x61, count: 249)), port: 53),
        .invalidAddressLength
      ),
      (RelayDatagramEndpoint(address: .ipv4(Data([192, 0, 2, 1])), port: 0), .invalidPort),
    ]
    for (endpoint, code) in invalidEndpoints {
      expectFailure(code, scope: .association, disposition: .rejectDatagram) {
        _ = try RelayDatagramWire.encodedLength(endpoint: endpoint, dataLength: 0)
      }
    }
  }

  @Test("invalid codec limits are session-fatal configuration errors")
  func configurationFailures() {
    expectFailure(.invalidConfiguration, scope: .session, disposition: .closeSession) {
      _ = try RelayDatagramCodec(maximumPayloadLength: P.maxUDPPayloadFloor - 1)
    }
    expectFailure(.invalidConfiguration, scope: .session, disposition: .closeSession) {
      _ = try RelayDatagramCodec(
        maximumPayloadLength: P.maxUDPPayloadClientHardCeiling + 1
      )
    }
  }

  @Test("failure diagnostics contain only finite protocol metadata")
  func privacySafeDiagnostics() throws {
    var codec = try RelayDatagramCodec()
    do {
      _ = try codec.decode(Data([0x00, 0x00, 0x07, 0x03, 0x00]))
      Issue.record("expected failure")
    } catch let failure as RelayDatagramFailure {
      #expect(
        failure.description
          == "relayDatagram code=invalidAddressLength phase=address "
          + "scope=association disposition=closeAssociation"
      )
      #expect(!failure.description.contains("domain"))
      #expect(!failure.description.contains("payload"))
      #expect(!failure.description.contains("192.0.2"))
    } catch {
      Issue.record("unexpected error type")
    }
  }
}

private struct HEVVectorEndpoint {
  let name: String
  let endpoint: RelayDatagramEndpoint
  /// Literal bytes from HDRLEN through DST.PORT under the pinned HEV layout.
  let headerTail: [UInt8]
}

private struct MalformedStructuralRecord {
  let name: String
  let record: Data
  let code: RelayDatagramFailureCode
}

private func malformedStructuralRecords(messageLength: UInt16) -> [MalformedStructuralRecord] {
  let high = UInt8(truncatingIfNeeded: messageLength >> 8)
  let low = UInt8(truncatingIfNeeded: messageLength)
  return [
    MalformedStructuralRecord(
      name: "unknown ATYP",
      record: Data([high, low, 0x0A, 0xFF]),
      code: .unknownAddressType
    ),
    MalformedStructuralRecord(
      name: "wrong IPv4 HDRLEN",
      record: Data([high, low, 0x09, 0x01, 192, 0, 2, 1, 0, 53]),
      code: .headerLengthMismatch
    ),
    MalformedStructuralRecord(
      name: "truncated IPv4 address",
      record: Data([high, low, 0x0A, 0x01, 192]),
      code: .truncatedAddress
    ),
    MalformedStructuralRecord(
      name: "truncated port",
      record: Data([high, low, 0x0A, 0x01, 192, 0, 2, 1, 0]),
      code: .truncatedPort
    ),
    MalformedStructuralRecord(
      name: "zero port",
      record: Data([high, low, 0x0A, 0x01, 192, 0, 2, 1, 0, 0]),
      code: .invalidPort
    ),
    MalformedStructuralRecord(
      name: "outer length mismatch",
      record: Data([high, low, 0x0A, 0x01, 192, 0, 2, 1, 0, 53]),
      code: .messageLengthMismatch
    ),
  ]
}

private func vectorEndpoints() -> [HEVVectorEndpoint] {
  [
    HEVVectorEndpoint(
      name: "IPv4",
      endpoint: RelayDatagramEndpoint(address: .ipv4(Data([192, 0, 2, 1])), port: 0x2035),
      headerTail: [0x0A, 0x01, 0xC0, 0x00, 0x02, 0x01, 0x20, 0x35]
    ),
    HEVVectorEndpoint(
      name: "IPv6",
      endpoint: RelayDatagramEndpoint(
        address: .ipv6(
          Data([0x20, 0x01, 0x0D, 0xB8] + Array(repeating: 0, count: 11) + [0x01])
        ),
        port: 0xBEEF
      ),
      headerTail: [
        0x16, 0x04,
        0x20, 0x01, 0x0D, 0xB8, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        0xBE, 0xEF,
      ]
    ),
    HEVVectorEndpoint(
      name: "domain",
      endpoint: RelayDatagramEndpoint(
        address: .domain(Data("example.test".utf8)),
        port: 443
      ),
      headerTail: [
        0x13, 0x03, 0x0C, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x74,
        0x65, 0x73, 0x74, 0x01, 0xBB,
      ]
    ),
  ]
}

private func vectorPayloads() -> [Data] {
  [
    Data(),
    Data([0x00, 0x7F, 0x80, 0xFE, 0xFF]),
    patternedData(count: Int(RelayProtocolV1.maxUDPPayloadClientHardCeiling)),
  ]
}

private func patternedData(count: Int) -> Data {
  Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
}

/// Independent HEV oracle: the header tails above are literal recorded layout
/// bytes, and only the unsigned network-order MSGLEN is inserted here.
private func hevOracle(headerTail: [UInt8], data: Data) -> Data {
  var wire = Data([
    UInt8(truncatingIfNeeded: data.count >> 8),
    UInt8(truncatingIfNeeded: data.count),
  ])
  wire.append(contentsOf: headerTail)
  wire.append(data)
  return wire
}

private func expectFailure(
  _ code: RelayDatagramFailureCode,
  scope: RelayDatagramScope,
  disposition: RelayDatagramDisposition,
  operation: () throws -> Void
) {
  do {
    try operation()
    Issue.record("expected \(code.rawValue)")
  } catch let failure as RelayDatagramFailure {
    #expect(failure.code == code)
    #expect(failure.scope == scope)
    #expect(failure.disposition == disposition)
  } catch {
    Issue.record("unexpected error type")
  }
}

extension Data {
  fileprivate func byte(at offset: Int) -> UInt8 {
    self[index(startIndex, offsetBy: offset)]
  }
}
