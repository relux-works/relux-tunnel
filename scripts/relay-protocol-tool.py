#!/usr/bin/env python3
"""Relay protocol v1 schema validator and deterministic Swift/Go generator.

Build-time only (TASK-260715-2azda7). Python standard library only. The tool
validates `Protocol/Relay/relay-v1.schema.json` and emits the two checked-in
generated bindings:

  - Sources/ReluxTunnelCore/RelayProtocol/Generated/RelayProtocolV1+Generated.swift
  - relay/internal/protocol/generated_v1.go

Subcommands:

  validate    validate the schema, print nothing on success
  generate    validate and (re)write both generated outputs
  check       full CI drift gate: validation, negative fixtures, double
              regeneration into fresh temp roots, byte comparison against the
              checked-in outputs, embedded digest verification, and a
              deliberate stale/manual-edit self-test
  digest      print the schema SHA-256

Determinism contract: no timestamps, no absolute paths, no hash-order
iteration in emitted text. Run through `make relay-protocol-generate` /
`make relay-protocol-check`, which pin LC_ALL/LANG/TZ/PYTHONHASHSEED.
"""

import argparse
import copy
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SCHEMA_PATH = "Protocol/Relay/relay-v1.schema.json"
SWIFT_OUTPUT = "Sources/ReluxTunnelCore/RelayProtocol/Generated/RelayProtocolV1+Generated.swift"
GO_OUTPUT = "relay/internal/protocol/generated_v1.go"
FIXTURES_DIR = "Protocol/Relay/Fixtures/invalid-schema"
TEMP_ROOT = ".temp/relay-protocol-check"

GENERATOR_FORMAT_VERSION = 1
REGENERATE_COMMAND = "make relay-protocol-generate"

WIDTH_MAX = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}
DIRECTIONS = ("clientToRelay", "relayToClient", "both")
ASSOCIATION_RULES = ("zero", "nonzero")
LIMIT_CLASSES = ("negotiatedWire", "fixedWireConstant", "localCap")
BIT_STATUSES = ("allocated", "reserved")

SCREAMING_NAME = re.compile(r"^[A-Z][A-Z0-9_]*$")
CAMEL_NAME = re.compile(r"^[a-z][A-Za-z0-9]*$")
CAMEL_WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z][a-z0-9]*|[a-z0-9]+")

# Known initialisms for deterministic per-language identifier derivation.
INITIALISMS = {
    "atyp": "ATYP",
    "dns": "DNS",
    "hdrlen": "HDRLEN",
    "hev": "HEV",
    "id": "ID",
    "ipv4": "IPv4",
    "ipv6": "IPv6",
    "msglen": "MSGLEN",
    "udp": "UDP",
}

# Frozen v1 wire invariants. This table is a compatibility guard, not a
# constants source: runtime values flow only from the schema through the
# generated files. Editing this table is the explicit gate for a compatible
# v1 extension (reserved-bit allocation or appended codes); anything else
# requires a wireVersion bump with a parallel schema.
FROZEN_V1 = {
    "magicASCII": "RLXR",
    "clientHelloFields": (("magic", 4), ("version", 2), ("flags", 2), ("maxFrame", 4)),
    "serverHelloFields": (
        ("magic", 4),
        ("version", 2),
        ("status", 2),
        ("features", 4),
        ("maxFrame", 4),
    ),
    "envelopePrefix": ("frameLength", 4),
    "envelopeHeaderFields": (("type", 1), ("flags", 1), ("associationID", 4)),
    "helloStatuses": (
        (0, "ACCEPTED"),
        (1, "UNSUPPORTED_VERSION"),
        (2, "INVALID_CLIENT_HELLO"),
        (3, "RESOURCE_POLICY_REJECTED"),
        (4, "RELAY_UNAVAILABLE"),
    ),
    "messageTypes": (
        (16, "UDP_DATAGRAM", "both", "nonzero", "hevUDPRecord", None),
        (17, "UDP_ERROR", "relayToClient", "nonzero", "fixed", 2),
        (32, "PING", "clientToRelay", "zero", "fixed", 8),
        (33, "PONG", "relayToClient", "zero", "fixed", 8),
        (48, "CLOSE_ASSOCIATION", "both", "nonzero", "fixed", 0),
        (49, "CLOSE_SESSION", "both", "zero", "fixed", 0),
    ),
    "reservedMessageTypeRanges": ((64, 79, "resource-governance"),),
    "addressTypes": (
        (1, "IPV4", False, 4, 4),
        (3, "DOMAIN", True, 1, 248),
        (4, "IPV6", False, 16, 16),
    ),
    "udpErrorCodes": (
        (1, "INVALID_DATAGRAM"),
        (2, "UNSUPPORTED_ADDRESS"),
        (3, "UNKNOWN_OR_CLOSED_ASSOCIATION"),
        (4, "ASSOCIATION_LIMIT"),
        (5, "DATAGRAM_TOO_LARGE"),
        (6, "QUEUE_SATURATED"),
        (7, "RESOLUTION_FAILURE"),
        (8, "SOCKET_FAILURE"),
        (9, "IDLE_EXPIRY"),
        (10, "RESOURCE_LIMIT"),
    ),
    "helloFlagBits": ((0, "dnsPriorityHint", "allocated"), (1, "resourceLimitExchange", "reserved")),
    "featureBits": ((0, "dnsPriorityHint", "allocated"), (1, "resourceLimitExchange", "reserved")),
    "envelopeFlagBits": ((0, "dnsPriority", "allocated"),),
    "requiredLimits": (
        "aggregateQueuedBytes",
        "controlReservedBytes",
        "dnsPriorityWeight",
        "idleTimeout",
        "maxAssociations",
        "maxFrame",
        "maxUDPPayload",
        "perAssociationQueuedBytes",
    ),
    "maxFrame": {"class": "negotiatedWire", "width": 4, "floor": 2048, "ceiling": 65536},
    "maxUDPPayload": {"class": "fixedWireConstant", "width": 2, "value": 1472},
}


class ToolError(Exception):
    pass


def fail(message):
    raise ToolError(message)


def repo_path(relative):
    return REPO_ROOT / relative


def canonical_dump(document):
    return json.dumps(document, ensure_ascii=True, sort_keys=True, indent=2) + "\n"


def reject_duplicate_keys(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise ValueError(f"duplicate object key {key!r}")
        seen[key] = value
    return seen


def load_schema_bytes(path):
    try:
        return path.read_bytes()
    except OSError as error:
        fail(f"cannot read schema {path}: {error}")


def parse_schema(raw, *, require_canonical):
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"schema is not UTF-8: {error}")
    try:
        document = json.loads(text, object_pairs_hook=reject_duplicate_keys)
    except ValueError as error:
        fail(f"schema is not valid JSON: {error}")
    if require_canonical and canonical_dump(document) != text:
        fail(
            "schema is not in canonical form (sorted keys, 2-space indent, "
            "ASCII, trailing newline)"
        )
    return document


# --- validation -------------------------------------------------------------


class Validator:
    def __init__(self, document):
        self.document = document
        self.errors = []

    def error(self, context, message):
        self.errors.append(f"{context}: {message}")

    def require_keys(self, context, obj, required, optional=()):
        if not isinstance(obj, dict):
            self.error(context, "expected an object")
            return False
        ok = True
        for key in required:
            if key not in obj:
                self.error(context, f'missing key "{key}"')
                ok = False
        allowed = set(required) | set(optional)
        for key in sorted(obj):
            if key not in allowed:
                self.error(context, f'unknown key "{key}"')
                ok = False
        return ok

    def require_uint(self, context, value, maximum, minimum=0):
        if not isinstance(value, int) or isinstance(value, bool):
            self.error(context, "expected an unsigned decimal integer")
            return None
        if value < minimum or value > maximum:
            self.error(context, f"value {value} exceeds bounds [{minimum}, {maximum}]")
            return None
        return value

    def require_width(self, context, value):
        if value not in WIDTH_MAX:
            self.error(context, f"width must be one of {sorted(WIDTH_MAX)}, got {value!r}")
            return None
        return value

    def require_name(self, context, value, pattern, description):
        if not isinstance(value, str) or not pattern.match(value):
            self.error(context, f"name must be {description}, got {value!r}")
            return None
        return value


def validate_fields(validator, context, fields, *, allow_semantic_names=SCREAMING_NAME):
    layout = []
    offset = 0
    if not isinstance(fields, list) or not fields:
        validator.error(context, "expected a non-empty field array")
        return layout, 0
    seen = set()
    for index, field in enumerate(fields):
        field_context = f"{context}[{index}]"
        if not validator.require_keys(field_context, field, ("name", "width")):
            continue
        name = field.get("name")
        if not isinstance(name, str) or not name:
            validator.error(field_context, "field name must be a non-empty string")
            continue
        if name in seen:
            validator.error(field_context, f"duplicate field name {name!r}")
        seen.add(name)
        width = validator.require_width(f"{field_context}.width", field.get("width"))
        if width is None:
            continue
        layout.append((name, offset, width))
        offset += width
    return layout, offset


def validate_named_values(validator, context, entries, *, width, first_value):
    values = []
    if not isinstance(entries, list) or not entries:
        validator.error(context, "expected a non-empty array")
        return values
    expected = first_value
    for index, entry in enumerate(entries):
        entry_context = f"{context}[{index}]"
        if not validator.require_keys(entry_context, entry, ("name", "value"), ("note",)):
            continue
        name = validator.require_name(
            f"{entry_context}.name", entry.get("name"), SCREAMING_NAME, "SCREAMING_SNAKE_CASE"
        )
        value = validator.require_uint(f"{entry_context}.value", entry.get("value"), WIDTH_MAX[width])
        if name is None or value is None:
            continue
        if any(name == existing for existing, _ in values):
            validator.error(entry_context, f"duplicate name {name!r}")
        if any(value == existing for _, existing in values):
            validator.error(entry_context, f"duplicate value {value}")
        if value != expected:
            validator.error(
                entry_context,
                f"values must be contiguous starting at {first_value}; expected {expected}, got {value}",
            )
        expected = value + 1
        values.append((name, value))
    return values


