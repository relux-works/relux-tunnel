import Foundation

/// A byte-preserving SOCKS/HEV address. Domain bytes are deliberately opaque:
/// DNS presentation-form validation belongs to the relay resolution boundary.
public enum RelayDatagramAddress: Equatable, Sendable {
  case ipv4(Data)
  case ipv6(Data)
  case domain(Data)

  public var type: RelayProtocolV1.AddressType {
    switch self {
    case .ipv4: .ipv4
    case .ipv6: .ipv6
    case .domain: .domain
    }
  }

  public var wireBytes: Data {
    switch self {
    case .ipv4(let bytes), .ipv6(let bytes), .domain(let bytes): bytes
    }
  }
}

/// The destination endpoint on client requests and the relay-observed source
/// endpoint on responses. The codec never resolves or substitutes endpoints.
public struct RelayDatagramEndpoint: Equatable, Sendable {
  public let address: RelayDatagramAddress
  public let port: UInt16

  public init(address: RelayDatagramAddress, port: UInt16) {
    self.address = address
    self.port = port
  }
}

public struct RelayDatagram: Equatable, Sendable {
  public let endpoint: RelayDatagramEndpoint
  public let data: Data

  public init(endpoint: RelayDatagramEndpoint, data: Data) {
    self.endpoint = endpoint
    self.data = data
  }
}

public enum RelayDatagramFailureCode: String, CaseIterable, Equatable, Sendable {
  case invalidConfiguration
  case arithmeticOverflow
  case truncatedFixedHeader
  case unknownAddressType
  case invalidAddressLength
  case headerLengthMismatch
  case truncatedAddress
  case truncatedPort
  case invalidPort
  case messageLengthExceedsProtocolMaximum
  case messageLengthExceedsLocalMaximum
  case messageLengthMismatch
  case outerLengthMismatch
}

public enum RelayDatagramPhase: String, Equatable, Sendable {
  case configuration
  case encoding
  case fixedHeader
  case address
  case port
  case data
  case outerLength
}

public enum RelayDatagramScope: String, Equatable, Sendable {
  case association
  case session
}

public enum RelayDatagramDisposition: String, Equatable, Sendable {
  case rejectDatagram
  case closeAssociation
  case closeSession
}

/// A finite, privacy-safe failure. It intentionally carries no endpoint,
/// domain, payload, peer text, or remote-controlled numeric value.
public struct RelayDatagramFailure: Error, Equatable, Sendable, CustomStringConvertible {
  public let code: RelayDatagramFailureCode
  public let phase: RelayDatagramPhase
  public let scope: RelayDatagramScope
  public let disposition: RelayDatagramDisposition

  fileprivate init(
    code: RelayDatagramFailureCode,
    phase: RelayDatagramPhase,
    scope: RelayDatagramScope,
    disposition: RelayDatagramDisposition
  ) {
    self.code = code
    self.phase = phase
    self.scope = scope
    self.disposition = disposition
  }

  public var description: String {
    "relayDatagram code=\(code.rawValue) phase=\(phase.rawValue) "
      + "scope=\(scope.rawValue) disposition=\(disposition.rawValue)"
  }
}

public struct RelayDatagramCodecMetrics: Equatable, Sendable {
  public fileprivate(set) var inputRecords: UInt64 = 0
  public fileprivate(set) var inputBytes: UInt64 = 0
  public fileprivate(set) var decodedRecords: UInt64 = 0
  public fileprivate(set) var encodedRecords: UInt64 = 0
  public fileprivate(set) var encodedBytes: UInt64 = 0
  public fileprivate(set) var decodedMaterializedBytes: UInt64 = 0
  public fileprivate(set) var failures: UInt64 = 0

  public init() {}
}

public enum RelayDatagramWire {
  /// Validates a complete HEV header without retaining or materializing its
  /// declared DATA bytes. This is the adapter's structural-before-limit gate
  /// for oversized stream records.
  public static func validateHeader(_ header: Data) throws {
    guard header.count >= 3 else {
      throw decodingFailure(.truncatedFixedHeader, phase: .fixedHeader)
    }
    guard Int(header.byte(at: 2)) == header.count else {
      throw decodingFailure(.headerLengthMismatch, phase: .fixedHeader)
    }

    var headerOnlyRecord = header
    headerOnlyRecord[headerOnlyRecord.startIndex] = 0
    headerOnlyRecord[headerOnlyRecord.index(after: headerOnlyRecord.startIndex)] = 0
    var codec = try RelayDatagramCodec()
    _ = try codec.decode(headerOnlyRecord)
  }

