#!/usr/bin/env python3
"""Generate and independently audit relay protocol v1 conformance vectors.

This build-only oracle intentionally does not import, invoke, or translate either
production codec. It constructs and parses wire bytes with Python's standard
library directly from the reviewed protocol schema and binding decisions.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "Protocol/Relay/relay-v1.schema.json"
CORPUS_PATH = ROOT / "Protocol/Relay/Vectors/v1/corpus.json"
FORMAT_VERSION = 1
GENERATOR_FORMAT_VERSION = 1


class VectorError(RuntimeError):
    pass


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n").encode()


def u16(value: int) -> bytes:
    return struct.pack(">H", value)


def u32(value: int) -> bytes:
    return struct.pack(">I", value)


def pattern(length: int) -> bytes:
    return bytes(index % 251 for index in range(length))


def load_schema() -> tuple[dict[str, Any], bytes]:
    raw = SCHEMA_PATH.read_bytes()
    return json.loads(raw), raw


def index_schema(schema: dict[str, Any]) -> dict[str, Any]:
    return {
        "message": {entry["name"]: entry for entry in schema["messageTypes"]},
        "address": {entry["name"]: entry for entry in schema["addressTypes"]},
        "status": {entry["name"]: entry for entry in schema["helloStatuses"]},
        "udpError": {entry["name"]: entry for entry in schema["udpErrorCodes"]},
        "limit": {entry["name"]: entry for entry in schema["limits"]},
    }


def limit_value(index: dict[str, Any], reference: str) -> int:
    try:
        name, selector = reference.split(".", 1)
        field = {
            "floor": "floor",
            "clientDefault": "clientDefault",
            "relayDefault": "relayDefault",
            "clientHardCeiling": "clientHardCeiling",
            "relayHardCeiling": "relayHardCeiling",
        }[selector]
        return int(index["limit"][name][field])
    except (KeyError, ValueError) as error:
        raise VectorError(f"invalid limit reference {reference!r}") from error


def client_hello(magic: bytes, version: int, flags: int, maximum_frame: int) -> bytes:
    return magic + u16(version) + u16(flags) + u32(maximum_frame)


def server_hello(
    magic: bytes,
    version: int,
    status: int,
    features: int,
    maximum_frame: int,
) -> bytes:
    return magic + u16(version) + u16(status) + u32(features) + u32(maximum_frame)


def datagram_record(address_type: int, address: bytes, port: int, data: bytes) -> bytes:
    if address_type == 0x01:
        header_length = 10
        address_wire = address
    elif address_type == 0x04:
        header_length = 22
        address_wire = address
    elif address_type == 0x03:
        header_length = 7 + len(address)
        address_wire = bytes([len(address)]) + address
    else:
        raise VectorError("oracle cannot encode an unknown address type")
    return u16(len(data)) + bytes([header_length, address_type]) + address_wire + u16(port) + data


def envelope(message_type: int, flags: int, association_id: int, payload: bytes) -> bytes:
    body = bytes([message_type, flags]) + u32(association_id) + payload
    return u32(len(body)) + body


def frame_result(name: str, flags: int, association_id: int, payload: bytes) -> dict[str, Any]:
    return {
        "associationID": association_id,
        "flags": flags,
        "messageType": name,
        "payloadHex": payload.hex(),
    }


def success(**fields: Any) -> dict[str, Any]:
    return {"outcome": "success", **fields}


def failure(code: str, phase: str, scope: str, disposition: str) -> dict[str, Any]:
    return {
        "code": code,
        "disposition": disposition,
        "outcome": "failure",
        "phase": phase,
        "scope": scope,
    }


def build_corpus(schema: dict[str, Any], schema_raw: bytes) -> dict[str, Any]:
    index = index_schema(schema)
    magic = schema["magic"]["ascii"].encode("ascii")
    version = int(schema["protocol"]["wireVersion"])
    messages = index["message"]
    addresses = index["address"]
    statuses = index["status"]
    errors = index["udpError"]
    max_frame_floor = limit_value(index, "maxFrame.floor")
    max_frame_default = limit_value(index, "maxFrame.clientDefault")
    max_frame_ceiling = limit_value(index, "maxFrame.clientHardCeiling")
    max_udp = limit_value(index, "maxUDPPayload.clientDefault")
    udp_floor = limit_value(index, "maxUDPPayload.floor")
    dns_flag = 1
    reserved_flag = 2
    vectors: list[dict[str, Any]] = []

    def add(
        identifier: str,
        kind: str,
        wire: bytes,
        expected: dict[str, Any],
        *,
        direction: str = "none",
        chunks: list[int] | None = None,
        features: list[str] | None = None,
        limit_refs: list[str] | None = None,
        covers: list[str] | None = None,
    ) -> None:
        vectors.append(
            {
                "chunks": chunks or [],
                "covers": covers or [],
                "direction": direction,
                "expected": expected,
                "features": features or [],
                "id": identifier,
                "inputHex": wire.hex(),
                "kind": kind,
                "limitRefs": limit_refs or [],
                "protocolVersion": version,
            }
        )

    # Client hello: exact layout, both maxFrame boundaries, and every reject class.
    for identifier, maximum_frame, coverage in [
        ("v1.hello.client.max-frame-floor", max_frame_floor, "boundary:maxFrame:floor"),
        ("v1.hello.client.max-frame-default", max_frame_default, "boundary:maxFrame:default"),
        ("v1.hello.client.max-frame-ceiling", max_frame_ceiling, "boundary:maxFrame:ceiling"),
    ]:
        wire = client_hello(magic, version, dns_flag, maximum_frame)
        add(
            identifier,
            "clientHello",
            wire,
            success(version=version, flags=dns_flag, maxFrame=maximum_frame),
            direction="clientToRelay",
            chunks=[1, 2, 3, 6],
            features=["dnsPriorityHint"],
            limit_refs=[
                {
                    max_frame_floor: "maxFrame.floor",
                    max_frame_default: "maxFrame.clientDefault",
                    max_frame_ceiling: "maxFrame.clientHardCeiling",
                }[maximum_frame]
            ],
            covers=["hello:client", coverage, "chunk:fragmented"],
        )

    client_failures = [
        (
            "v1.hello.client.bad-magic",
            b"XLXR" + u16(version) + u16(0) + u32(max_frame_default),
            "unknownMagic",
            "malformed:magic",
        ),
        (
            "v1.hello.client.version-zero",
            client_hello(magic, 0, 0, max_frame_default),
            "unsupportedVersion",
            "boundary:version:below",
        ),
        (
            "v1.hello.client.version-two",
            client_hello(magic, version + 1, 0, max_frame_default),
            "unsupportedVersion",
            "boundary:version:above",
        ),
        (
            "v1.hello.client.reserved-flag",
            client_hello(magic, version, reserved_flag, max_frame_default),
            "reservedClientFlags",
            "malformed:helloFlags",
        ),
        (
            "v1.hello.client.max-frame-below-floor",
            client_hello(magic, version, 0, max_frame_floor - 1),
            "unreasonableMaxFrame",
            "boundary:maxFrame:belowFloor",
        ),
        (
            "v1.hello.client.max-frame-above-ceiling",
            client_hello(magic, version, 0, max_frame_ceiling + 1),
            "unreasonableMaxFrame",
            "boundary:maxFrame:aboveCeiling",
        ),
        (
            "v1.hello.client.truncated",
            client_hello(magic, version, 0, max_frame_default)[:-1],
            "truncatedHello",
            "boundary:clientHello:belowWidth",
        ),
        (
            "v1.hello.client.extended",
            client_hello(magic, version, 0, max_frame_default) + b"\x00",
            "extendedHello",
            "boundary:clientHello:aboveWidth",
        ),
    ]
    for identifier, wire, code, coverage in client_failures:
        add(
            identifier,
            "clientHello",
            wire,
            failure(code, "clientHelloValidation", "session", "closeSession"),
            direction="clientToRelay",
            limit_refs=["maxFrame.clientDefault"],
            covers=[coverage, "failureScope:session.closeSession"],
        )

    # Server hello: every schema status plus feature and frame boundaries.
    for identifier, features_value, features_list, maximum_frame, reference, coverage in [
        ("v1.hello.server.accepted-floor", 0, [], max_frame_floor, "maxFrame.floor", "boundary:maxFrame:floor"),
        (
            "v1.hello.server.accepted-default-feature",
            dns_flag,
            ["dnsPriorityHint"],
            max_frame_default,
            "maxFrame.clientDefault",
            "helloStatus:ACCEPTED",
        ),
        (
            "v1.hello.server.accepted-ceiling",
            dns_flag,
            ["dnsPriorityHint"],
            max_frame_ceiling,
            "maxFrame.clientHardCeiling",
            "boundary:maxFrame:ceiling",
        ),
    ]:
        wire = server_hello(magic, version, statuses["ACCEPTED"]["value"], features_value, maximum_frame)
        add(
            identifier,
            "serverHello",
            wire,
            success(version=version, status=0, features=features_value, maxFrame=maximum_frame),
            direction="relayToClient",
            chunks=[3, 1, 5, 7],
            features=features_list,
            limit_refs=[reference],
            covers=["hello:server", coverage, "chunk:fragmented"],
        )

    status_failures = {
        "UNSUPPORTED_VERSION": "unsupportedVersion",
        "INVALID_CLIENT_HELLO": "invalidClientHello",
        "RESOURCE_POLICY_REJECTED": "resourcePolicyRejected",
        "RELAY_UNAVAILABLE": "relayUnavailable",
    }
    for name, code in status_failures.items():
        wire = server_hello(magic, version, statuses[name]["value"], 0, 0)
        add(
            f"v1.hello.server.status-{name.lower().replace('_', '-')}",
            "serverHello",
            wire,
            failure(code, "serverHelloValidation", "session", "closeSession"),
            direction="relayToClient",
            features=["dnsPriorityHint"],
            limit_refs=["maxFrame.clientDefault"],
            covers=[f"helloStatus:{name}", "failureScope:session.closeSession"],
        )
    add(
        "v1.hello.server.status-unknown",
        "serverHello",
        server_hello(magic, version, 0xFFFF, 0, 0),
        failure("relayRejected", "serverHelloValidation", "session", "closeSession"),
        direction="relayToClient",
        features=["dnsPriorityHint"],
        limit_refs=["maxFrame.clientDefault"],
        covers=["malformed:helloStatus", "failureScope:session.closeSession"],
    )
    server_failures = [
        ("v1.hello.server.bad-magic", server_hello(b"RLXQ", version, 0, 0, max_frame_default), "unknownMagic", "malformed:magic"),
        ("v1.hello.server.version-two", server_hello(magic, version + 1, 0, 0, max_frame_default), "unsupportedVersion", "boundary:version:above"),
        ("v1.hello.server.reserved-feature", server_hello(magic, version, 0, reserved_flag, max_frame_default), "impossibleFeatureSelection", "malformed:features"),
        ("v1.hello.server.max-frame-below-floor", server_hello(magic, version, 0, 0, max_frame_floor - 1), "unreasonableMaxFrame", "boundary:maxFrame:belowFloor"),
        ("v1.hello.server.max-frame-above-ceiling", server_hello(magic, version, 0, 0, max_frame_ceiling + 1), "unreasonableMaxFrame", "boundary:maxFrame:aboveCeiling"),
        ("v1.hello.server.truncated", server_hello(magic, version, 0, 0, max_frame_default)[:-1], "truncatedHello", "boundary:serverHello:belowWidth"),
        ("v1.hello.server.extended", server_hello(magic, version, 0, 0, max_frame_default) + b"\x00", "extendedHello", "boundary:serverHello:aboveWidth"),
    ]
    for identifier, wire, code, coverage in server_failures:
        add(
            identifier,
            "serverHello",
            wire,
            failure(code, "serverHelloValidation", "session", "closeSession"),
            direction="relayToClient",
            features=["dnsPriorityHint"],
            limit_refs=["maxFrame.clientHardCeiling"],
            covers=[coverage, "failureScope:session.closeSession"],
        )

    ipv4 = bytes([192, 0, 2, 44])
    ipv6 = bytes.fromhex("20010db8000000000000000000000044")
    domain_min = b"x"
    domain_typical = b"relay.example"
    domain_max = b".".join([b"a" * 63, b"b" * 63, b"c" * 63, b"d" * 48, b"example"])
    assert len(domain_max) == addresses["DOMAIN"]["maxAddressBytes"]
    address_cases = [
        ("IPV4", ipv4, 1, b"", "boundary:payload:zero"),
        ("IPV6", ipv6, 65535, bytes.fromhex("cafe"), "boundary:port:maximum"),
        ("DOMAIN", domain_min, 53, b"\x00", "boundary:domain:minimum"),
        ("DOMAIN", domain_typical, 5353, bytes.fromhex("000102ff"), "address:domainTypical"),
    ]
    for name, address, port, data, coverage in address_cases:
        address_type = addresses[name]["value"]
        record = datagram_record(address_type, address, port, data)
        add(
            f"v1.datagram.{name.lower()}-{coverage.split(':')[-1].lower()}",
            "datagram",
            record,
            success(addressType=name, addressHex=address.hex(), port=port, dataHex=data.hex()),
            limit_refs=["maxUDPPayload.clientDefault"],
            covers=[f"addressType:{name}", coverage],
        )

    max_data = pattern(max_udp)
    max_record = datagram_record(addresses["DOMAIN"]["value"], domain_max, 65535, max_data)
    max_frame = envelope(messages["UDP_DATAGRAM"]["value"], 0, 0xFFFFFFFF, max_record)
    add(
        "v1.frame.maximum-legal-domain-datagram",
        "envelopeDatagram",
        max_frame,
        success(
            frames=[frame_result("UDP_DATAGRAM", 0, 0xFFFFFFFF, max_record)],
            addressType="DOMAIN",
            addressHex=domain_max.hex(),
            port=65535,
            dataHex=max_data.hex(),
        ),
        direction="clientToRelay",
        chunks=[4, 6, 255, len(max_frame) - 265],
        limit_refs=["maxFrame.floor", "maxUDPPayload.clientDefault"],
        covers=[
            "messageType:UDP_DATAGRAM",
            "direction:UDP_DATAGRAM:clientToRelay",
            "addressType:DOMAIN",
            "boundary:domain:maximum",
            "boundary:payload:maximum",
            "boundary:associationID:maximum",
            "boundary:frameBody:maximumLegal",
            "chunk:fragmented",
        ],
    )
    oversized_data = pattern(max_udp + 1)
    oversized_record = datagram_record(addresses["DOMAIN"]["value"], domain_max, 65535, oversized_data)
    oversized_frame = envelope(messages["UDP_DATAGRAM"]["value"], 0, 1, oversized_record)
    add(
        "v1.frame.above-maximum-legal-domain-datagram",
        "envelopeDatagram",
        oversized_frame,
        failure("messageLengthExceedsProtocolMaximum", "data", "association", "closeAssociation"),
        direction="clientToRelay",
        chunks=[len(oversized_frame)],
        limit_refs=["maxFrame.floor", "maxUDPPayload.clientDefault"],
        covers=[
            "boundary:payload:aboveMaximum",
            "boundary:frameBody:aboveMaximumLegal",
            "failureScope:association.closeAssociation",
        ],
    )

    # UDP_DATAGRAM in the reverse legal direction, including IPv4 and IPv6.
    for name, address in [("IPV4", ipv4), ("IPV6", ipv6)]:
        record = datagram_record(addresses[name]["value"], address, 443, b"reply")
        wire = envelope(messages["UDP_DATAGRAM"]["value"], 0, 1, record)
        add(
            f"v1.envelope.udp-datagram-relay-to-client-{name.lower()}",
            "envelopeDatagram",
            wire,
            success(
                frames=[frame_result("UDP_DATAGRAM", 0, 1, record)],
                addressType=name,
                addressHex=address.hex(),
                port=443,
                dataHex=b"reply".hex(),
            ),
            direction="relayToClient",
            chunks=[2, 5, len(wire) - 7],
            limit_refs=["maxFrame.floor", "maxUDPPayload.clientDefault"],
            covers=[f"direction:UDP_DATAGRAM:relayToClient", f"addressType:{name}"],
        )

    # Every finite UDP error code is an exact two-byte relay-to-client frame.
    for name, entry in errors.items():
        payload = u16(entry["value"])
        wire = envelope(messages["UDP_ERROR"]["value"], 0, 1, payload)
        add(
            f"v1.envelope.udp-error-{name.lower().replace('_', '-')}",
            "envelope",
            wire,
            success(frames=[frame_result("UDP_ERROR", 0, 1, payload)]),
            direction="relayToClient",
            chunks=[1, 3, len(wire) - 4],
            limit_refs=["maxFrame.floor"],
            covers=[
                "messageType:UDP_ERROR",
                "direction:UDP_ERROR:relayToClient",
                f"udpError:{name}",
            ],
        )
    unknown_error_payload = u16(0xFFFF)
    add(
        "v1.envelope.udp-error-unknown",
        "envelope",
        envelope(messages["UDP_ERROR"]["value"], 0, 1, unknown_error_payload),
        success(frames=[frame_result("UDP_ERROR", 0, 1, unknown_error_payload)]),
        direction="relayToClient",
        limit_refs=["maxFrame.floor"],
        covers=["malformed:udpErrorCode"],
    )

    token = bytes.fromhex("0011223344556677")
    fixed_successes = [
        ("ping", "PING", "clientToRelay", 0, token),
        ("pong", "PONG", "relayToClient", 0, token),
        ("close-association-client", "CLOSE_ASSOCIATION", "clientToRelay", 1, b""),
        ("close-association-relay", "CLOSE_ASSOCIATION", "relayToClient", 0xFFFFFFFF, b""),
        ("close-session-client", "CLOSE_SESSION", "clientToRelay", 0, b""),
        ("close-session-relay", "CLOSE_SESSION", "relayToClient", 0, b""),
    ]
    for identifier, name, direction, association_id, payload in fixed_successes:
        wire = envelope(messages[name]["value"], 0, association_id, payload)
        covers = [f"messageType:{name}", f"direction:{name}:{direction}"]
        if len(payload) == 0:
            covers.append("boundary:frameBody:minimum")
        if association_id == 1:
            covers.append("boundary:associationID:minimum")
        add(
            f"v1.envelope.{identifier}",
            "envelope",
            wire,
            success(frames=[frame_result(name, 0, association_id, payload)]),
            direction=direction,
            chunks=[len(wire)],
            limit_refs=["maxFrame.floor"],
            covers=covers,
        )

    dns_record = datagram_record(addresses["DOMAIN"]["value"], domain_typical, 53, b"dns")
    dns_wire = envelope(messages["UDP_DATAGRAM"]["value"], dns_flag, 1, dns_record)
    add(
        "v1.envelope.udp-datagram-dns-priority",
        "envelopeDatagram",
        dns_wire,
        success(
            frames=[frame_result("UDP_DATAGRAM", dns_flag, 1, dns_record)],
            addressType="DOMAIN",
            addressHex=domain_typical.hex(),
            port=53,
            dataHex=b"dns".hex(),
        ),
        direction="clientToRelay",
        chunks=[1] * len(dns_wire),
        features=["dnsPriorityHint"],
        limit_refs=["maxFrame.floor", "maxUDPPayload.clientDefault"],
        covers=["flag:dnsPriority", "chunk:fragmented"],
    )

    # Stream plans explicitly cross frame boundaries and coalesce multiple frames.
    stream_frames = [
        envelope(messages["PING"]["value"], 0, 0, token),
        envelope(messages["CLOSE_ASSOCIATION"]["value"], 0, 1, b""),
        envelope(messages["CLOSE_SESSION"]["value"], 0, 0, b""),
    ]
    stream_wire = b"".join(stream_frames)
    stream_expected = success(
        frames=[
            frame_result("PING", 0, 0, token),
            frame_result("CLOSE_ASSOCIATION", 0, 1, b""),
            frame_result("CLOSE_SESSION", 0, 0, b""),
        ]
    )
    add(
        "v1.stream.fragmented-across-three-frames",
        "stream",
        stream_wire,
        stream_expected,
        direction="clientToRelay",
        chunks=[1, 3, 8, 5, 2, 7, len(stream_wire) - 26],
        limit_refs=["maxFrame.floor"],
        covers=["chunk:fragmented", "stream:multipleFrames"],
    )
    add(
        "v1.stream.coalesced-three-frames",
        "stream",
        stream_wire,
        stream_expected,
        direction="clientToRelay",
        chunks=[len(stream_wire)],
        limit_refs=["maxFrame.floor"],
        covers=["chunk:coalesced", "stream:multipleFrames"],
    )

    # Envelope failures cover length, type, flags, direction, IDs, fixed sizes, and EOF.
    bad_envelopes = [
        ("length-below-minimum", u32(5) + bytes(5), "clientToRelay", [], "frameLengthBelowMinimum", "prefix", "boundary:frameLength:belowMinimum"),
        ("length-above-effective-max", u32(max_frame_floor + 1), "clientToRelay", [], "frameLengthExceedsMaximum", "prefix", "boundary:frameLength:aboveEffectiveMaximum"),
        ("unknown-type", u32(6) + bytes([0x00, 0]) + u32(0), "clientToRelay", [], "unknownMessageType", "header", "malformed:messageType"),
        ("reserved-type", u32(6) + bytes([0x40, 0]) + u32(0), "clientToRelay", [], "unknownMessageType", "header", "malformed:reservedMessageType"),
        ("reserved-flag", envelope(messages["PING"]["value"], reserved_flag, 0, token), "clientToRelay", ["dnsPriorityHint"], "reservedFlags", "header", "malformed:envelopeFlags"),
        ("dns-flag-without-feature", dns_wire, "clientToRelay", [], "invalidFlags", "header", "malformed:dnsFlagWithoutFeature"),
        ("dns-flag-on-ping", envelope(messages["PING"]["value"], dns_flag, 0, token), "clientToRelay", ["dnsPriorityHint"], "invalidFlags", "header", "malformed:dnsFlagMessage"),
        ("udp-error-wrong-direction", envelope(messages["UDP_ERROR"]["value"], 0, 1, u16(1)), "clientToRelay", [], "invalidDirection", "header", "malformed:direction"),
        ("ping-wrong-direction", envelope(messages["PING"]["value"], 0, 0, token), "relayToClient", [], "invalidDirection", "header", "malformed:direction"),
        ("pong-wrong-direction", envelope(messages["PONG"]["value"], 0, 0, token), "clientToRelay", [], "invalidDirection", "header", "malformed:direction"),
        ("datagram-zero-association", envelope(messages["UDP_DATAGRAM"]["value"], 0, 0, datagram_record(addresses["IPV4"]["value"], ipv4, 53, b"")), "clientToRelay", [], "invalidAssociationID", "header", "boundary:associationID:belowMinimum"),
        ("ping-nonzero-association", envelope(messages["PING"]["value"], 0, 1, token), "clientToRelay", [], "invalidAssociationID", "header", "malformed:associationID"),
        ("close-session-nonzero-association", envelope(messages["CLOSE_SESSION"]["value"], 0, 1, b""), "clientToRelay", [], "invalidAssociationID", "header", "malformed:associationID"),
        ("ping-short-payload", envelope(messages["PING"]["value"], 0, 0, token[:-1]), "clientToRelay", [], "invalidPayloadLength", "header", "boundary:fixedPayload:below"),
        ("ping-long-payload", envelope(messages["PING"]["value"], 0, 0, token + b"\x88"), "clientToRelay", [], "invalidPayloadLength", "header", "boundary:fixedPayload:above"),
        ("udp-error-short-payload", envelope(messages["UDP_ERROR"]["value"], 0, 1, b"\x00"), "relayToClient", [], "invalidPayloadLength", "header", "boundary:fixedPayload:below"),
        ("close-association-extra-payload", envelope(messages["CLOSE_ASSOCIATION"]["value"], 0, 1, b"\x00"), "clientToRelay", [], "invalidPayloadLength", "header", "boundary:fixedPayload:above"),
        ("truncated-prefix-eof", b"\x00\x00\x00", "clientToRelay", [], "unexpectedEOF", "terminal", "boundary:prefix:belowWidth"),
        ("truncated-body-eof", envelope(messages["PING"]["value"], 0, 0, token)[:-1], "clientToRelay", [], "unexpectedEOF", "terminal", "boundary:body:belowDeclared"),
    ]
    for identifier, wire, direction, features_list, code, phase, coverage in bad_envelopes:
        add(
            f"v1.envelope.failure-{identifier}",
            "envelope",
            wire,
            failure(code, phase, "session", "closeSession"),
            direction=direction,
            chunks=[1] * len(wire) if wire else [],
            features=features_list,
            limit_refs=["maxFrame.floor"],
            covers=[coverage, "failureScope:session.closeSession"],
        )

    # Datagram failures cover structural boundaries and both association dispositions.
    ipv4_empty = datagram_record(addresses["IPV4"]["value"], ipv4, 53, b"")
    datagram_failures = [
        ("empty", b"", "truncatedFixedHeader", "fixedHeader", "closeAssociation", "boundary:fixedHeader:zero"),
        ("one-byte", b"\x00", "truncatedFixedHeader", "fixedHeader", "closeAssociation", "boundary:fixedHeader:one"),
        ("two-byte", b"\x00\x00", "truncatedFixedHeader", "fixedHeader", "closeAssociation", "boundary:fixedHeader:two"),
        ("three-byte", b"\x00\x00\x0a", "truncatedFixedHeader", "fixedHeader", "closeAssociation", "boundary:fixedHeader:belowMinimum"),
        ("unknown-address", b"\x00\x00\x0a\xff", "unknownAddressType", "address", "closeAssociation", "malformed:addressType"),
        ("domain-length-missing", b"\x00\x00\x07\x03", "truncatedAddress", "address", "closeAssociation", "boundary:domain:lengthMissing"),
        ("domain-empty", b"\x00\x00\x07\x03\x00\x00\x35", "invalidAddressLength", "address", "closeAssociation", "boundary:domain:belowMinimum"),
        ("domain-249", b"\x00\x00\xff\x03\xf9", "invalidAddressLength", "address", "closeAssociation", "boundary:domain:aboveMaximum"),
        ("ipv4-wrong-hdrlen", b"\x00\x00\x09\x01" + ipv4 + b"\x00\x35", "headerLengthMismatch", "fixedHeader", "closeAssociation", "malformed:hdrlen"),
        ("ipv4-truncated-address", b"\x00\x00\x0a\x01\xc0", "truncatedAddress", "address", "closeAssociation", "boundary:address:truncated"),
        ("ipv4-truncated-port", ipv4_empty[:-1], "truncatedPort", "port", "closeAssociation", "boundary:port:truncated"),
        ("zero-port", datagram_record(addresses["IPV4"]["value"], ipv4, 1, b"")[:-2] + b"\x00\x00", "invalidPort", "port", "closeAssociation", "boundary:port:belowMinimum"),
        ("declared-data-missing", b"\x00\x01" + ipv4_empty[2:], "messageLengthMismatch", "data", "closeAssociation", "boundary:msglen:aboveAvailable"),
        ("undeclared-extra-data", ipv4_empty + b"\xaa", "messageLengthMismatch", "data", "closeAssociation", "boundary:msglen:belowAvailable"),
        ("payload-1473", datagram_record(addresses["IPV4"]["value"], ipv4, 53, oversized_data), "messageLengthExceedsProtocolMaximum", "data", "closeAssociation", "boundary:payload:aboveMaximum"),
        ("local-cap-513", datagram_record(addresses["IPV4"]["value"], ipv4, 53, pattern(udp_floor + 1)), "messageLengthExceedsLocalMaximum", "data", "rejectDatagram", "boundary:localPayloadCap:above"),
    ]
    for identifier, wire, code, phase, disposition, coverage in datagram_failures:
        reference = "maxUDPPayload.floor" if identifier == "local-cap-513" else "maxUDPPayload.clientDefault"
        add(
            f"v1.datagram.failure-{identifier}",
            "datagram",
            wire,
            failure(code, phase, "association", disposition),
            limit_refs=[reference],
            covers=[coverage, f"failureScope:association.{disposition}"],
        )

    corpus = {
        "formatVersion": FORMAT_VERSION,
        "protocolVersion": version,
        "provenance": {
            "generator": "scripts/relay-protocol-vectors.py",
            "generatorFormatVersion": GENERATOR_FORMAT_VERSION,
            "generatorSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "privacy": "synthetic-only-rfc-reserved-endpoints",
            "regenerateCommand": "make relay-protocol-vectors-generate",
            "reviewPolicy": {
                "compatibility": "Existing identifiers, bytes, or expectations may change only with the schema and both generated binding diffs; incompatible v1 edits require a new protocol version.",
                "identifiers": "Never reuse or rename a published identifier; append a replacement vector and retain the old vector for review visibility.",
                "requiredConsumers": ["Swift ReluxTunnelCoreTests", "Go relay/internal/protocol"],
            },
            "schemaSHA256": hashlib.sha256(schema_raw).hexdigest(),
            "sources": [
                ".spec/relay-protocol.md",
                ".spec/security-privacy.md",
                "Protocol/Relay/relay-v1.schema.json",
                "TASK-260715-111tde binding decision",
                "TASK-260715-18owh7 limit decision",
            ],
            "task": "TASK-260715-1q7u14",
        },
        "vectors": vectors,
    }
    audit_corpus(corpus, schema)
    return corpus


def classify_client_hello(data: bytes, index: dict[str, Any], magic: bytes, version: int) -> tuple[str, dict[str, Any]]:
    if len(data) < 12:
        return "failure", failure("truncatedHello", "clientHelloValidation", "session", "closeSession")
    if len(data) > 12:
        return "failure", failure("extendedHello", "clientHelloValidation", "session", "closeSession")
    if data[:4] != magic:
        return "failure", failure("unknownMagic", "clientHelloValidation", "session", "closeSession")
    got_version, flags, maximum_frame = struct.unpack(">HHI", data[4:])
    if got_version != version:
        return "failure", failure("unsupportedVersion", "clientHelloValidation", "session", "closeSession")
    if flags & 0xFFFE:
        return "failure", failure("reservedClientFlags", "clientHelloValidation", "session", "closeSession")
    if not limit_value(index, "maxFrame.floor") <= maximum_frame <= limit_value(index, "maxFrame.clientHardCeiling"):
        return "failure", failure("unreasonableMaxFrame", "clientHelloValidation", "session", "closeSession")
    return "success", success(version=got_version, flags=flags, maxFrame=maximum_frame)


def classify_server_hello(data: bytes, index: dict[str, Any], magic: bytes, version: int, requested: set[str]) -> tuple[str, dict[str, Any]]:
    if len(data) < 16:
        return "failure", failure("truncatedHello", "serverHelloValidation", "session", "closeSession")
    if len(data) > 16:
        return "failure", failure("extendedHello", "serverHelloValidation", "session", "closeSession")
    if data[:4] != magic:
        return "failure", failure("unknownMagic", "serverHelloValidation", "session", "closeSession")
    got_version, status, features, maximum_frame = struct.unpack(">HHII", data[4:])
    if got_version != version:
        return "failure", failure("unsupportedVersion", "serverHelloValidation", "session", "closeSession")
    status_codes = {1: "unsupportedVersion", 2: "invalidClientHello", 3: "resourcePolicyRejected", 4: "relayUnavailable"}
    if status != 0:
        return "failure", failure(status_codes.get(status, "relayRejected"), "serverHelloValidation", "session", "closeSession")
    if features & 0xFFFFFFFE or (features & 1 and "dnsPriorityHint" not in requested):
        return "failure", failure("impossibleFeatureSelection", "serverHelloValidation", "session", "closeSession")
    if not limit_value(index, "maxFrame.floor") <= maximum_frame <= limit_value(index, "maxFrame.clientHardCeiling"):
        return "failure", failure("unreasonableMaxFrame", "serverHelloValidation", "session", "closeSession")
    return "success", success(version=got_version, status=status, features=features, maxFrame=maximum_frame)


def classify_envelopes(data: bytes, vector: dict[str, Any], index: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    maximum_frame = limit_value(index, vector["limitRefs"][0])
    feature_enabled = "dnsPriorityHint" in vector["features"]
    offset = 0
    decoded: list[dict[str, Any]] = []
    metadata = {entry["value"]: entry for entry in index["message"].values()}
    while offset < len(data):
        if len(data) - offset < 4:
            return "failure", failure("unexpectedEOF", "terminal", "session", "closeSession")
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        if length < 6:
            return "failure", failure("frameLengthBelowMinimum", "prefix", "session", "closeSession")
        if length > maximum_frame:
            return "failure", failure("frameLengthExceedsMaximum", "prefix", "session", "closeSession")
        if len(data) - offset - 4 < length:
            return "failure", failure("unexpectedEOF", "terminal", "session", "closeSession")
        body = data[offset + 4 : offset + 4 + length]
        message_type, flags = body[0], body[1]
        association_id = struct.unpack(">I", body[2:6])[0]
        payload = body[6:]
        entry = metadata.get(message_type)
        if entry is None:
            return "failure", failure("unknownMessageType", "header", "session", "closeSession")
        if flags & 0xFE:
            return "failure", failure("reservedFlags", "header", "session", "closeSession")
        if flags and not (flags == 1 and entry["name"] == "UDP_DATAGRAM" and vector["direction"] == "clientToRelay" and feature_enabled):
            return "failure", failure("invalidFlags", "header", "session", "closeSession")
        if entry["direction"] != "both" and entry["direction"] != vector["direction"]:
            return "failure", failure("invalidDirection", "header", "session", "closeSession")
        if (entry["associationID"] == "zero" and association_id != 0) or (entry["associationID"] == "nonzero" and association_id == 0):
            return "failure", failure("invalidAssociationID", "header", "session", "closeSession")
        payload_spec = entry["payload"]
        if payload_spec["shape"] == "fixed" and len(payload) != payload_spec["width"]:
            return "failure", failure("invalidPayloadLength", "header", "session", "closeSession")
        decoded.append(frame_result(entry["name"], flags, association_id, payload))
        offset += 4 + length
    return "success", success(frames=decoded)


def classify_datagram(data: bytes, maximum_payload: int) -> tuple[str, dict[str, Any]]:
    close = lambda code, phase: ("failure", failure(code, phase, "association", "closeAssociation"))
    if len(data) < 4:
        return close("truncatedFixedHeader", "fixedHeader")
    message_length, header_length, address_type = struct.unpack(">HBB", data[:4])
    if address_type not in (1, 3, 4):
        return close("unknownAddressType", "address")
    address_offset = 4
    if address_type == 1:
        address_length, expected_header, name = 4, 10, "IPV4"
    elif address_type == 4:
        address_length, expected_header, name = 16, 22, "IPV6"
    else:
        if len(data) < 5:
            return close("truncatedAddress", "address")
        address_offset = 5
        address_length = data[4]
        if not 1 <= address_length <= 248:
            return close("invalidAddressLength", "address")
        expected_header, name = 7 + address_length, "DOMAIN"
    if header_length != expected_header:
        return close("headerLengthMismatch", "fixedHeader")
    address_end = address_offset + address_length
    if len(data) < address_end:
        return close("truncatedAddress", "address")
    port_end = address_end + 2
    if len(data) < port_end:
        return close("truncatedPort", "port")
    if port_end != header_length:
        return close("headerLengthMismatch", "fixedHeader")
    port = struct.unpack(">H", data[address_end:port_end])[0]
    if port == 0:
        return close("invalidPort", "port")
    if len(data) - header_length != message_length:
        return close("messageLengthMismatch", "data")
    if message_length > 1472:
        return close("messageLengthExceedsProtocolMaximum", "data")
    if message_length > maximum_payload:
        return "failure", failure("messageLengthExceedsLocalMaximum", "data", "association", "rejectDatagram")
    address = data[address_offset:address_end]
    payload = data[header_length:]
    return "success", success(addressType=name, addressHex=address.hex(), port=port, dataHex=payload.hex())


def audit_corpus(corpus: dict[str, Any], schema: dict[str, Any]) -> None:
    index = index_schema(schema)
    magic = schema["magic"]["ascii"].encode("ascii")
    version = schema["protocol"]["wireVersion"]
    identifiers: set[str] = set()
    coverage: set[str] = set()
    identifier_pattern = re.compile(r"^v1\.[a-z0-9]+(?:[.-][a-z0-9]+)*$")
    for vector in corpus["vectors"]:
        identifier = vector["id"]
        if identifier in identifiers or not identifier_pattern.fullmatch(identifier):
            raise VectorError(f"invalid or duplicate identifier {identifier}")
        identifiers.add(identifier)
        if vector["protocolVersion"] != version:
            raise VectorError(f"{identifier}: protocol version mismatch")
        try:
            wire = bytes.fromhex(vector["inputHex"])
        except ValueError as error:
            raise VectorError(f"{identifier}: invalid lowercase hex") from error
        if vector["inputHex"] != wire.hex():
            raise VectorError(f"{identifier}: hex must be canonical lowercase")
        if vector["chunks"] and (any(size <= 0 for size in vector["chunks"]) or sum(vector["chunks"]) != len(wire)):
            raise VectorError(f"{identifier}: invalid chunk plan")
        for reference in vector["limitRefs"]:
            limit_value(index, reference)
        if vector["kind"] == "clientHello":
            _, actual = classify_client_hello(wire, index, magic, version)
        elif vector["kind"] == "serverHello":
            _, actual = classify_server_hello(wire, index, magic, version, set(vector["features"]))
        elif vector["kind"] in ("envelope", "stream", "envelopeDatagram"):
            outcome, actual = classify_envelopes(wire, vector, index)
            if vector["kind"] == "envelopeDatagram" and outcome == "success":
                frame_payload = bytes.fromhex(actual["frames"][0]["payloadHex"])
                maximum_payload = limit_value(index, vector["limitRefs"][1])
                datagram_outcome, datagram_actual = classify_datagram(frame_payload, maximum_payload)
                if datagram_outcome == "failure":
                    actual = datagram_actual
                else:
                    actual.update({key: value for key, value in datagram_actual.items() if key != "outcome"})
        elif vector["kind"] == "datagram":
            _, actual = classify_datagram(wire, limit_value(index, vector["limitRefs"][0]))
        else:
            raise VectorError(f"{identifier}: unknown kind")
        if actual != vector["expected"]:
            raise VectorError(f"{identifier}: independent oracle expectation mismatch")
        coverage.update(vector["covers"])

    required = {
        "hello:client",
        "hello:server",
        "chunk:fragmented",
        "chunk:coalesced",
        "failureScope:session.closeSession",
        "failureScope:association.closeAssociation",
        "failureScope:association.rejectDatagram",
        "boundary:frameBody:maximumLegal",
        "boundary:frameBody:aboveMaximumLegal",
        "boundary:maxFrame:belowFloor",
        "boundary:maxFrame:floor",
        "boundary:maxFrame:ceiling",
        "boundary:maxFrame:aboveCeiling",
        "boundary:payload:zero",
        "boundary:payload:maximum",
        "boundary:payload:aboveMaximum",
        "boundary:domain:minimum",
        "boundary:domain:maximum",
        "boundary:domain:aboveMaximum",
    }
    required.update(f"messageType:{entry['name']}" for entry in schema["messageTypes"])
    required.update(f"addressType:{entry['name']}" for entry in schema["addressTypes"])
    required.update(f"helloStatus:{entry['name']}" for entry in schema["helloStatuses"])
    required.update(f"udpError:{entry['name']}" for entry in schema["udpErrorCodes"])
    for entry in schema["messageTypes"]:
        directions = [entry["direction"]] if entry["direction"] != "both" else ["clientToRelay", "relayToClient"]
        required.update(f"direction:{entry['name']}:{direction}" for direction in directions)
    missing = sorted(required - coverage)
    if missing:
        raise VectorError("missing required coverage: " + ", ".join(missing))


def command_generate() -> int:
    schema, schema_raw = load_schema()
    corpus = build_corpus(schema, schema_raw)
    CORPUS_PATH.write_bytes(canonical_json(corpus))
    digest = hashlib.sha256(CORPUS_PATH.read_bytes()).hexdigest()
    print(f"relay protocol vectors generated: count={len(corpus['vectors'])} sha256={digest}")
    return 0


def command_check() -> int:
    schema, schema_raw = load_schema()
    first = canonical_json(build_corpus(schema, schema_raw))
    second = canonical_json(build_corpus(schema, schema_raw))
    if first != second:
        raise VectorError("independent oracle generation is nondeterministic")
    if not CORPUS_PATH.exists():
        raise VectorError(f"missing checked-in corpus: {CORPUS_PATH.relative_to(ROOT)}")
    checked_in = CORPUS_PATH.read_bytes()
    if checked_in != first:
        raise VectorError("checked-in corpus drift; run make relay-protocol-vectors-generate")
    digest = hashlib.sha256(checked_in).hexdigest()
    count = len(json.loads(checked_in)["vectors"])
    print(f"relay protocol vectors OK: count={count} sha256={digest} deterministic=2/2")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("generate", "check"))
    args = parser.parse_args()
    try:
        return command_generate() if args.command == "generate" else command_check()
    except (OSError, ValueError, VectorError) as error:
        print(f"relay protocol vector error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