def validate_bits(validator, context, section, *, feature_names=(), message_names=()):
    bits = []
    if not validator.require_keys(context, section, ("width", "bits")):
        return bits, 0
    width = validator.require_width(f"{context}.width", section.get("width"))
    entries = section.get("bits")
    if not isinstance(entries, list):
        validator.error(f"{context}.bits", "expected an array")
        return bits, width or 0
    seen_bits = set()
    seen_names = set()
    for index, entry in enumerate(entries):
        entry_context = f"{context}.bits[{index}]"
        if not validator.require_keys(
            entry_context,
            entry,
            ("bit", "name", "status"),
            ("note", "gatedByFeature", "validOnMessage", "validDirection"),
        ):
            continue
        maximum_bit = (width or 4) * 8 - 1
        bit = validator.require_uint(f"{entry_context}.bit", entry.get("bit"), maximum_bit)
        name = validator.require_name(
            f"{entry_context}.name", entry.get("name"), CAMEL_NAME, "lowerCamelCase"
        )
        status = entry.get("status")
        if status not in BIT_STATUSES:
            validator.error(f"{entry_context}.status", f"status must be one of {BIT_STATUSES}")
            status = None
        if bit is None or name is None or status is None:
            continue
        if bit in seen_bits:
            validator.error(entry_context, f"duplicate bit {bit}")
        if name in seen_names:
            validator.error(entry_context, f"duplicate bit name {name!r}")
        seen_bits.add(bit)
        seen_names.add(name)
        gated = entry.get("gatedByFeature", "")
        valid_message = entry.get("validOnMessage", "")
        valid_direction = entry.get("validDirection", "")
        if gated and gated not in feature_names:
            validator.error(f"{entry_context}.gatedByFeature", f"unknown feature {gated!r}")
        if valid_message and valid_message not in message_names:
            validator.error(f"{entry_context}.validOnMessage", f"unknown message type {valid_message!r}")
        if valid_direction and valid_direction not in DIRECTIONS:
            validator.error(f"{entry_context}.validDirection", f"unknown direction {valid_direction!r}")
        bits.append(
            {
                "bit": bit,
                "name": name,
                "status": status,
                "gatedByFeature": gated,
                "validOnMessage": valid_message,
                "validDirection": valid_direction,
            }
        )
    bits.sort(key=lambda entry: entry["bit"])
    return bits, width or 0