  /// Computes and validates the exact HEV record size before allocation.
  public static func encodedLength(
    endpoint: RelayDatagramEndpoint,
    dataLength: UInt64,
    maximumPayloadLength: UInt16 = RelayProtocolV1.maxUDPPayloadClientDefault
  ) throws -> Int {
    try validateMaximumPayloadLength(maximumPayloadLength)
    let headerLength = try validateEndpoint(endpoint, phase: .encoding)
    let (recordLength, overflow) = UInt64(headerLength).addingReportingOverflow(dataLength)
    guard !overflow, recordLength <= UInt64(Int.max) else {
      throw encodingFailure(.arithmeticOverflow, phase: .encoding)
    }
    guard dataLength <= UInt64(RelayProtocolV1.maxUDPPayloadClientHardCeiling) else {
      throw encodingFailure(.messageLengthExceedsProtocolMaximum, phase: .data)
    }
    guard dataLength <= UInt64(maximumPayloadLength) else {
      throw encodingFailure(.messageLengthExceedsLocalMaximum, phase: .data)
    }
    guard recordLength <= UInt64(RelayProtocolV1.maxHEVRecordWidth) else {
      throw encodingFailure(.arithmeticOverflow, phase: .encoding)
    }
    return Int(recordLength)
  }
}

public struct RelayDatagramCodec: Sendable {
  public let maximumPayloadLength: UInt16
  public private(set) var metrics = RelayDatagramCodecMetrics()

  public init(
    maximumPayloadLength: UInt16 = RelayProtocolV1.maxUDPPayloadClientDefault
  ) throws {
    try validateMaximumPayloadLength(maximumPayloadLength)
    self.maximumPayloadLength = maximumPayloadLength
  }

  public mutating func encode(_ datagram: RelayDatagram) throws -> Data {
    do {
      let recordLength = try RelayDatagramWire.encodedLength(
        endpoint: datagram.endpoint,
        dataLength: UInt64(datagram.data.count),
        maximumPayloadLength: maximumPayloadLength
      )
      let addressBytes = datagram.endpoint.address.wireBytes
      let headerLength = recordLength - datagram.data.count

      var record = Data()
      record.reserveCapacity(recordLength)
      appendDatagramBigEndian(UInt16(datagram.data.count), to: &record)
      record.append(UInt8(headerLength))
      record.append(datagram.endpoint.address.type.rawValue)
      if case .domain = datagram.endpoint.address {
        record.append(UInt8(addressBytes.count))
      }
      record.append(addressBytes)
      appendDatagramBigEndian(datagram.endpoint.port, to: &record)
      record.append(datagram.data)

      guard record.count == recordLength else {
        throw encodingFailure(.arithmeticOverflow, phase: .encoding)
      }
      metrics.encodedRecords += 1
      metrics.encodedBytes += UInt64(record.count)
      return record
    } catch let failure as RelayDatagramFailure {
      metrics.failures += 1
      throw failure
    }
  }

  /// Decodes one complete envelope payload. HEV structure is validated before
  /// payload-limit policy, and every check finishes before slicing/materializing.
  public mutating func decode(_ record: Data) throws -> RelayDatagram {
    metrics.inputRecords += 1
    metrics.inputBytes += UInt64(record.count)

    do {
      let layout = try validateRecordLayout(record)
      let addressStart = record.index(record.startIndex, offsetBy: layout.addressOffset)
      let addressEnd = record.index(addressStart, offsetBy: layout.addressLength)
      let dataStart = record.index(record.startIndex, offsetBy: layout.headerLength)

      let addressBytes = Data(record[addressStart..<addressEnd])
      let data = Data(record[dataStart..<record.endIndex])
      let address: RelayDatagramAddress =
        switch layout.addressType {
        case .ipv4: .ipv4(addressBytes)
        case .ipv6: .ipv6(addressBytes)
        case .domain: .domain(addressBytes)
        }
      let datagram = RelayDatagram(
        endpoint: RelayDatagramEndpoint(address: address, port: layout.port),
        data: data
      )

      metrics.decodedRecords += 1
      metrics.decodedMaterializedBytes += UInt64(addressBytes.count + data.count)
      return datagram
    } catch let failure as RelayDatagramFailure {
      metrics.failures += 1
      throw failure
    }
  }