def validate_schema(document):
    """Validate a parsed schema document. Returns (model, errors)."""
    validator = Validator(document)
    top_level = (
        "addressTypes",
        "compatibility",
        "envelope",
        "envelopeFlags",
        "features",
        "hello",
        "helloFlags",
        "helloStatuses",
        "hevRecord",
        "limits",
        "magic",
        "messageTypes",
        "protocol",
        "reservedMessageTypeRanges",
        "schemaFormatVersion",
        "udpErrorCodes",
    )
    if not validator.require_keys("schema", document, top_level):
        return None, validator.errors

    model = {}

    schema_format = validator.require_uint(
        "schemaFormatVersion", document.get("schemaFormatVersion"), 0xFFFF, minimum=1
    )
    if schema_format != GENERATOR_FORMAT_VERSION:
        validator.error(
            "schemaFormatVersion",
            f"generator format {GENERATOR_FORMAT_VERSION} cannot consume schema format {schema_format}",
        )

    protocol = document.get("protocol", {})
    if validator.require_keys("protocol", protocol, ("name", "wireVersion", "byteOrder")):
        if protocol.get("byteOrder") != "big-endian":
            validator.error("protocol.byteOrder", 'must be "big-endian"')
        validator.require_uint("protocol.wireVersion", protocol.get("wireVersion"), 0xFFFF, minimum=1)
        if not isinstance(protocol.get("name"), str) or not protocol.get("name"):
            validator.error("protocol.name", "must be a non-empty string")
    model["protocolName"] = protocol.get("name", "")
    model["wireVersion"] = protocol.get("wireVersion", 0)
    model["byteOrder"] = protocol.get("byteOrder", "")

    magic = document.get("magic", {})
    magic_ascii = ""
    if validator.require_keys("magic", magic, ("ascii",)):
        magic_ascii = magic.get("ascii")
        if (
            not isinstance(magic_ascii, str)
            or len(magic_ascii) != 4
            or not all(32 < ord(ch) < 127 for ch in magic_ascii)
        ):
            validator.error("magic.ascii", "must be exactly 4 printable ASCII characters")
            magic_ascii = ""
    model["magicASCII"] = magic_ascii
    model["magicBytes"] = [ord(ch) for ch in magic_ascii]

    compatibility = document.get("compatibility", {})
    if validator.require_keys("compatibility", compatibility, ("class",), ("note",)):
        if compatibility.get("class") != "v1-frozen":
            validator.error("compatibility.class", 'must be "v1-frozen" for wire version 1')

    hello = document.get("hello", {})
    client_layout = server_layout = []
    client_width = server_width = 0
    if validator.require_keys("hello", hello, ("client", "server")):
        client = hello.get("client", {})
        server = hello.get("server", {})
        if validator.require_keys("hello.client", client, ("fields",)):
            client_layout, client_width = validate_fields(
                validator, "hello.client.fields", client.get("fields")
            )
        if validator.require_keys("hello.server", server, ("fields",)):
            server_layout, server_width = validate_fields(
                validator, "hello.server.fields", server.get("fields")
            )
    model["clientHelloLayout"] = client_layout
    model["clientHelloWidth"] = client_width
    model["serverHelloLayout"] = server_layout
    model["serverHelloWidth"] = server_width

    model["helloStatuses"] = validate_named_values(
        validator, "helloStatuses", document.get("helloStatuses"), width=2, first_value=0
    )

    envelope = document.get("envelope", {})
    prefix = ("", 0)
    header_layout = []
    header_width = 0
    if validator.require_keys("envelope", envelope, ("prefix", "headerFields", "lengthCoverage")):
        prefix_obj = envelope.get("prefix", {})
        if validator.require_keys("envelope.prefix", prefix_obj, ("name", "width")):
            width = validator.require_width("envelope.prefix.width", prefix_obj.get("width"))
            prefix = (prefix_obj.get("name", ""), width or 0)
        header_layout, header_width = validate_fields(
            validator, "envelope.headerFields", envelope.get("headerFields")
        )
        if envelope.get("lengthCoverage") != "type-through-payload":
            validator.error("envelope.lengthCoverage", 'must be "type-through-payload"')
    model["envelopePrefix"] = prefix
    model["envelopeHeaderLayout"] = header_layout
    model["envelopeHeaderWidth"] = header_width
    model["lengthCoverage"] = envelope.get("lengthCoverage", "")

    message_types = []
    entries = document.get("messageTypes")
    if not isinstance(entries, list) or not entries:
        validator.error("messageTypes", "expected a non-empty array")
        entries = []
    previous_value = -1
    for index, entry in enumerate(entries):
        context = f"messageTypes[{index}]"
        if not validator.require_keys(
            context, entry, ("name", "value", "direction", "associationID", "payload"), ("note",)
        ):
            continue
        name = validator.require_name(
            f"{context}.name", entry.get("name"), SCREAMING_NAME, "SCREAMING_SNAKE_CASE"
        )
        value = validator.require_uint(f"{context}.value", entry.get("value"), WIDTH_MAX[1])
        direction = entry.get("direction")
        association = entry.get("associationID")
        if direction not in DIRECTIONS:
            validator.error(f"{context}.direction", f"direction must be one of {DIRECTIONS}")
            direction = None
        if association not in ASSOCIATION_RULES:
            validator.error(f"{context}.associationID", f"must be one of {ASSOCIATION_RULES}")
            association = None
        payload = entry.get("payload")
        shape = None
        fixed_width = -1
        if isinstance(payload, dict) and payload.get("shape") == "hevUDPRecord":
            if validator.require_keys(f"{context}.payload", payload, ("shape",)):
                shape = "hevUDPRecord"
        elif isinstance(payload, dict) and payload.get("shape") == "fixed":
            if validator.require_keys(f"{context}.payload", payload, ("shape", "width")):
                fixed = validator.require_uint(
                    f"{context}.payload.width", payload.get("width"), WIDTH_MAX[2]
                )
                if fixed is not None:
                    shape = "fixed"
                    fixed_width = fixed
        else:
            validator.error(f"{context}.payload", 'shape must be "fixed" or "hevUDPRecord"')
        if None in (name, value, direction, association) or shape is None:
            continue
        if any(name == m["name"] for m in message_types):
            validator.error(context, f"duplicate message type name {name!r}")
        if any(value == m["value"] for m in message_types):
            validator.error(context, f"duplicate message type value {value}")
        if value <= previous_value:
            validator.error(context, "message types must be sorted by ascending value")
        previous_value = value
        message_types.append(
            {
                "name": name,
                "value": value,
                "direction": direction,
                "associationID": association,
                "shape": shape,
                "fixedWidth": fixed_width,
            }
        )
    model["messageTypes"] = message_types
    message_names = tuple(m["name"] for m in message_types)

    reserved_ranges = []
    entries = document.get("reservedMessageTypeRanges")
    if not isinstance(entries, list):
        validator.error("reservedMessageTypeRanges", "expected an array")
        entries = []
    for index, entry in enumerate(entries):
        context = f"reservedMessageTypeRanges[{index}]"
        if not validator.require_keys(context, entry, ("first", "last", "purpose"), ("note",)):
            continue
        first = validator.require_uint(f"{context}.first", entry.get("first"), WIDTH_MAX[1])
        last = validator.require_uint(f"{context}.last", entry.get("last"), WIDTH_MAX[1])
        purpose = entry.get("purpose")
        if not isinstance(purpose, str) or not purpose:
            validator.error(f"{context}.purpose", "must be a non-empty string")
            purpose = ""
        if first is None or last is None:
            continue
        if first > last:
            validator.error(context, f"invalid range: first {first} > last {last}")
        for message in message_types:
            if first <= message["value"] <= last:
                validator.error(
                    context,
                    f"range [{first}, {last}] overlaps allocated message type {message['name']}",
                )
        for other_first, other_last, _ in reserved_ranges:
            if first <= other_last and other_first <= last:
                validator.error(context, "overlapping reserved ranges")
        reserved_ranges.append((first, last, purpose))
    model["reservedMessageTypeRanges"] = reserved_ranges

    address_types = []
    entries = document.get("addressTypes")
    if not isinstance(entries, list) or not entries:
        validator.error("addressTypes", "expected a non-empty array")
        entries = []
    previous_value = -1
    for index, entry in enumerate(entries):
        context = f"addressTypes[{index}]"
        if not validator.require_keys(
            context,
            entry,
            ("name", "value", "lengthPrefixed", "minAddressBytes", "maxAddressBytes"),
            ("note",),
        ):
            continue
        name = validator.require_name(
            f"{context}.name", entry.get("name"), SCREAMING_NAME, "SCREAMING_SNAKE_CASE"
        )
        value = validator.require_uint(f"{context}.value", entry.get("value"), WIDTH_MAX[1])
        prefixed = entry.get("lengthPrefixed")
        minimum = validator.require_uint(f"{context}.minAddressBytes", entry.get("minAddressBytes"), WIDTH_MAX[1], minimum=1)
        maximum = validator.require_uint(f"{context}.maxAddressBytes", entry.get("maxAddressBytes"), WIDTH_MAX[1], minimum=1)
        if not isinstance(prefixed, bool):
            validator.error(f"{context}.lengthPrefixed", "must be a boolean")
            prefixed = None
        if None in (name, value, minimum, maximum) or prefixed is None:
            continue
        if minimum > maximum:
            validator.error(context, f"invalid range: minAddressBytes {minimum} > maxAddressBytes {maximum}")
        if not prefixed and minimum != maximum:
            validator.error(context, "fixed-width address types require minAddressBytes == maxAddressBytes")
        if any(value == a["value"] for a in address_types):
            validator.error(context, f"duplicate address type value {value}")
        if any(name == a["name"] for a in address_types):
            validator.error(context, f"duplicate address type name {name!r}")
        if value <= previous_value:
            validator.error(context, "address types must be sorted by ascending value")
        previous_value = value
        address_types.append(
            {
                "name": name,
                "value": value,
                "lengthPrefixed": prefixed,
                "min": minimum,
                "max": maximum,
            }
        )
    model["addressTypes"] = address_types

    hev = document.get("hevRecord", {})
    hev_prefix_layout = []
    hev_prefix_width = 0
    port_width = 0
    if validator.require_keys("hevRecord", hev, ("fixedPrefixFields", "portWidth", "msglenLimit")):
        hev_prefix_layout, hev_prefix_width = validate_fields(
            validator, "hevRecord.fixedPrefixFields", hev.get("fixedPrefixFields")
        )
        port_width = validator.require_width("hevRecord.portWidth", hev.get("portWidth")) or 0
    model["hevFixedPrefixLayout"] = hev_prefix_layout
    model["hevHeaderBaseWidth"] = hev_prefix_width + port_width
    model["hevPortWidth"] = port_width

    model["udpErrorCodes"] = validate_named_values(
        validator, "udpErrorCodes", document.get("udpErrorCodes"), width=2, first_value=1
    )

    limits = []
    entries = document.get("limits")
    if not isinstance(entries, list) or not entries:
        validator.error("limits", "expected a non-empty array")
        entries = []
    previous_name = ""
    for index, entry in enumerate(entries):
        context = f"limits[{index}]"
        if not validator.require_keys(
            context,
            entry,
            (
                "name",
                "class",
                "width",
                "unit",
                "clientDefault",
                "relayDefault",
                "floor",
                "clientHardCeiling",
                "relayHardCeiling",
            ),
            ("note",),
        ):
            continue
        name = validator.require_name(f"{context}.name", entry.get("name"), CAMEL_NAME, "lowerCamelCase")
        limit_class = entry.get("class")
        if limit_class not in LIMIT_CLASSES:
            validator.error(f"{context}.class", f"class must be one of {LIMIT_CLASSES}")
            limit_class = None
        width = validator.require_width(f"{context}.width", entry.get("width"))
        unit = entry.get("unit")
        if not isinstance(unit, str) or not CAMEL_NAME.match(unit):
            validator.error(f"{context}.unit", f"unit must be lowerCamelCase, got {unit!r}")
            unit = None
        if None in (name, limit_class, width, unit):
            continue
        bound = WIDTH_MAX[width]
        values = {}
        for key in ("clientDefault", "relayDefault", "floor", "clientHardCeiling", "relayHardCeiling"):
            values[key] = validator.require_uint(f"{context}.{key}", entry.get(key), bound)
        if any(value is None for value in values.values()):
            continue
        floor = values["floor"]
        for peer, default_key, ceiling_key in (
            ("client", "clientDefault", "clientHardCeiling"),
            ("relay", "relayDefault", "relayHardCeiling"),
        ):
            default = values[default_key]
            ceiling = values[ceiling_key]
            if floor > ceiling:
                validator.error(context, f"floor {floor} exceeds {peer} hard ceiling {ceiling}")
            elif not floor <= default <= ceiling:
                validator.error(
                    context,
                    f"{peer} default {default} outside [floor {floor}, ceiling {ceiling}]",
                )
        if limit_class == "fixedWireConstant" and not (
            values["clientDefault"]
            == values["relayDefault"]
            == values["clientHardCeiling"]
            == values["relayHardCeiling"]
        ):
            validator.error(
                context,
                "fixedWireConstant requires clientDefault == relayDefault == both hard ceilings",
            )
        if any(name == limit["name"] for limit in limits):
            validator.error(context, f"duplicate limit name {name!r}")
        if name <= previous_name:
            validator.error(context, "limits must be sorted by ascending name")
        previous_name = name
        limits.append(
            {
                "name": name,
                "class": limit_class,
                "width": width,
                "unit": unit,
                "clientDefault": values["clientDefault"],
                "relayDefault": values["relayDefault"],
                "floor": floor,
                "clientHardCeiling": values["clientHardCeiling"],
                "relayHardCeiling": values["relayHardCeiling"],
            }
        )
    model["limits"] = limits
    limits_by_name = {limit["name"]: limit for limit in limits}

    if isinstance(hev, dict) and "msglenLimit" in hev:
        msglen_limit = hev.get("msglenLimit")
        referenced = limits_by_name.get(msglen_limit)
        if referenced is None:
            validator.error("hevRecord.msglenLimit", f"undeclared limit {msglen_limit!r}")
        elif referenced["class"] != "fixedWireConstant":
            validator.error("hevRecord.msglenLimit", "must reference a fixedWireConstant limit")
        model["msglenLimit"] = msglen_limit

    feature_names = ()
    features_section = document.get("features", {})
    if isinstance(features_section, dict) and isinstance(features_section.get("bits"), list):
        feature_names = tuple(
            bit.get("name")
            for bit in features_section["bits"]
            if isinstance(bit, dict) and bit.get("status") == "allocated"
        )
    model["helloFlagBits"], model["helloFlagsWidth"] = validate_bits(
        validator, "helloFlags", document.get("helloFlags", {})
    )
    model["featureBits"], model["featuresWidth"] = validate_bits(
        validator, "features", document.get("features", {})
    )
    model["envelopeFlagBits"], model["envelopeFlagsWidth"] = validate_bits(
        validator,
        "envelopeFlags",
        document.get("envelopeFlags", {}),
        feature_names=feature_names,
        message_names=message_names,
    )

    if validator.errors:
        return None, validator.errors

    derive_model(validator, model)
    if model["wireVersion"] == 1:
        check_frozen_v1(validator, model)
    if validator.errors:
        return None, validator.errors
    return model, []


def derive_model(validator, model):
    """Compute derived constants and cross-checks after structural validation."""
    limits = {limit["name"]: limit for limit in model["limits"]}

    max_udp_payload = limits.get("maxUDPPayload", {}).get("clientDefault", 0)
    max_hdrlen = 0
    for address in model["addressTypes"]:
        address_field = address["max"] + (1 if address["lengthPrefixed"] else 0)
        hdrlen = model["hevHeaderBaseWidth"] + address_field
        address["hdrlen"] = hdrlen
        max_hdrlen = max(max_hdrlen, hdrlen)
        if hdrlen > WIDTH_MAX[1]:
            validator.error(
                f"addressTypes {address['name']}",
                f"HDRLEN {hdrlen} exceeds the one-byte HDRLEN field",
            )
    model["maxHEVRecordWidth"] = max_hdrlen + max_udp_payload
    model["minFrameLength"] = model["envelopeHeaderWidth"]
    model["maxLegalFrameBody"] = model["envelopeHeaderWidth"] + model["maxHEVRecordWidth"]

    domain = next((a for a in model["addressTypes"] if a["lengthPrefixed"]), None)
    model["minDomainWireBytes"] = domain["min"] if domain else 0
    model["maxDomainWireBytes"] = domain["max"] if domain else 0

    max_frame = limits.get("maxFrame")
    if max_frame and model["maxLegalFrameBody"] > max_frame["floor"]:
        validator.error(
            "limits maxFrame",
            f"floor {max_frame['floor']} is below the maximum legal frame body "
            f"{model['maxLegalFrameBody']}; every accepted hello must carry every legal frame",
        )

    udp_error = next((m for m in model["messageTypes"] if m["name"] == "UDP_ERROR"), None)
    if udp_error and udp_error["fixedWidth"] != 2:
        validator.error(
            "messageTypes UDP_ERROR", "payload must be exactly the two-byte error code"
        )

    def reserved_mask(bits, width):
        mask = WIDTH_MAX[width]
        for bit in bits:
            if bit["status"] == "allocated":
                mask &= ~(1 << bit["bit"])
        return mask

    model["helloFlagsReservedMask"] = reserved_mask(model["helloFlagBits"], model["helloFlagsWidth"])
    model["featuresReservedMask"] = reserved_mask(model["featureBits"], model["featuresWidth"])
    model["envelopeFlagsReservedMask"] = reserved_mask(
        model["envelopeFlagBits"], model["envelopeFlagsWidth"]
    )


def check_frozen_v1(validator, model):
    """Reject backward-incompatible edits to the frozen v1 wire surface."""

    def frozen_error(message):
        validator.error("frozen-v1", f"incompatible v1 edit: {message} (requires a wireVersion bump)")

    if model["magicASCII"] != FROZEN_V1["magicASCII"]:
        frozen_error(f"magic changed to {model['magicASCII']!r}")
    for peer, key in (("client", "clientHelloLayout"), ("server", "serverHelloLayout")):
        actual = tuple((name, width) for name, _, width in model[key])
        if actual != FROZEN_V1[f"{peer}HelloFields"]:
            frozen_error(f"{peer} hello layout changed")
    if (model["envelopePrefix"][0], model["envelopePrefix"][1]) != FROZEN_V1["envelopePrefix"]:
        frozen_error("envelope length prefix changed")
    actual_header = tuple((name, width) for name, _, width in model["envelopeHeaderLayout"])
    if actual_header != FROZEN_V1["envelopeHeaderFields"]:
        frozen_error("envelope header layout changed")

    statuses = tuple((value, name) for name, value in model["helloStatuses"])
    if statuses[: len(FROZEN_V1["helloStatuses"])] != FROZEN_V1["helloStatuses"]:
        frozen_error("hello status vocabulary changed")

    actual_messages = tuple(
        (
            m["value"],
            m["name"],
            m["direction"],
            m["associationID"],
            m["shape"],
            None if m["fixedWidth"] < 0 else m["fixedWidth"],
        )
        for m in model["messageTypes"]
    )
    if actual_messages != FROZEN_V1["messageTypes"]:
        frozen_error("allocated message type table changed")

    actual_ranges = tuple(model["reservedMessageTypeRanges"])
    if actual_ranges != FROZEN_V1["reservedMessageTypeRanges"]:
        frozen_error("reserved message type ranges changed")

    actual_addresses = tuple(
        (a["value"], a["name"], a["lengthPrefixed"], a["min"], a["max"])
        for a in model["addressTypes"]
    )
    if actual_addresses != FROZEN_V1["addressTypes"]:
        frozen_error("address type table changed")

    errors = tuple((value, name) for name, value in model["udpErrorCodes"])
    if errors[: len(FROZEN_V1["udpErrorCodes"])] != FROZEN_V1["udpErrorCodes"]:
        frozen_error("existing UDP error codes changed")

    for key, frozen_key in (
        ("helloFlagBits", "helloFlagBits"),
        ("featureBits", "featureBits"),
        ("envelopeFlagBits", "envelopeFlagBits"),
    ):
        actual_bits = tuple((b["bit"], b["name"], b["status"]) for b in model[key])
        if actual_bits != FROZEN_V1[frozen_key]:
            frozen_error(f"{key} assignments changed")

    limits = {limit["name"]: limit for limit in model["limits"]}
    for name in FROZEN_V1["requiredLimits"]:
        if name not in limits:
            frozen_error(f"required limit {name!r} missing")
    max_frame = limits.get("maxFrame")
    frozen_frame = FROZEN_V1["maxFrame"]
    if max_frame and (
        max_frame["class"] != frozen_frame["class"]
        or max_frame["width"] != frozen_frame["width"]
        or max_frame["floor"] != frozen_frame["floor"]
        or max_frame["clientHardCeiling"] != frozen_frame["ceiling"]
        or max_frame["relayHardCeiling"] != frozen_frame["ceiling"]
    ):
        frozen_error("maxFrame wire acceptance range changed")
    max_payload = limits.get("maxUDPPayload")
    frozen_payload = FROZEN_V1["maxUDPPayload"]
    if max_payload and (
        max_payload["class"] != frozen_payload["class"]
        or max_payload["width"] != frozen_payload["width"]
        or max_payload["clientDefault"] != frozen_payload["value"]
    ):
        frozen_error("maxUDPPayload fixed wire constant changed")


# --- identifier derivation --------------------------------------------------


def screaming_to_camel(name):
    parts = name.lower().split("_")
    return parts[0] + "".join(part.capitalize() for part in parts[1:])


def screaming_to_pascal(name):
    parts = name.lower().split("_")
    return "".join(INITIALISMS.get(part, part.capitalize()) for part in parts)


def camel_to_pascal(name):
    words = CAMEL_WORD.findall(name)
    return "".join(INITIALISMS.get(word.lower(), word[:1].upper() + word[1:]) for word in words)


def hex_literal(value, width):
    return f"0x{value:0{width * 2}X}"


def swift_uint_type(width):
    return {1: "UInt8", 2: "UInt16", 4: "UInt32"}[width]


def go_uint_type(width):
    return {1: "uint8", 2: "uint16", 4: "uint32"}[width]


def swift_decimal(value):
    """Decimal literal for Swift sources, grouped per the repo swift-format rules."""
    text = str(value)
    if len(text) < 7:
        return text
    groups = []
    while text:
        groups.insert(0, text[-3:])
        text = text[:-3]
    return "_".join(groups)


def swift_hex(value, width):
    """Hex literal for Swift sources, grouped per the repo swift-format rules."""
    digits = f"{value:0{width * 2}X}"
    if len(digits) >= 8:
        digits = "_".join(digits[index : index + 4] for index in range(0, len(digits), 4))
    return "0x" + digits


def chunk_parity_line(line, max_content=86):
    """Split a parity line at spaces so emitted Swift string pieces stay short."""
    words = line.split(" ")
    chunks = []
    current = words[0]
    for word in words[1:]:
        if len(current) + 1 + len(word) + 1 > max_content:
            chunks.append(current + " ")
            current = word
        else:
            current += " " + word
    chunks.append(current)
    return chunks


def swift_struct_literal(out, indent, type_name, fields, trailing=","):
    out.append(f"{indent}{type_name}(")
    for index, (label, value) in enumerate(fields):
        comma = "," if index < len(fields) - 1 else ""
        out.append(f"{indent}  {label}: {value}{comma}")
    out.append(f"{indent}){trailing}")


# --- parity fingerprint -----------------------------------------------------


def parity_lines(model):
    lines = [
        f"protocol name={model['protocolName']} wireVersion={model['wireVersion']} "
        f"byteOrder={model['byteOrder']} magic={model['magicASCII']}"
    ]
    for peer, key in (("client", "clientHelloLayout"), ("server", "serverHelloLayout")):
        for name, offset, width in model[key]:
            lines.append(f"helloField peer={peer} name={name} offset={offset} width={width}")
    lines.append(
        f"helloWidth client={model['clientHelloWidth']} server={model['serverHelloWidth']}"
    )
    prefix_name, prefix_width = model["envelopePrefix"]
    lines.append(f"envelopeField name={prefix_name} offset=0 width={prefix_width}")
    for name, offset, width in model["envelopeHeaderLayout"]:
        lines.append(f"envelopeField name={name} offset={prefix_width + offset} width={width}")
    lines.append(
        f"envelope prefixWidth={prefix_width} headerWidth={model['envelopeHeaderWidth']} "
        f"lengthCoverage={model['lengthCoverage']} minFrameLength={model['minFrameLength']} "
        f"maxLegalFrameBody={model['maxLegalFrameBody']}"
    )
    for name, value in model["helloStatuses"]:
        lines.append(f"helloStatus name={name} value={value}")

    def bit_lines(label, bits, mask_label, mask):
        for bit in bits:
            lines.append(
                f"{label} bit={bit['bit']} name={bit['name']} status={bit['status']} "
                f"validOnMessage={bit['validOnMessage'] or '-'} "
                f"validDirection={bit['validDirection'] or '-'} "
                f"gatedByFeature={bit['gatedByFeature'] or '-'}"
            )
        lines.append(f"{mask_label} value={mask}")

    bit_lines("helloFlagBit", model["helloFlagBits"], "helloFlagsReservedMask", model["helloFlagsReservedMask"])
    bit_lines("featureBit", model["featureBits"], "featuresReservedMask", model["featuresReservedMask"])
    bit_lines(
        "envelopeFlagBit",
        model["envelopeFlagBits"],
        "envelopeFlagsReservedMask",
        model["envelopeFlagsReservedMask"],
    )
    for message in model["messageTypes"]:
        lines.append(
            f"messageType name={message['name']} value={message['value']} "
            f"direction={message['direction']} association={message['associationID']} "
            f"payload={message['shape']} fixedPayloadWidth={message['fixedWidth']}"
        )
    for first, last, purpose in model["reservedMessageTypeRanges"]:
        lines.append(f"reservedMessageTypeRange first={first} last={last} purpose={purpose}")
    for address in model["addressTypes"]:
        prefixed = "true" if address["lengthPrefixed"] else "false"
        lines.append(
            f"addressType name={address['name']} value={address['value']} "
            f"lengthPrefixed={prefixed} min={address['min']} max={address['max']}"
        )
    for name, offset, width in model["hevFixedPrefixLayout"]:
        lines.append(f"hevField name={name} offset={offset} width={width}")
    hdrlens = {a["name"]: a["hdrlen"] for a in model["addressTypes"]}
    lines.append(
        f"hev headerBaseWidth={model['hevHeaderBaseWidth']} portWidth={model['hevPortWidth']} "
        f"hdrlenIPv4={hdrlens.get('IPV4', 0)} hdrlenIPv6={hdrlens.get('IPV6', 0)} "
        f"hdrlenDomainBase={model['hevHeaderBaseWidth'] + 1} "
        f"minDomainWireBytes={model['minDomainWireBytes']} "
        f"maxDomainWireBytes={model['maxDomainWireBytes']} "
        f"maxRecordWidth={model['maxHEVRecordWidth']}"
    )
    for name, value in model["udpErrorCodes"]:
        lines.append(f"udpErrorCode name={name} value={value}")
    for limit in model["limits"]:
        lines.append(
            f"limit name={limit['name']} class={limit['class']} width={limit['width']} "
            f"unit={limit['unit']} clientDefault={limit['clientDefault']} "
            f"relayDefault={limit['relayDefault']} floor={limit['floor']} "
            f"clientHardCeiling={limit['clientHardCeiling']} "
            f"relayHardCeiling={limit['relayHardCeiling']}"
        )
    return lines