  private func validateRecordLayout(_ record: Data) throws -> RelayDatagramLayout {
    guard record.count >= 4 else {
      throw decodingFailure(.truncatedFixedHeader, phase: .fixedHeader)
    }

    let messageLength =
      (Int(record.byte(at: 0)) << 8) | Int(record.byte(at: 1))
    let headerLength = Int(record.byte(at: 2))
    guard
      let addressType = RelayProtocolV1.AddressType(rawValue: record.byte(at: 3))
    else {
      throw decodingFailure(.unknownAddressType, phase: .address)
    }
    let addressOffset: Int
    let addressLength: Int
    let expectedHeaderLength: Int
    switch addressType {
    case .ipv4:
      addressOffset = 4
      addressLength = 4
      expectedHeaderLength = RelayProtocolV1.hevHDRLENIPv4
    case .ipv6:
      addressOffset = 4
      addressLength = 16
      expectedHeaderLength = RelayProtocolV1.hevHDRLENIPv6
    case .domain:
      guard record.count >= 5 else {
        throw decodingFailure(.truncatedAddress, phase: .address)
      }
      addressOffset = 5
      addressLength = Int(record.byte(at: 4))
      guard
        addressLength >= RelayProtocolV1.minDomainWireBytes,
        addressLength <= RelayProtocolV1.maxDomainWireBytes
      else {
        throw decodingFailure(.invalidAddressLength, phase: .address)
      }
      expectedHeaderLength = RelayProtocolV1.hevHDRLENDomainBase + addressLength
    }

    guard headerLength == expectedHeaderLength else {
      throw decodingFailure(.headerLengthMismatch, phase: .fixedHeader)
    }
    let addressEnd = addressOffset + addressLength
    guard record.count >= addressEnd else {
      throw decodingFailure(.truncatedAddress, phase: .address)
    }
    let portEnd = addressEnd + RelayProtocolV1.hevPortWidth
    guard record.count >= portEnd else {
      throw decodingFailure(.truncatedPort, phase: .port)
    }
    guard portEnd == headerLength else {
      throw decodingFailure(.headerLengthMismatch, phase: .fixedHeader)
    }
    let port =
      (UInt16(record.byte(at: addressEnd)) << 8)
      | UInt16(record.byte(at: addressEnd + 1))
    guard port != 0 else {
      throw decodingFailure(.invalidPort, phase: .port)
    }

    let availableDataLength = record.count - headerLength
    guard availableDataLength == messageLength else {
      throw decodingFailure(.messageLengthMismatch, phase: .data)
    }
    let (outerLength, overflow) = headerLength.addingReportingOverflow(messageLength)
    guard !overflow else {
      throw decodingFailure(.arithmeticOverflow, phase: .outerLength)
    }
    guard outerLength == record.count else {
      throw decodingFailure(.outerLengthMismatch, phase: .outerLength)
    }
    guard messageLength <= Int(RelayProtocolV1.maxUDPPayloadClientHardCeiling) else {
      throw decodingFailure(.messageLengthExceedsProtocolMaximum, phase: .data)
    }
    guard messageLength <= Int(maximumPayloadLength) else {
      throw localLimitFailure()
    }

    return RelayDatagramLayout(
      addressType: addressType,
      addressOffset: addressOffset,
      addressLength: addressLength,
      headerLength: headerLength,
      port: port
    )
  }
}

private struct RelayDatagramLayout {
  let addressType: RelayProtocolV1.AddressType
  let addressOffset: Int
  let addressLength: Int
  let headerLength: Int
  let port: UInt16
}

private func validateMaximumPayloadLength(_ value: UInt16) throws {
  guard
    value >= RelayProtocolV1.maxUDPPayloadFloor,
    value <= RelayProtocolV1.maxUDPPayloadClientHardCeiling
  else {
    throw RelayDatagramFailure(
      code: .invalidConfiguration,
      phase: .configuration,
      scope: .session,
      disposition: .closeSession
    )
  }
}

private func validateEndpoint(
  _ endpoint: RelayDatagramEndpoint,
  phase: RelayDatagramPhase
) throws -> Int {
  guard endpoint.port != 0 else {
    throw encodingFailure(.invalidPort, phase: .port)
  }
  let length = endpoint.address.wireBytes.count
  switch endpoint.address {
  case .ipv4:
    guard length == 4 else {
      throw encodingFailure(.invalidAddressLength, phase: phase)
    }
    return RelayProtocolV1.hevHDRLENIPv4
  case .ipv6:
    guard length == 16 else {
      throw encodingFailure(.invalidAddressLength, phase: phase)
    }
    return RelayProtocolV1.hevHDRLENIPv6
  case .domain:
    guard
      length >= RelayProtocolV1.minDomainWireBytes,
      length <= RelayProtocolV1.maxDomainWireBytes
    else {
      throw encodingFailure(.invalidAddressLength, phase: phase)
    }
    return RelayProtocolV1.hevHDRLENDomainBase + length
  }
}

private func encodingFailure(
  _ code: RelayDatagramFailureCode,
  phase: RelayDatagramPhase
) -> RelayDatagramFailure {
  RelayDatagramFailure(
    code: code,
    phase: phase,
    scope: .association,
    disposition: .rejectDatagram
  )
}

private func decodingFailure(
  _ code: RelayDatagramFailureCode,
  phase: RelayDatagramPhase
) -> RelayDatagramFailure {
  RelayDatagramFailure(
    code: code,
    phase: phase,
    scope: .association,
    disposition: .closeAssociation
  )
}

private func localLimitFailure() -> RelayDatagramFailure {
  RelayDatagramFailure(
    code: .messageLengthExceedsLocalMaximum,
    phase: .data,
    scope: .association,
    disposition: .rejectDatagram
  )
}

private func appendDatagramBigEndian(_ value: UInt16, to data: inout Data) {
  data.append(UInt8(truncatingIfNeeded: value >> 8))
  data.append(UInt8(truncatingIfNeeded: value))
}

extension Data {
  fileprivate func byte(at offset: Int) -> UInt8 {
    self[index(startIndex, offsetBy: offset)]
  }
}