def parity_digest(lines):
    return hashlib.sha256(("\n".join(lines) + "\n").encode("utf-8")).hexdigest()


# --- Swift emission ---------------------------------------------------------


def header_lines(comment, schema_digest):
    return [
        f"{comment} Generated by scripts/relay-protocol-tool.py. DO NOT EDIT.",
        f"{comment} Manual edits are forbidden; `make relay-protocol-check` rejects drift.",
        f"{comment} Source-Schema: {SCHEMA_PATH}",
        f"{comment} Schema-SHA256: {schema_digest}",
        f"{comment} Generator-Format-Version: {GENERATOR_FORMAT_VERSION}",
        f"{comment} Regenerate: {REGENERATE_COMMAND}",
    ]


def emit_swift(model, schema_digest):
    lines = parity_lines(model)
    digest = parity_digest(lines)
    hdrlens = {a["name"]: a["hdrlen"] for a in model["addressTypes"]}
    out = header_lines("//", schema_digest)
    out += [
        "",
        "/// Relay protocol v1 wire constants and typed metadata generated from the",
        "/// canonical schema. Handwritten code must not restate these values.",
        "///",
        "/// Semantics: TASK-260715-111tde (binding ADR) and TASK-260715-18owh7 (limits).",
        "public enum RelayProtocolV1 {",
        "  // MARK: - Supporting types",
        "",
        "  public struct WireField: Sendable {",
        "    public let name: String",
        "    public let byteOffset: Int",
        "    public let byteWidth: Int",
        "  }",
        "",
        "  public struct NamedValue: Sendable {",
        "    public let name: String",
        "    public let value: UInt64",
        "  }",
        "",
        "  public struct BitAssignment: Sendable {",
        "    public let bit: Int",
        "    public let name: String",
        "    public let isAllocated: Bool",
        "    public let validOnMessage: String",
        "    public let validDirection: String",
        "    public let gatedByFeature: String",
        "  }",
        "",
        "  public enum MessageDirection: String, CaseIterable, Sendable {",
        "    case clientToRelay",
        "    case relayToClient",
        "    case both",
        "  }",
        "",
        "  public enum AssociationIDRule: String, CaseIterable, Sendable {",
        "    case zero",
        "    case nonzero",
        "  }",
        "",
        "  public enum PayloadShape: String, CaseIterable, Sendable {",
        "    case fixed",
        "    case hevUDPRecord",
        "  }",
        "",
        "  public struct MessageMetadata: Sendable {",
        "    public let type: MessageType",
        "    public let name: String",
        "    public let direction: MessageDirection",
        "    public let associationID: AssociationIDRule",
        "    public let payloadShape: PayloadShape",
        "    /// Exact payload byte count for fixed shapes; -1 for variable payloads.",
        "    public let fixedPayloadWidth: Int",
        "  }",
        "",
        "  public struct AddressTypeMetadata: Sendable {",
        "    public let type: AddressType",
        "    public let name: String",
        "    public let isLengthPrefixed: Bool",
        "    public let minAddressBytes: Int",
        "    public let maxAddressBytes: Int",
        "  }",
        "",
        "  public enum LimitClass: String, CaseIterable, Sendable {",
        "    case negotiatedWire",
        "    case fixedWireConstant",
        "    case localCap",
        "  }",
        "",
        "  public struct LimitSpec: Sendable {",
        "    public let name: String",
        "    public let limitClass: LimitClass",
        "    public let byteWidth: Int",
        "    public let unit: String",
        "    public let clientDefault: UInt64",
        "    public let relayDefault: UInt64",
        "    public let floor: UInt64",
        "    public let clientHardCeiling: UInt64",
        "    public let relayHardCeiling: UInt64",
        "  }",
        "",
        "  public struct ReservedMessageTypeRange: Sendable {",
        "    public let first: UInt8",
        "    public let last: UInt8",
        "    public let purpose: String",
        "  }",
        "",
        "  // MARK: - Protocol identity",
        "",
        f"  public static let protocolName = \"{model['protocolName']}\"",
        f"  public static let wireVersion: UInt16 = {model['wireVersion']}",
        f"  public static let byteOrder = \"{model['byteOrder']}\"",
        f"  public static let magicASCII = \"{model['magicASCII']}\"",
        "  public static let magic: [UInt8] = ["
        + ", ".join(hex_literal(byte, 1) for byte in model["magicBytes"])
        + "]",
        "",
        "  // MARK: - Generation provenance",
        "",
        "  public static let schemaSHA256 =",
        f"    \"{schema_digest}\"",
        f"  public static let generatorFormatVersion = {GENERATOR_FORMAT_VERSION}",
        "",
        "  // MARK: - Hello layout",
        "",
    ]
    for swift_name, key in (
        ("clientHelloLayout", "clientHelloLayout"),
        ("serverHelloLayout", "serverHelloLayout"),
    ):
        out.append(f"  public static let {swift_name}: [WireField] = [")
        for name, offset, width in model[key]:
            out.append(
                f"    WireField(name: \"{name}\", byteOffset: {offset}, byteWidth: {width}),"
            )
        out.append("  ]")
        out.append("")
    out += [
        f"  public static let clientHelloWidth = {model['clientHelloWidth']}",
        f"  public static let serverHelloWidth = {model['serverHelloWidth']}",
        "",
        "  public enum HelloStatus: UInt16, CaseIterable, Sendable {",
    ]
    for name, value in model["helloStatuses"]:
        out.append(f"    case {screaming_to_camel(name)} = {hex_literal(value, 2)}")
    out += [
        "  }",
        "",
        "  public static let helloStatusNames: [NamedValue] = [",
    ]
    for name, value in model["helloStatuses"]:
        out.append(f"    NamedValue(name: \"{name}\", value: {value}),")
    out += [
        "  ]",
        "",
        "  // MARK: - Hello flags and features",
        "",
    ]

    def swift_bits(prefix, bits, mask_name, mask, width, array_name):
        for bit in bits:
            if bit["status"] == "allocated":
                constant = f"{prefix}{camel_to_pascal(bit['name'])}"
                out.append(
                    f"  public static let {constant}: {swift_uint_type(width)} = "
                    f"{swift_hex(1 << bit['bit'], width)}"
                )
        out.append(
            f"  public static let {mask_name}: {swift_uint_type(width)} = {swift_hex(mask, width)}"
        )
        out.append(f"  public static let {array_name}: [BitAssignment] = [")
        for bit in bits:
            allocated = "true" if bit["status"] == "allocated" else "false"
            swift_struct_literal(
                out,
                "    ",
                "BitAssignment",
                (
                    ("bit", str(bit["bit"])),
                    ("name", f"\"{bit['name']}\""),
                    ("isAllocated", allocated),
                    ("validOnMessage", f"\"{bit['validOnMessage']}\""),
                    ("validDirection", f"\"{bit['validDirection']}\""),
                    ("gatedByFeature", f"\"{bit['gatedByFeature']}\""),
                ),
                trailing="," if len(bits) > 1 else "",
            )
        out.append("  ]")

    swift_bits(
        "helloFlag",
        model["helloFlagBits"],
        "helloFlagsReservedMask",
        model["helloFlagsReservedMask"],
        model["helloFlagsWidth"],
        "helloFlagAssignments",
    )
    out.append("")
    swift_bits(
        "feature",
        model["featureBits"],
        "featuresReservedMask",
        model["featuresReservedMask"],
        model["featuresWidth"],
        "featureAssignments",
    )
    out += [
        "",
        "  // MARK: - Envelope layout",
        "",
        f"  public static let framePrefixWidth = {model['envelopePrefix'][1]}",
        "  public static let envelopeLayout: [WireField] = [",
        f"    WireField(name: \"{model['envelopePrefix'][0]}\", byteOffset: 0, "
        f"byteWidth: {model['envelopePrefix'][1]}),",
    ]
    for name, offset, width in model["envelopeHeaderLayout"]:
        out.append(
            f"    WireField(name: \"{name}\", byteOffset: {model['envelopePrefix'][1] + offset}, "
            f"byteWidth: {width}),"
        )
    out += [
        "  ]",
        f"  public static let envelopeHeaderWidth = {model['envelopeHeaderWidth']}",
        f"  public static let envelopeLengthCoverage = \"{model['lengthCoverage']}\"",
        f"  public static let minFrameLength: UInt32 = {model['minFrameLength']}",
        f"  public static let maxLegalFrameBody: UInt32 = {model['maxLegalFrameBody']}",
        "",
    ]
    swift_bits(
        "envelopeFlag",
        model["envelopeFlagBits"],
        "envelopeFlagsReservedMask",
        model["envelopeFlagsReservedMask"],
        model["envelopeFlagsWidth"],
        "envelopeFlagAssignments",
    )
    out += [
        "",
        "  // MARK: - Message types",
        "",
        "  public enum MessageType: UInt8, CaseIterable, Sendable {",
    ]
    for message in model["messageTypes"]:
        out.append(f"    case {screaming_to_camel(message['name'])} = {hex_literal(message['value'], 1)}")
    out += [
        "  }",
        "",
        "  public static let messageMetadata: [MessageMetadata] = [",
    ]
    for message in model["messageTypes"]:
        swift_struct_literal(
            out,
            "    ",
            "MessageMetadata",
            (
                ("type", f".{screaming_to_camel(message['name'])}"),
                ("name", f"\"{message['name']}\""),
                ("direction", f".{message['direction']}"),
                ("associationID", f".{message['associationID']}"),
                ("payloadShape", f".{message['shape']}"),
                ("fixedPayloadWidth", str(message["fixedWidth"])),
            ),
        )
    out += [
        "  ]",
        "",
        "  public static let reservedMessageTypeRanges: [ReservedMessageTypeRange] = [",
    ]
    for first, last, purpose in model["reservedMessageTypeRanges"]:
        swift_struct_literal(
            out,
            "    ",
            "ReservedMessageTypeRange",
            (
                ("first", swift_hex(first, 1)),
                ("last", swift_hex(last, 1)),
                ("purpose", f"\"{purpose}\""),
            ),
            trailing="," if len(model["reservedMessageTypeRanges"]) > 1 else "",
        )
    out += [
        "  ]",
        "",
        "  // MARK: - Address types and HEV record",
        "",
        "  public enum AddressType: UInt8, CaseIterable, Sendable {",
    ]
    for address in model["addressTypes"]:
        out.append(
            f"    case {screaming_to_camel(address['name'])} = {hex_literal(address['value'], 1)}"
        )
    out += [
        "  }",
        "",
        "  public static let addressTypeMetadata: [AddressTypeMetadata] = [",
    ]
    for address in model["addressTypes"]:
        prefixed = "true" if address["lengthPrefixed"] else "false"
        swift_struct_literal(
            out,
            "    ",
            "AddressTypeMetadata",
            (
                ("type", f".{screaming_to_camel(address['name'])}"),
                ("name", f"\"{address['name']}\""),
                ("isLengthPrefixed", prefixed),
                ("minAddressBytes", str(address["min"])),
                ("maxAddressBytes", str(address["max"])),
            ),
        )
    out += [
        "  ]",
        "",
        "  public static let hevFixedPrefixLayout: [WireField] = [",
    ]
    for name, offset, width in model["hevFixedPrefixLayout"]:
        out.append(f"    WireField(name: \"{name}\", byteOffset: {offset}, byteWidth: {width}),")
    out += [
        "  ]",
        f"  public static let hevHeaderBaseWidth = {model['hevHeaderBaseWidth']}",
        f"  public static let hevPortWidth = {model['hevPortWidth']}",
        f"  public static let hevHDRLENIPv4 = {hdrlens.get('IPV4', 0)}",
        f"  public static let hevHDRLENIPv6 = {hdrlens.get('IPV6', 0)}",
        f"  public static let hevHDRLENDomainBase = {model['hevHeaderBaseWidth'] + 1}",
        f"  public static let minDomainWireBytes = {model['minDomainWireBytes']}",
        f"  public static let maxDomainWireBytes = {model['maxDomainWireBytes']}",
        f"  public static let maxHEVRecordWidth = {model['maxHEVRecordWidth']}",
        "",
        "  // MARK: - UDP error codes",
        "",
        "  public enum UDPErrorCode: UInt16, CaseIterable, Sendable {",
    ]
    for name, value in model["udpErrorCodes"]:
        out.append(f"    case {screaming_to_camel(name)} = {hex_literal(value, 2)}")
    out += [
        "  }",
        "",
        "  public static let udpErrorCodeNames: [NamedValue] = [",
    ]
    for name, value in model["udpErrorCodes"]:
        out.append(f"    NamedValue(name: \"{name}\", value: {value}),")
    out += [
        "  ]",
        "",
        "  // MARK: - Limits",
        "",
        "  public static let limits: [LimitSpec] = [",
    ]
    for limit in model["limits"]:
        swift_struct_literal(
            out,
            "    ",
            "LimitSpec",
            (
                ("name", f"\"{limit['name']}\""),
                ("limitClass", f".{limit['class']}"),
                ("byteWidth", str(limit["width"])),
                ("unit", f"\"{limit['unit']}\""),
                ("clientDefault", swift_decimal(limit["clientDefault"])),
                ("relayDefault", swift_decimal(limit["relayDefault"])),
                ("floor", swift_decimal(limit["floor"])),
                ("clientHardCeiling", swift_decimal(limit["clientHardCeiling"])),
                ("relayHardCeiling", swift_decimal(limit["relayHardCeiling"])),
            ),
        )
    out += ["  ]", ""]
    for limit in model["limits"]:
        swift_type = swift_uint_type(limit["width"])
        for suffix, key in (
            ("ClientDefault", "clientDefault"),
            ("RelayDefault", "relayDefault"),
            ("Floor", "floor"),
            ("ClientHardCeiling", "clientHardCeiling"),
            ("RelayHardCeiling", "relayHardCeiling"),
        ):
            out.append(
                f"  public static let {limit['name']}{suffix}: {swift_type} = "
                f"{swift_decimal(limit[key])}"
            )
    limits_by_name = {limit["name"]: limit for limit in model["limits"]}
    max_frame = limits_by_name["maxFrame"]
    max_payload = limits_by_name["maxUDPPayload"]
    out += [
        "",
        "  // MARK: - Limit aliases (TASK-260715-18owh7 wording; maxFrameFloor is",
        "  // already emitted by the uniform per-limit block above)",
        "",
        f"  public static let maxFrameDefault: {swift_uint_type(max_frame['width'])} = "
        f"{swift_decimal(max_frame['clientDefault'])}",
        f"  public static let maxFrameHardCeiling: {swift_uint_type(max_frame['width'])} = "
        f"{swift_decimal(max_frame['clientHardCeiling'])}",
        f"  public static let maxUDPPayload: {swift_uint_type(max_payload['width'])} = "
        f"{swift_decimal(max_payload['clientDefault'])}",
        f"  public static let maxUDPPayloadLocalFloor: {swift_uint_type(max_payload['width'])} = "
        f"{swift_decimal(max_payload['floor'])}",
        "",
        "  // MARK: - Parity fingerprint",
        "",
        "  /// Canonical language-neutral rendering of every value above. The Swift",
        "  /// and Go parity tests re-derive these lines from the typed metadata and",
        "  /// fail on any hand edit; `make relay-protocol-check` compares bytes.",
        "  public static let parityLines: [String] = [",
    ]
    for line in lines:
        chunks = chunk_parity_line(line)
        if len(chunks) == 1:
            out.append(f"    \"{chunks[0]}\",")
        else:
            out.append(f"    \"{chunks[0]}\"")
            for chunk in chunks[1:-1]:
                out.append(f"      + \"{chunk}\"")
            out.append(f"      + \"{chunks[-1]}\",")
    out += [
        "  ]",
        "",
        "  public static let paritySHA256 =",
        f"    \"{digest}\"",
        "}",
    ]
    return "\n".join(out) + "\n"


# --- Go emission ------------------------------------------------------------


def emit_go(model, schema_digest, gofmt):
    lines = parity_lines(model)
    digest = parity_digest(lines)
    hdrlens = {a["name"]: a["hdrlen"] for a in model["addressTypes"]}
    out = [
        "// Code generated by scripts/relay-protocol-tool.py. DO NOT EDIT.",
    ] + header_lines("//", schema_digest)[1:]
    out += [
        "",
        "// Package protocol carries the generated relay protocol v1 wire constants",
        "// and typed metadata. Handwritten code must not restate these values.",
        "//",
        "// Semantics: TASK-260715-111tde (binding ADR) and TASK-260715-18owh7 (limits).",
        "package protocol",
        "",
        "type WireField struct {",
        "\tName       string",
        "\tByteOffset int",
        "\tByteWidth  int",
        "}",
        "",
        "type NamedValue struct {",
        "\tName  string",
        "\tValue uint64",
        "}",
        "",
        "type BitAssignment struct {",
        "\tBit            int",
        "\tName           string",
        "\tIsAllocated    bool",
        "\tValidOnMessage string",
        "\tValidDirection string",
        "\tGatedByFeature string",
        "}",
        "",
        "type MessageDirection string",
        "",
        "const MessageDirectionClientToRelay MessageDirection = \"clientToRelay\"",
        "const MessageDirectionRelayToClient MessageDirection = \"relayToClient\"",
        "const MessageDirectionBoth MessageDirection = \"both\"",
        "",
        "type AssociationIDRule string",
        "",
        "const AssociationIDRuleZero AssociationIDRule = \"zero\"",
        "const AssociationIDRuleNonzero AssociationIDRule = \"nonzero\"",
        "",
        "type PayloadShape string",
        "",
        "const PayloadShapeFixed PayloadShape = \"fixed\"",
        "const PayloadShapeHEVUDPRecord PayloadShape = \"hevUDPRecord\"",
        "",
        "type MessageMetadata struct {",
        "\tType          MessageType",
        "\tName          string",
        "\tDirection     MessageDirection",
        "\tAssociationID AssociationIDRule",
        "\tPayloadShape  PayloadShape",
        "\t// FixedPayloadWidth is the exact payload byte count for fixed shapes;",
        "\t// -1 for variable payloads.",
        "\tFixedPayloadWidth int",
        "}",
        "",
        "type AddressTypeMetadata struct {",
        "\tType             AddressType",
        "\tName             string",
        "\tIsLengthPrefixed bool",
        "\tMinAddressBytes  int",
        "\tMaxAddressBytes  int",
        "}",
        "",
        "type LimitClass string",
        "",
        "const LimitClassNegotiatedWire LimitClass = \"negotiatedWire\"",
        "const LimitClassFixedWireConstant LimitClass = \"fixedWireConstant\"",
        "const LimitClassLocalCap LimitClass = \"localCap\"",
        "",
        "type LimitSpec struct {",
        "\tName             string",
        "\tClass            LimitClass",
        "\tByteWidth        int",
        "\tUnit             string",
        "\tClientDefault    uint64",
        "\tRelayDefault     uint64",
        "\tFloor            uint64",
        "\tClientHardCeiling uint64",
        "\tRelayHardCeiling  uint64",
        "}",
        "",
        "type ReservedMessageTypeRange struct {",
        "\tFirst   uint8",
        "\tLast    uint8",
        "\tPurpose string",
        "}",
        "",
        f"const ProtocolName = \"{model['protocolName']}\"",
        f"const WireVersion uint16 = {model['wireVersion']}",
        f"const ByteOrder = \"{model['byteOrder']}\"",
        f"const MagicASCII = \"{model['magicASCII']}\"",
        "",
        "var Magic = [4]byte{"
        + ", ".join(hex_literal(byte, 1) for byte in model["magicBytes"])
        + "}",
        "",
        f"const SchemaSHA256 = \"{schema_digest}\"",
        f"const GeneratorFormatVersion = {GENERATOR_FORMAT_VERSION}",
        "",
    ]
    for go_name, key in (
        ("ClientHelloLayout", "clientHelloLayout"),
        ("ServerHelloLayout", "serverHelloLayout"),
    ):
        out.append(f"var {go_name} = []WireField{{")
        for name, offset, width in model[key]:
            out.append(f"\t{{Name: \"{name}\", ByteOffset: {offset}, ByteWidth: {width}}},")
        out.append("}")
        out.append("")
    out += [
        f"const ClientHelloWidth = {model['clientHelloWidth']}",
        f"const ServerHelloWidth = {model['serverHelloWidth']}",
        "",
        "type HelloStatus uint16",
        "",
    ]
    for name, value in model["helloStatuses"]:
        out.append(f"const HelloStatus{screaming_to_pascal(name)} HelloStatus = {hex_literal(value, 2)}")
    out += ["", "var HelloStatusNames = []NamedValue{"]
    for name, value in model["helloStatuses"]:
        out.append(f"\t{{Name: \"{name}\", Value: {value}}},")
    out += ["}", ""]

    def go_bits(prefix, bits, mask_name, mask, width, slice_name):
        for bit in bits:
            if bit["status"] == "allocated":
                out.append(
                    f"const {prefix}{camel_to_pascal(bit['name'])} {go_uint_type(width)} = "
                    f"{hex_literal(1 << bit['bit'], width)}"
                )
        out.append(f"const {mask_name} {go_uint_type(width)} = {hex_literal(mask, width)}")
        out.append("")
        out.append(f"var {slice_name} = []BitAssignment{{")
        for bit in bits:
            allocated = "true" if bit["status"] == "allocated" else "false"
            out.append(
                f"\t{{Bit: {bit['bit']}, Name: \"{bit['name']}\", IsAllocated: {allocated}, "
                f"ValidOnMessage: \"{bit['validOnMessage']}\", "
                f"ValidDirection: \"{bit['validDirection']}\", "
                f"GatedByFeature: \"{bit['gatedByFeature']}\"}},"
            )
        out.append("}")

    go_bits(
        "HelloFlag",
        model["helloFlagBits"],
        "HelloFlagsReservedMask",
        model["helloFlagsReservedMask"],
        model["helloFlagsWidth"],
        "HelloFlagAssignments",
    )
    out.append("")
    go_bits(
        "Feature",
        model["featureBits"],
        "FeaturesReservedMask",
        model["featuresReservedMask"],
        model["featuresWidth"],
        "FeatureAssignments",
    )
    out += [
        "",
        f"const FramePrefixWidth = {model['envelopePrefix'][1]}",
        f"const EnvelopeHeaderWidth = {model['envelopeHeaderWidth']}",
        f"const EnvelopeLengthCoverage = \"{model['lengthCoverage']}\"",
        f"const MinFrameLength uint32 = {model['minFrameLength']}",
        f"const MaxLegalFrameBody uint32 = {model['maxLegalFrameBody']}",
        "",
        "var EnvelopeLayout = []WireField{",
        f"\t{{Name: \"{model['envelopePrefix'][0]}\", ByteOffset: 0, "
        f"ByteWidth: {model['envelopePrefix'][1]}}},",
    ]
    for name, offset, width in model["envelopeHeaderLayout"]:
        out.append(
            f"\t{{Name: \"{name}\", ByteOffset: {model['envelopePrefix'][1] + offset}, "
            f"ByteWidth: {width}}},"
        )
    out += ["}", ""]
    go_bits(
        "EnvelopeFlag",
        model["envelopeFlagBits"],
        "EnvelopeFlagsReservedMask",
        model["envelopeFlagsReservedMask"],
        model["envelopeFlagsWidth"],
        "EnvelopeFlagAssignments",
    )
    out += [
        "",
        "type MessageType uint8",
        "",
    ]
    for message in model["messageTypes"]:
        out.append(
            f"const MessageType{screaming_to_pascal(message['name'])} MessageType = "
            f"{hex_literal(message['value'], 1)}"
        )
    out += ["", "var MessageMetadataTable = []MessageMetadata{"]
    for message in model["messageTypes"]:
        out.append(
            f"\t{{Type: MessageType{screaming_to_pascal(message['name'])}, "
            f"Name: \"{message['name']}\", "
            f"Direction: MessageDirection{camel_to_pascal(message['direction'])}, "
            f"AssociationID: AssociationIDRule{camel_to_pascal(message['associationID'])}, "
            f"PayloadShape: PayloadShape{camel_to_pascal(message['shape'])}, "
            f"FixedPayloadWidth: {message['fixedWidth']}}},"
        )
    out += ["}", "", "var ReservedMessageTypeRanges = []ReservedMessageTypeRange{"]
    for first, last, purpose in model["reservedMessageTypeRanges"]:
        out.append(
            f"\t{{First: {hex_literal(first, 1)}, Last: {hex_literal(last, 1)}, "
            f"Purpose: \"{purpose}\"}},"
        )
    out += [
        "}",
        "",
        "type AddressType uint8",
        "",
    ]
    for address in model["addressTypes"]:
        out.append(
            f"const AddressType{screaming_to_pascal(address['name'])} AddressType = "
            f"{hex_literal(address['value'], 1)}"
        )
    out += ["", "var AddressTypeMetadataTable = []AddressTypeMetadata{"]
    for address in model["addressTypes"]:
        prefixed = "true" if address["lengthPrefixed"] else "false"
        out.append(
            f"\t{{Type: AddressType{screaming_to_pascal(address['name'])}, "
            f"Name: \"{address['name']}\", IsLengthPrefixed: {prefixed}, "
            f"MinAddressBytes: {address['min']}, MaxAddressBytes: {address['max']}}},"
        )
    out += ["}", "", "var HEVFixedPrefixLayout = []WireField{"]
    for name, offset, width in model["hevFixedPrefixLayout"]:
        out.append(f"\t{{Name: \"{name}\", ByteOffset: {offset}, ByteWidth: {width}}},")
    out += [
        "}",
        "",
        f"const HEVHeaderBaseWidth = {model['hevHeaderBaseWidth']}",
        f"const HEVPortWidth = {model['hevPortWidth']}",
        f"const HEVHDRLENIPv4 = {hdrlens.get('IPV4', 0)}",
        f"const HEVHDRLENIPv6 = {hdrlens.get('IPV6', 0)}",
        f"const HEVHDRLENDomainBase = {model['hevHeaderBaseWidth'] + 1}",
        f"const MinDomainWireBytes = {model['minDomainWireBytes']}",
        f"const MaxDomainWireBytes = {model['maxDomainWireBytes']}",
        f"const MaxHEVRecordWidth = {model['maxHEVRecordWidth']}",
        "",
        "type UDPErrorCode uint16",
        "",
    ]
    for name, value in model["udpErrorCodes"]:
        out.append(
            f"const UDPErrorCode{screaming_to_pascal(name)} UDPErrorCode = {hex_literal(value, 2)}"
        )
    out += ["", "var UDPErrorCodeNames = []NamedValue{"]
    for name, value in model["udpErrorCodes"]:
        out.append(f"\t{{Name: \"{name}\", Value: {value}}},")
    out += ["}", "", "var Limits = []LimitSpec{"]
    for limit in model["limits"]:
        out.append(
            f"\t{{Name: \"{limit['name']}\", Class: LimitClass{camel_to_pascal(limit['class'])}, "
            f"ByteWidth: {limit['width']}, Unit: \"{limit['unit']}\", "
            f"ClientDefault: {limit['clientDefault']}, RelayDefault: {limit['relayDefault']}, "
            f"Floor: {limit['floor']}, ClientHardCeiling: {limit['clientHardCeiling']}, "
            f"RelayHardCeiling: {limit['relayHardCeiling']}}},"
        )
    out += ["}", ""]
    for limit in model["limits"]:
        go_type = go_uint_type(limit["width"])
        pascal = camel_to_pascal(limit["name"])
        for suffix, key in (
            ("ClientDefault", "clientDefault"),
            ("RelayDefault", "relayDefault"),
            ("Floor", "floor"),
            ("ClientHardCeiling", "clientHardCeiling"),
            ("RelayHardCeiling", "relayHardCeiling"),
        ):
            out.append(f"const {pascal}{suffix} {go_type} = {limit[key]}")
    limits_by_name = {limit["name"]: limit for limit in model["limits"]}
    max_frame = limits_by_name["maxFrame"]
    max_payload = limits_by_name["maxUDPPayload"]
    out += [
        "",
        f"const MaxFrameDefault {go_uint_type(max_frame['width'])} = {max_frame['clientDefault']}",
        f"const MaxFrameHardCeiling {go_uint_type(max_frame['width'])} = {max_frame['clientHardCeiling']}",
        f"const MaxUDPPayload {go_uint_type(max_payload['width'])} = {max_payload['clientDefault']}",
        f"const MaxUDPPayloadLocalFloor {go_uint_type(max_payload['width'])} = {max_payload['floor']}",
        "",
        "// ParityLines is the canonical language-neutral rendering of every value",
        "// above. The Swift and Go parity tests re-derive these lines from the typed",
        "// metadata and fail on any hand edit; make relay-protocol-check compares",
        "// bytes.",
        "var ParityLines = []string{",
    ]
    for line in lines:
        out.append(f"\t\"{line}\",")
    out += [
        "}",
        "",
        f"const ParitySHA256 = \"{digest}\"",
    ]
    text = "\n".join(out) + "\n"
    return run_gofmt(text, gofmt)


def find_gofmt():
    gofmt = shutil.which("gofmt")
    if gofmt is None:
        fail("gofmt not found on PATH; the pinned Go toolchain is required to generate")
    return gofmt


def run_gofmt(text, gofmt):
    result = subprocess.run(
        [gofmt],
        input=text.encode("utf-8"),
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"gofmt rejected generated Go source: {result.stderr.decode('utf-8', 'replace')}")
    return result.stdout.decode("utf-8")


# --- commands ---------------------------------------------------------------


def load_validated_model(schema_path):
    raw = load_schema_bytes(schema_path)
    document = parse_schema(raw, require_canonical=True)
    model, errors = validate_schema(document)
    if errors:
        for error in errors:
            print(f"schema error: {error}", file=sys.stderr)
        fail(f"schema validation failed with {len(errors)} error(s)")
    return raw, model


def generate_outputs(model, schema_digest, output_root, gofmt):
    outputs = {
        SWIFT_OUTPUT: emit_swift(model, schema_digest),
        GO_OUTPUT: emit_go(model, schema_digest, gofmt),
    }
    written = []
    for relative, text in sorted(outputs.items()):
        path = Path(output_root) / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))
        written.append(relative)
    return written


def cmd_validate(args):
    load_validated_model(repo_path(args.schema))
    print("schema OK")
    return 0


def cmd_digest(args):
    raw = load_schema_bytes(repo_path(args.schema))
    print(hashlib.sha256(raw).hexdigest())
    return 0


def cmd_generate(args):
    raw, model = load_validated_model(repo_path(args.schema))
    schema_digest = hashlib.sha256(raw).hexdigest()
    gofmt = find_gofmt()
    output_root = Path(args.output_root) if args.output_root else REPO_ROOT
    written = generate_outputs(model, schema_digest, output_root, gofmt)
    for relative in written:
        print(f"wrote {relative}")
    print(f"schema sha256 {schema_digest}")
    return 0


def apply_fixture_operations(document, operations, fixture_name):
    patched = copy.deepcopy(document)
    for operation in operations:
        op = operation.get("op")
        path = operation.get("path")
        if op not in ("set", "delete") or not isinstance(path, list) or not path:
            fail(f"fixture {fixture_name}: invalid operation {operation!r}")
        node = patched
        try:
            for key in path[:-1]:
                node = node[key]
            if op == "set":
                node[path[-1]] = operation["value"]
            else:
                del node[path[-1]]
        except (KeyError, IndexError, TypeError) as error:
            fail(f"fixture {fixture_name}: path {path!r} does not apply: {error}")
    return patched


def run_negative_fixtures(document, fixtures_dir):
    fixture_paths = sorted(fixtures_dir.glob("*.json"))
    if not fixture_paths:
        fail(f"no negative fixtures found in {fixtures_dir}")
    for fixture_path in fixture_paths:
        try:
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
        except ValueError as error:
            fail(f"fixture {fixture_path.name}: invalid JSON: {error}")
        for key in ("description", "expectError", "operations"):
            if key not in fixture:
                fail(f"fixture {fixture_path.name}: missing key {key!r}")
        patched = apply_fixture_operations(document, fixture["operations"], fixture_path.name)
        _, errors = validate_schema(patched)
        if not errors:
            fail(
                f"fixture {fixture_path.name}: validation unexpectedly PASSED; "
                "the validator no longer rejects this class of invalid schema"
            )
        joined = "\n".join(errors)
        if fixture["expectError"] not in joined:
            fail(
                f"fixture {fixture_path.name}: expected error containing "
                f"{fixture['expectError']!r}, got:\n{joined}"
            )
    return len(fixture_paths)


def compare_files(fresh_root, candidate_root, relatives):
    mismatches = []
    for relative in relatives:
        fresh = (Path(fresh_root) / relative).read_bytes()
        candidate_path = Path(candidate_root) / relative
        if not candidate_path.exists():
            mismatches.append(f"{relative}: missing")
            continue
        if candidate_path.read_bytes() != fresh:
            mismatches.append(f"{relative}: differs from regenerated output")
    return mismatches


def extract_header_digest(path):
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("// Schema-SHA256: "):
            return line.removeprefix("// Schema-SHA256: ").strip()
    return None


def cmd_check(args):
    schema_path = repo_path(args.schema)
    raw, model = load_validated_model(schema_path)
    schema_digest = hashlib.sha256(raw).hexdigest()
    document = parse_schema(raw, require_canonical=True)
    gofmt = find_gofmt()
    outputs = (SWIFT_OUTPUT, GO_OUTPUT)

    fixture_count = run_negative_fixtures(document, repo_path(FIXTURES_DIR))
    print(f"negative fixtures OK ({fixture_count} rejected)")

    temp_root = repo_path(TEMP_ROOT)
    temp_root.mkdir(parents=True, exist_ok=True)
    run_a = Path(tempfile.mkdtemp(prefix="generate-a-", dir=temp_root))
    run_b = Path(tempfile.mkdtemp(prefix="generate-b-", dir=temp_root))
    try:
        generate_outputs(model, schema_digest, run_a, gofmt)
        generate_outputs(model, schema_digest, run_b, gofmt)

        mismatches = compare_files(run_a, run_b, outputs)
        if mismatches:
            fail("nondeterministic generation: " + "; ".join(mismatches))
        print("double regeneration byte-identical")

        mismatches = compare_files(run_a, REPO_ROOT, outputs)
        if mismatches:
            fail(
                "checked-in generated outputs are stale or hand-edited: "
                + "; ".join(mismatches)
                + f". Run `{REGENERATE_COMMAND}` and commit the diff."
            )
        print("checked-in outputs match regeneration")

        for relative in outputs:
            embedded = extract_header_digest(repo_path(relative))
            if embedded != schema_digest:
                fail(
                    f"{relative}: embedded Schema-SHA256 {embedded!r} does not match "
                    f"schema digest {schema_digest}"
                )
        print("embedded schema digests OK")

        # Self-test: a deliberately stale/hand-edited output must be detected.
        stale_root = Path(tempfile.mkdtemp(prefix="stale-", dir=temp_root))
        for relative in outputs:
            stale_path = stale_root / relative
            stale_path.parent.mkdir(parents=True, exist_ok=True)
            stale_path.write_bytes(repo_path(relative).read_bytes()[:-1])
        if not compare_files(run_a, stale_root, outputs):
            fail("stale-output self-test failed: mutated outputs were not detected")
        mutated_swift = stale_root / SWIFT_OUTPUT
        original = repo_path(SWIFT_OUTPUT).read_text(encoding="utf-8")
        mutated_swift.write_text(
            original.replace(f"Schema-SHA256: {schema_digest}", f"Schema-SHA256: {'0' * 64}"),
            encoding="utf-8",
        )
        if extract_header_digest(mutated_swift) == schema_digest:
            fail("digest self-test failed: mutated digest header was not detected")
        print("stale/manual-edit self-test OK")
    finally:
        for path in (run_a, run_b):
            shutil.rmtree(path, ignore_errors=True)
        shutil.rmtree(temp_root / "stale", ignore_errors=True)
        for stale in temp_root.glob("stale-*"):
            shutil.rmtree(stale, ignore_errors=True)

    print(f"relay-protocol-check tool stage OK (schema sha256 {schema_digest})")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", default=SCHEMA_PATH, help="repo-relative schema path")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate", help="validate the schema")
    subparsers.add_parser("digest", help="print the schema SHA-256")
    generate = subparsers.add_parser("generate", help="validate and write generated outputs")
    generate.add_argument(
        "--output-root", default=None, help="write outputs under this root instead of the repo"
    )
    subparsers.add_parser("check", help="run the full schema/generation drift gate")
    args = parser.parse_args()
    handlers = {
        "validate": cmd_validate,
        "digest": cmd_digest,
        "generate": cmd_generate,
        "check": cmd_check,
    }
    try:
        return handlers[args.command](args)
    except ToolError as error:
        print(f"relay-protocol-tool: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
