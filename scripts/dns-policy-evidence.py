#!/usr/bin/env python3
"""Controlled, network-isolated evidence harness for DNSRuntimePolicyV1.

This is a disposable research harness. It opens only numeric loopback sockets,
replaces hostname resolution with a failing sentinel, exercises DNS/TCP and
DNS/UDP fixture behavior, validates policy vectors, and emits one JSON report.
It is not production DNS implementation code.
"""

from __future__ import annotations

import argparse
import copy
import ctypes
import gc
import hashlib
import json
import math
import os
import platform
import resource
import socket
import statistics
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any


TASK_ID = "TASK-260721-3miqh4"
SCHEMA_VERSION = 1
TCP_FRAME_BYTES = 2
METADATA_BYTES_PER_QUERY = 1024
RETRY_REQUEST_COPIES_PER_QUERY = 1
# A DNS-over-TCP frame is the two-byte length field plus up to 65,535 message
# bytes. These are contiguous wire-buffer reservations, so 65,537 is the exact
# minimum that can hold a maximum frame without borrowing untracked storage.
CONNECTION_READ_BUFFER_BYTES = 65_537
CONNECTION_WRITE_BUFFER_BYTES = 65_537
MANAGER_BASE_BYTES = 65_536
DIAGNOSTICS_RESERVE_BYTES = 65_536
ENDPOINT_METADATA_BYTES = 64


DEFAULTS: dict[str, int] = {
    "maxConfiguredEndpoints": 4,
    "maxDNSMessageBytes": 65_535,
    "maxInFlightQueries": 16,
    "maxQueuedWireBytes": 262_144,
    "maxAggregateDNSBytes": 4_194_304,
    "channelOpenTimeoutMilliseconds": 2_000,
    "responseTimeoutMilliseconds": 5_000,
    "relayUDPPhaseTimeoutMilliseconds": 5_000,
    "dispatchAllowanceMilliseconds": 1_000,
    "logicalQueryTimeoutMilliseconds": 35_000,
    "startupReadinessTimeoutMilliseconds": 10_000,
    "idleCloseTimeoutMilliseconds": 10_000,
}

CEILINGS: dict[str, int] = {
    "maxConfiguredEndpoints": 8,
    "maxDNSMessageBytes": 65_535,
    "maxInFlightQueries": 32,
    "maxQueuedWireBytes": 1_048_576,
    "maxAggregateDNSBytes": 8_388_608,
    "channelOpenTimeoutMilliseconds": 5_000,
    "responseTimeoutMilliseconds": 10_000,
    "relayUDPPhaseTimeoutMilliseconds": 10_000,
    "dispatchAllowanceMilliseconds": 2_000,
    "logicalQueryTimeoutMilliseconds": 135_000,
    "startupReadinessTimeoutMilliseconds": 45_000,
    "idleCloseTimeoutMilliseconds": 30_000,
}

MINIMUMS: dict[str, int] = {
    "maxConfiguredEndpoints": 1,
    "maxDNSMessageBytes": 65_535,
    "maxInFlightQueries": 1,
    "maxQueuedWireBytes": 512,
    "maxAggregateDNSBytes": 262_144,
    "channelOpenTimeoutMilliseconds": 250,
    "responseTimeoutMilliseconds": 500,
    "relayUDPPhaseTimeoutMilliseconds": 500,
    "dispatchAllowanceMilliseconds": 1,
    "logicalQueryTimeoutMilliseconds": 1_000,
    "startupReadinessTimeoutMilliseconds": 250,
    "idleCloseTimeoutMilliseconds": 2_000,
}

POLICY_NAME = "DNSRuntimePolicyV1"
POLICY_STATUS = "candidate-blocked-missing-accepted-budget-and-ssh-evidence"
AUTHORITY_CLASS = "non-authoritative-candidate"
BLOCKING_TASK_IDS = ["TASK-260715-1gjxer", "TASK-260715-1pn983"]
PHYSICAL_EVIDENCE_GATE = {
    "required": True,
    "classification": "later-external-physical-evidence-gate",
    "requirements": [
        "selected-engine controlled SSH direct-tcpip timing and cleanup rows",
        "physical baseline-provider startup and footprint rows",
    ],
}
PRODUCTION_AUTHORIZATION = {
    "permitted": False,
    "adr022MayAdvanceToAccepted": False,
    "blockingTaskIDs": BLOCKING_TASK_IDS,
    "physicalEvidenceGate": PHYSICAL_EVIDENCE_GATE,
}
PROFILE_STORAGE = {
    "storesRuntimePolicyValues": False,
    "storesResolverIdentityOnly": True,
}
ATTEMPT_POLICY = {
    "m1TCPAttemptsPerEndpointMaximum": 1,
    "m1EndpointOrder": "stored-serial",
    "m1ParallelRacing": False,
    "m1CoordinatedRetryBatchesMaximumPerEpochFailure": 1,
    "m2UDPAttemptsMaximum": 1,
    "m2TCPAttemptsPerEndpointMaximum": 1,
    "terminalClaimsPerLogicalQueryMaximum": 1,
}
TIMING_SEMANTICS = {
    "responseTimeout": "complete correlated framed TCP response after request write ownership",
    "relayUDPPhaseTimeout": "one bounded association/session/send/receive phase ending on valid response, typed failure, datagram-size rejection, or timeout",
    "dispatchAllowance": "one non-resetting allowance for scheduling and terminal publication across the logical/startup state machine",
    "logicalDeadline": "one monotonic deadline that never resets on UDP-to-TCP fallback, channel open, retry batch, or endpoint promotion",
}
VALIDATION_EQUATIONS = [
    "all fields are integers and minimum <= value <= hard ceiling",
    "startupRequired = E * channelOpen + dispatchAllowance",
    "m1ReadyRequired = E * response + (E - 1) * channelOpen + dispatchAllowance",
    "m1ColdRequired = E * (channelOpen + response) + dispatchAllowance",
    "m2ReadyRequired = relayUDPPhase + m1ReadyRequired",
    "m2ColdRequired = relayUDPPhase + m1ColdRequired",
    "startupReadiness >= startupRequired",
    "logicalQuery >= max(m1ReadyRequired, m1ColdRequired, m2ReadyRequired, m2ColdRequired)",
    "maxQueuedWireBytes < maxAggregateDNSBytes",
    "perQueryReservationBytes = 3 * (maxDNSMessageBytes + 2) + 1024",
    "accountedBytes = maxInFlightQueries * perQueryReservationBytes + maxQueuedWireBytes + 65537 + 65537 + 65536 + 65536 + maxConfiguredEndpoints * 64",
    "accountedBytes <= maxAggregateDNSBytes",
]
METADATA_SUBLEDGER = {
    "perQuery": {
        "epochAndGeneration": 16,
        "clientAndUpstreamIDsFlagsAndPadding": 16,
        "canonicalQuestionCorrelation": 64,
        "deadlineStateTerminalAndCancellation": 64,
        "timerTaskContinuationAndQueueHandles": 128,
        "retryAndTombstoneBookkeeping": 64,
        "allocatorAlignmentAndImplementationSlack": 128,
        "subtotal": 480,
        "reserved": 1024,
        "headroom": 544,
    },
    "managerBase": {
        "upstreamIDOccupancyBitmap": 8192,
        "ownerAndTombstoneMapBuckets": 16384,
        "timerAndDeadlineContainers": 8192,
        "retryAndAdmissionContainers": 8192,
        "epochAndConnectionState": 8192,
        "fixedMetricsAndCounters": 4096,
        "allocatorAlignmentAndImplementationSlack": 12288,
        "subtotal": 65536,
        "reserved": 65536,
        "headroom": 0,
    },
}
WIRE_BOUNDARY_VECTORS = [
    {"messageBytes": 65_535, "wireBytes": 65_537, "expectedAccepted": True},
    {"messageBytes": 65_536, "expectedAccepted": False},
]

# These values are independently frozen review expectations. The timing-vector
# tests compare the calculator against them before exercising validate_policy,
# so a defect in timing_requirements cannot make the validator tests tautological.
EXPECTED_TIMING_REQUIREMENTS = {
    "defaults": {
        "startupColdSerialMilliseconds": 9_000,
        "m1ReadyConnectionMilliseconds": 27_000,
        "m1ColdConnectionMilliseconds": 29_000,
        "m2ReadyTCPConnectionMilliseconds": 32_000,
        "m2ColdTCPConnectionMilliseconds": 34_000,
    },
    "hardCeilings": {
        "startupColdSerialMilliseconds": 42_000,
        "m1ReadyConnectionMilliseconds": 117_000,
        "m1ColdConnectionMilliseconds": 122_000,
        "m2ReadyTCPConnectionMilliseconds": 127_000,
        "m2ColdTCPConnectionMilliseconds": 132_000,
    },
}
TIMING_VALIDATOR_CONTRACT = {
    "startupColdSerialMilliseconds": {
        "mutatedField": "startupReadinessTimeoutMilliseconds",
        "expectedError": "startupReadinessTimeoutMilliseconds:endpoint-open-coverage",
        "governingMaximum": True,
    },
    "m1ReadyConnectionMilliseconds": {
        "mutatedField": "logicalQueryTimeoutMilliseconds",
        "expectedError": "logicalQueryTimeoutMilliseconds:m1-ready-coverage",
        "governingMaximum": False,
    },
    "m1ColdConnectionMilliseconds": {
        "mutatedField": "logicalQueryTimeoutMilliseconds",
        "expectedError": "logicalQueryTimeoutMilliseconds:m1-cold-coverage",
        "governingMaximum": False,
    },
    "m2ReadyTCPConnectionMilliseconds": {
        "mutatedField": "logicalQueryTimeoutMilliseconds",
        "expectedError": "logicalQueryTimeoutMilliseconds:m2-ready-coverage",
        "governingMaximum": False,
    },
    "m2ColdTCPConnectionMilliseconds": {
        "mutatedField": "logicalQueryTimeoutMilliseconds",
        "expectedError": "logicalQueryTimeoutMilliseconds:m2-cold-coverage",
        "governingMaximum": True,
    },
}


def per_query_reservation(policy: dict[str, int]) -> int:
    message_and_frame = policy["maxDNSMessageBytes"] + TCP_FRAME_BYTES
    return (
        message_and_frame  # encoded request
        + message_and_frame  # maximum response
        + RETRY_REQUEST_COPIES_PER_QUERY * message_and_frame
        + METADATA_BYTES_PER_QUERY
    )


def ledger(policy: dict[str, int]) -> dict[str, int]:
    query_reservation = per_query_reservation(policy)
    transaction_reservations = query_reservation * policy["maxInFlightQueries"]
    endpoint_table = ENDPOINT_METADATA_BYTES * policy["maxConfiguredEndpoints"]
    accounted = (
        transaction_reservations
        + policy["maxQueuedWireBytes"]
        + CONNECTION_READ_BUFFER_BYTES
        + CONNECTION_WRITE_BUFFER_BYTES
        + MANAGER_BASE_BYTES
        + DIAGNOSTICS_RESERVE_BYTES
        + endpoint_table
    )
    return {
        "requestBytesPerQuery": policy["maxDNSMessageBytes"],
        "responseBytesPerQuery": policy["maxDNSMessageBytes"],
        "tcpFramingBytesPerQuery": TCP_FRAME_BYTES
        * (2 + RETRY_REQUEST_COPIES_PER_QUERY),
        "correlationAndTombstoneBytesPerQuery": METADATA_BYTES_PER_QUERY,
        "retryBatchRequestBytesPerQuery": policy["maxDNSMessageBytes"],
        "perQueryReservationBytes": query_reservation,
        "transactionReservationsBytes": transaction_reservations,
        "queuedWireBytes": policy["maxQueuedWireBytes"],
        "connectionReadBufferBytes": CONNECTION_READ_BUFFER_BYTES,
        "connectionWriteBufferBytes": CONNECTION_WRITE_BUFFER_BYTES,
        "managerBaseBytes": MANAGER_BASE_BYTES,
        "diagnosticsReserveBytes": DIAGNOSTICS_RESERVE_BYTES,
        "endpointTableBytes": endpoint_table,
        "accountedBytes": accounted,
        "aggregateBudgetBytes": policy["maxAggregateDNSBytes"],
        "headroomBytes": policy["maxAggregateDNSBytes"] - accounted,
    }


def validate_policy(policy: dict[str, int]) -> list[str]:
    errors: list[str] = []
    expected = set(DEFAULTS)
    if set(policy) != expected:
        errors.append("field-set")
        return errors
    for key in sorted(expected):
        value = policy[key]
        if not isinstance(value, int) or isinstance(value, bool):
            errors.append(f"{key}:integer")
            continue
        if value < MINIMUMS[key]:
            errors.append(f"{key}:below-minimum")
        if value > CEILINGS[key]:
            errors.append(f"{key}:above-ceiling")
    if errors:
        return errors

    endpoints = policy["maxConfiguredEndpoints"]
    channel_open = policy["channelOpenTimeoutMilliseconds"]
    response = policy["responseTimeoutMilliseconds"]
    relay_udp = policy["relayUDPPhaseTimeoutMilliseconds"]
    dispatch = policy["dispatchAllowanceMilliseconds"]
    startup_required = endpoints * channel_open + dispatch
    # Ready M1: the generation-global active endpoint already has a usable
    # connection. Later endpoints need one serial open each. Cold M1 is the
    # conservative case when the reusable connection was idle-closed.
    m1_ready_required = endpoints * response + (endpoints - 1) * channel_open + dispatch
    m1_cold_required = endpoints * (channel_open + response) + dispatch
    # M2 spends one bounded relay/UDP phase, then hands ownership to M1. The
    # conservative cold path includes a same-endpoint TCP open plus later
    # serial promotion; an already-ready TCP connection uses m1_ready_required.
    m2_ready_required = relay_udp + m1_ready_required
    m2_cold_required = relay_udp + m1_cold_required
    if policy["startupReadinessTimeoutMilliseconds"] < startup_required:
        errors.append("startupReadinessTimeoutMilliseconds:endpoint-open-coverage")
    if policy["logicalQueryTimeoutMilliseconds"] < m1_ready_required:
        errors.append("logicalQueryTimeoutMilliseconds:m1-ready-coverage")
    if policy["logicalQueryTimeoutMilliseconds"] < m1_cold_required:
        errors.append("logicalQueryTimeoutMilliseconds:m1-cold-coverage")
    if policy["logicalQueryTimeoutMilliseconds"] < m2_ready_required:
        errors.append("logicalQueryTimeoutMilliseconds:m2-ready-coverage")
    if policy["logicalQueryTimeoutMilliseconds"] < m2_cold_required:
        errors.append("logicalQueryTimeoutMilliseconds:m2-cold-coverage")
    if policy["maxQueuedWireBytes"] >= policy["maxAggregateDNSBytes"]:
        errors.append("maxQueuedWireBytes:must-be-below-aggregate")
    if ledger(policy)["headroomBytes"] < 0:
        errors.append("maxAggregateDNSBytes:ledger-overflow")
    return errors


def timing_requirements(policy: dict[str, int]) -> dict[str, int]:
    endpoints = policy["maxConfiguredEndpoints"]
    channel_open = policy["channelOpenTimeoutMilliseconds"]
    response = policy["responseTimeoutMilliseconds"]
    relay_udp = policy["relayUDPPhaseTimeoutMilliseconds"]
    dispatch = policy["dispatchAllowanceMilliseconds"]
    m1_ready = endpoints * response + (endpoints - 1) * channel_open + dispatch
    m1_cold = endpoints * (channel_open + response) + dispatch
    return {
        "startupColdSerialMilliseconds": endpoints * channel_open + dispatch,
        "m1ReadyConnectionMilliseconds": m1_ready,
        "m1ColdConnectionMilliseconds": m1_cold,
        "m2ReadyTCPConnectionMilliseconds": relay_udp + m1_ready,
        "m2ColdTCPConnectionMilliseconds": relay_udp + m1_cold,
    }


def policy_validation_vectors() -> list[dict[str, Any]]:
    return [
        {
            "name": "default-valid",
            "base": "defaults",
            "expectedValid": True,
            "expectedAccountedBytes": 3_686_706,
        },
        {
            "name": "hard-envelope-valid",
            "base": "hardCeilings",
            "expectedValid": True,
            "expectedAccountedBytes": 7_635_554,
        },
        {
            "name": "endpoint-over-ceiling",
            "base": "defaults",
            "override": {"maxConfiguredEndpoints": 9},
            "expectedValid": False,
            "expectedError": "maxConfiguredEndpoints:above-ceiling",
        },
        {
            "name": "message-one-byte-over",
            "base": "defaults",
            "override": {"maxDNSMessageBytes": 65_536},
            "expectedValid": False,
            "expectedError": "maxDNSMessageBytes:above-ceiling",
        },
        {
            "name": "ledger-overflow",
            "base": "defaults",
            "override": {"maxAggregateDNSBytes": 3_000_000},
            "expectedValid": False,
            "expectedError": "maxAggregateDNSBytes:ledger-overflow",
        },
    ]


def timing_validator_vectors(*, assert_results: bool) -> list[dict[str, Any]]:
    vectors: list[dict[str, Any]] = []
    for base_name, base_policy in (("defaults", DEFAULTS), ("hardCeilings", CEILINGS)):
        calculated = timing_requirements(base_policy)
        expected_requirements = EXPECTED_TIMING_REQUIREMENTS[base_name]
        if calculated != expected_requirements:
            raise AssertionError(
                f"{base_name} timing calculation drift: "
                f"expected={expected_requirements}, actual={calculated}"
            )
        for relationship, contract in TIMING_VALIDATOR_CONTRACT.items():
            required = expected_requirements[relationship]
            for boundary, offset, expected_target_error in (
                ("exact-equality", 0, False),
                ("one-millisecond-under", -1, True),
            ):
                mutated_field = str(contract["mutatedField"])
                policy = dict(base_policy)
                policy[mutated_field] = required + offset
                errors = validate_policy(policy)
                target_error = str(contract["expectedError"])
                target_error_present = target_error in errors
                expected_overall_valid = (
                    bool(contract["governingMaximum"]) and offset == 0
                )
                if assert_results:
                    if target_error_present != expected_target_error:
                        raise AssertionError(
                            f"{base_name}/{relationship}/{boundary}: "
                            f"expected target error present={expected_target_error}, errors={errors}"
                        )
                    if (not errors) != expected_overall_valid:
                        raise AssertionError(
                            f"{base_name}/{relationship}/{boundary}: "
                            f"expected overall valid={expected_overall_valid}, errors={errors}"
                        )
                vectors.append(
                    {
                        "name": f"{base_name}-{relationship}-{boundary}",
                        "base": base_name,
                        "relationship": relationship,
                        "mutatedField": mutated_field,
                        "mutatedValueMilliseconds": required + offset,
                        "requiredMilliseconds": required,
                        "boundary": boundary,
                        "expectedError": target_error,
                        "expectedTargetErrorPresent": expected_target_error,
                        "expectedRelationshipValid": not expected_target_error,
                        "expectedOverallValid": expected_overall_valid,
                        "actualErrors": errors,
                    }
                )
    return vectors


def accounting_constants() -> dict[str, int]:
    return {
        "tcpFramingBytesPerMessage": TCP_FRAME_BYTES,
        "correlationAndTombstoneBytesPerQuery": METADATA_BYTES_PER_QUERY,
        "retryRequestCopiesPerQuery": RETRY_REQUEST_COPIES_PER_QUERY,
        "connectionReadBufferBytes": CONNECTION_READ_BUFFER_BYTES,
        "connectionWriteBufferBytes": CONNECTION_WRITE_BUFFER_BYTES,
        "managerBaseBytes": MANAGER_BASE_BYTES,
        "diagnosticsReserveBytes": DIAGNOSTICS_RESERVE_BYTES,
        "endpointMetadataBytes": ENDPOINT_METADATA_BYTES,
    }


def accounting_proof(policy: dict[str, int]) -> dict[str, int]:
    proof = ledger(policy)
    return {
        "perQueryReservationBytes": proof["perQueryReservationBytes"],
        "transactionReservationsBytes": proof["transactionReservationsBytes"],
        "accountedBytes": proof["accountedBytes"],
        "aggregateBudgetBytes": proof["aggregateBudgetBytes"],
        "headroomBytes": proof["headroomBytes"],
    }


def canonical_policy_artifact() -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "policyName": POLICY_NAME,
        "taskID": TASK_ID,
        "status": POLICY_STATUS,
        "authorityClass": AUTHORITY_CLASS,
        "candidateMeasurementsOnly": True,
        "productionAuthorization": copy.deepcopy(PRODUCTION_AUTHORIZATION),
        "profileStorage": copy.deepcopy(PROFILE_STORAGE),
        "defaults": dict(DEFAULTS),
        "minimums": dict(MINIMUMS),
        "hardCeilings": dict(CEILINGS),
        "accountingConstants": accounting_constants(),
        "metadataSubledger": copy.deepcopy(METADATA_SUBLEDGER),
        "attemptPolicy": copy.deepcopy(ATTEMPT_POLICY),
        "timingSemantics": copy.deepcopy(TIMING_SEMANTICS),
        "validationEquations": list(VALIDATION_EQUATIONS),
        "timingProof": {
            "candidateDefault": dict(EXPECTED_TIMING_REQUIREMENTS["defaults"]),
            "hardEnvelope": dict(EXPECTED_TIMING_REQUIREMENTS["hardCeilings"]),
        },
        "accountingProof": {
            "default": accounting_proof(DEFAULTS),
            "hardEnvelope": accounting_proof(CEILINGS),
        },
        "vectors": policy_validation_vectors(),
        "timingBoundaryVectors": timing_validator_vectors(assert_results=True),
        "wireBoundaryVectors": copy.deepcopy(WIRE_BOUNDARY_VECTORS),
    }


def percentile(samples: list[float], p: float) -> float:
    ordered = sorted(samples)
    if not ordered:
        return 0.0
    rank = (len(ordered) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (rank - lower)


def distribution(samples_seconds: list[float]) -> dict[str, float | int]:
    ms = [sample * 1000.0 for sample in samples_seconds]
    return {
        "count": len(ms),
        "minMilliseconds": round(min(ms), 3),
        "medianMilliseconds": round(statistics.median(ms), 3),
        "p95Milliseconds": round(percentile(ms, 0.95), 3),
        "p99Milliseconds": round(percentile(ms, 0.99), 3),
        "maxMilliseconds": round(max(ms), 3),
    }


def dns_query(identifier: int) -> bytes:
    qname = b"\x07example\x04test\x00"
    return (
        struct.pack("!HHHHHH", identifier, 0x0100, 1, 0, 0, 0)
        + qname
        + struct.pack("!HH", 1, 1)
    )


def dns_message_at_size(identifier: int, size: int) -> bytes:
    base = dns_query(identifier)
    if size == len(base):
        return base
    # Construct a syntactically bounded QUERY with one OPT RR containing an
    # EDNS Padding option, rather than appending parser-invisible junk. OPT's
    # 11-byte fixed form plus the four-byte option header leaves the remainder
    # as padding data and reaches the exact requested transport boundary.
    padding_bytes = size - len(base) - 15
    if padding_bytes < 0 or padding_bytes > 65_490 or size > 65_535:
        raise ValueError(
            "DNS fixture message size cannot be encoded as one padded OPT RR"
        )
    header = struct.pack("!HHHHHH", identifier, 0x0100, 1, 0, 0, 1)
    question = base[12:]
    option = struct.pack("!HH", 12, padding_bytes) + bytes(padding_bytes)
    opt = b"\x00" + struct.pack("!HHIH", 41, 4096, 0, len(option)) + option
    message = header + question + opt
    if len(message) != size:
        raise AssertionError("padded DNS fixture size mismatch")
    return message


def validate_wire_message_length(size: int, maximum: int = 65_535) -> None:
    if size < 1 or size > maximum:
        raise ValueError("DNS message length is outside the accepted wire range")


def dns_response(query: bytes, *, truncated: bool = False) -> bytes:
    identifier, _, questions, _, authority, additional = struct.unpack(
        "!HHHHHH", query[:12]
    )
    flags = 0x8180 | (0x0200 if truncated else 0)
    return (
        struct.pack("!HHHHHH", identifier, flags, questions, 0, authority, additional)
        + query[12:]
    )


def recv_exact(connection: socket.socket, count: int) -> bytes:
    data = bytearray()
    while len(data) < count:
        chunk = connection.recv(count - len(data))
        if not chunk:
            raise EOFError(f"expected {count} bytes, received {len(data)}")
        data.extend(chunk)
    return bytes(data)


class TCPFixture:
    def __init__(
        self,
        family: int,
        mode: str = "valid",
        delay_seconds: float = 0.0,
        batch_size: int = 1,
        requested_port: int = 0,
    ) -> None:
        self.family = family
        self.mode = mode
        self.delay_seconds = delay_seconds
        self.batch_size = batch_size
        self.socket = socket.socket(family, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        host = "127.0.0.1" if family == socket.AF_INET else "::1"
        self.socket.bind((host, requested_port))
        self.socket.listen(16)
        self.socket.settimeout(0.1)
        self.host = host
        self.port = self.socket.getsockname()[1]
        self.stop_event = threading.Event()
        self.channel_opens = 0
        self.messages_received = 0
        self.thread = threading.Thread(
            target=self._run, name=f"tcp-fixture-{mode}", daemon=True
        )

    def start(self) -> "TCPFixture":
        self.thread.start()
        return self

    def endpoint(self) -> tuple[str, int, int]:
        return (self.host, self.port, self.family)

    def _run(self) -> None:
        while not self.stop_event.is_set():
            try:
                connection, _ = self.socket.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            self.channel_opens += 1
            thread = threading.Thread(
                target=self._handle, args=(connection,), daemon=True
            )
            thread.start()

    def _handle(self, connection: socket.socket) -> None:
        with connection:
            connection.settimeout(2.0)
            if self.mode == "stall-open":
                time.sleep(self.delay_seconds)
                return
            queries: list[bytes] = []
            try:
                while not self.stop_event.is_set():
                    length_data = recv_exact(connection, TCP_FRAME_BYTES)
                    length = struct.unpack("!H", length_data)[0]
                    query = recv_exact(connection, length)
                    self.messages_received += 1
                    queries.append(query)
                    if self.mode == "close-after-first":
                        return
                    if self.mode == "malformed":
                        connection.sendall(struct.pack("!H", 10) + b"bad")
                        return
                    if self.mode == "stall-response":
                        time.sleep(self.delay_seconds)
                        continue
                    if self.mode == "batch-valid" and len(queries) < self.batch_size:
                        continue
                    if self.delay_seconds:
                        time.sleep(self.delay_seconds)
                    response_queries = (
                        list(reversed(queries))
                        if self.mode == "batch-valid"
                        else queries
                    )
                    for item in response_queries:
                        response = dns_response(item)
                        connection.sendall(struct.pack("!H", len(response)) + response)
                    queries.clear()
            except (EOFError, OSError, socket.timeout):
                return

    def close(self) -> None:
        self.stop_event.set()
        try:
            self.socket.close()
        finally:
            self.thread.join(timeout=1.0)


class UDPFixture:
    def __init__(self, family: int, mode: str, requested_port: int = 0) -> None:
        self.family = family
        self.mode = mode
        self.socket = socket.socket(family, socket.SOCK_DGRAM)
        host = "127.0.0.1" if family == socket.AF_INET else "::1"
        self.socket.bind((host, requested_port))
        self.socket.settimeout(0.1)
        self.host = host
        self.port = self.socket.getsockname()[1]
        self.stop_event = threading.Event()
        self.transmissions = 0
        self.thread = threading.Thread(
            target=self._run, name=f"udp-fixture-{mode}", daemon=True
        )

    def start(self) -> "UDPFixture":
        self.thread.start()
        return self

    def _run(self) -> None:
        while not self.stop_event.is_set():
            try:
                query, peer = self.socket.recvfrom(65_535)
            except socket.timeout:
                continue
            except OSError:
                return
            self.transmissions += 1
            if self.mode == "timeout":
                continue
            if self.mode == "malformed":
                self.socket.sendto(b"bad", peer)
                continue
            self.socket.sendto(
                dns_response(query, truncated=self.mode == "truncated"), peer
            )

    def close(self) -> None:
        self.stop_event.set()
        try:
            self.socket.close()
        finally:
            self.thread.join(timeout=1.0)


def tcp_exchange(
    endpoint: tuple[str, int, int], identifier: int, timeout: float = 1.0
) -> bytes:
    host, port, family = endpoint
    query = dns_query(identifier)
    with socket.socket(family, socket.SOCK_STREAM) as connection:
        connection.settimeout(timeout)
        connection.connect((host, port))
        connection.sendall(struct.pack("!H", len(query)) + query)
        response_length = struct.unpack("!H", recv_exact(connection, TCP_FRAME_BYTES))[
            0
        ]
        if response_length > CEILINGS["maxDNSMessageBytes"]:
            raise ValueError("response exceeds DNS message ceiling")
        response = recv_exact(connection, response_length)
    if response[:2] != query[:2] or response[12:] != query[12:]:
        raise ValueError("response correlation mismatch")
    return response


def tcp_framing_boundaries(fixture: TCPFixture) -> dict[str, Any]:
    exact = dns_message_at_size(0x5100, 65_535)
    with socket.socket(fixture.family, socket.SOCK_STREAM) as connection:
        connection.settimeout(2.0)
        connection.connect((fixture.host, fixture.port))
        prefix = struct.pack("!H", len(exact))
        connection.sendall(prefix[:1])
        connection.sendall(prefix[1:])
        for start in range(0, len(exact), 997):
            connection.sendall(exact[start : start + 997])
        response_length = struct.unpack("!H", recv_exact(connection, TCP_FRAME_BYTES))[
            0
        ]
        response = recv_exact(connection, response_length)
    if response_length != 65_535 or len(response) != 65_535:
        raise AssertionError("maximum DNS/TCP frame was not returned intact")

    partial = dns_query(0x5101)
    with socket.socket(fixture.family, socket.SOCK_STREAM) as connection:
        connection.settimeout(2.0)
        connection.connect((fixture.host, fixture.port))
        framed = struct.pack("!H", len(partial)) + partial
        for octet in framed:
            connection.sendall(bytes([octet]))
        response_length = struct.unpack("!H", recv_exact(connection, TCP_FRAME_BYTES))[
            0
        ]
        partial_response = recv_exact(connection, response_length)
    if len(partial_response) != len(partial):
        raise AssertionError("partial-write frame changed length")

    first = dns_query(0x5102)
    second = dns_query(0x5103)
    coalesced = (
        struct.pack("!H", len(first)) + first + struct.pack("!H", len(second)) + second
    )
    with socket.socket(fixture.family, socket.SOCK_STREAM) as connection:
        connection.settimeout(2.0)
        connection.connect((fixture.host, fixture.port))
        connection.sendall(coalesced)
        response_ids: list[int] = []
        for _ in range(2):
            response_length = struct.unpack(
                "!H", recv_exact(connection, TCP_FRAME_BYTES)
            )[0]
            item = recv_exact(connection, response_length)
            response_ids.append(struct.unpack("!H", item[:2])[0])
    if response_ids != [0x5102, 0x5103]:
        raise AssertionError("coalesced frames were not parsed independently")

    validate_wire_message_length(65_535)
    rejected = False
    try:
        validate_wire_message_length(65_536)
    except ValueError:
        rejected = True
    if not rejected:
        raise AssertionError("one-byte-over DNS message was accepted")
    return {
        "maximumMessageBytesAccepted": len(response),
        "maximumWireFrameBytesAccepted": len(response) + TCP_FRAME_BYTES,
        "oneByteOverMessageBytesRejected": 65_536,
        "splitPrefixChunks": 2,
        "splitBodyChunkBytes": 997,
        "partialWriteBytes": len(framed),
        "coalescedFramesParsed": len(response_ids),
    }


def tcp_failover(
    endpoints: list[tuple[str, int, int]], timeout: float = 0.25
) -> tuple[int, bytes]:
    last_error: Exception | None = None
    for index, endpoint in enumerate(endpoints):
        try:
            return index + 1, tcp_exchange(endpoint, 0x2200 + index, timeout)
        except (OSError, EOFError, ValueError, socket.timeout) as error:
            last_error = error
    raise RuntimeError("all endpoints failed") from last_error


def retry_batch(
    failing: TCPFixture,
    succeeding: TCPFixture,
    count: int,
) -> dict[str, int]:
    queries = [dns_query(0x3000 + index) for index in range(count)]
    first_failed = False
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
        connection.settimeout(0.5)
        connection.connect((failing.host, failing.port))
        for query in queries:
            try:
                connection.sendall(struct.pack("!H", len(query)) + query)
            except OSError:
                break
        try:
            recv_exact(connection, TCP_FRAME_BYTES)
        except (OSError, EOFError, socket.timeout):
            first_failed = True
    if not first_failed:
        raise AssertionError("failure fixture did not retire the epoch")

    received: list[bytes] = []
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
        connection.settimeout(1.0)
        connection.connect((succeeding.host, succeeding.port))
        for query in queries:
            connection.sendall(struct.pack("!H", len(query)) + query)
        for _ in queries:
            response_length = struct.unpack(
                "!H", recv_exact(connection, TCP_FRAME_BYTES)
            )[0]
            response = recv_exact(connection, response_length)
            received.append(response)
    received_ids = [struct.unpack("!H", response[:2])[0] for response in received]
    duplicate_attempts = len(received_ids) - len(set(received_ids))
    return {
        "logicalQueries": count,
        "firstEpochChannelOpens": failing.channel_opens,
        "promotedEpochChannelOpens": succeeding.channel_opens,
        "retryBatchQueries": count,
        "terminalResponses": len(received),
        "duplicateDeliveryAttemptsBeforeDedup": duplicate_attempts,
    }


def udp_then_optional_tcp(
    udp_fixture: UDPFixture,
    tcp_fixture: TCPFixture,
    identifier: int,
    timeout: float = 0.05,
) -> dict[str, Any]:
    query = dns_query(identifier)
    tcp_attempts = 0
    udp_valid = False
    trigger = "none"
    visible_responses = 0
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        client.settimeout(timeout)
        client.sendto(query, (udp_fixture.host, udp_fixture.port))
        try:
            response, _ = client.recvfrom(65_535)
            if (
                len(response) >= 12
                and response[:2] == query[:2]
                and response[12:] == query[12:]
            ):
                udp_valid = True
                if struct.unpack("!H", response[2:4])[0] & 0x0200:
                    trigger = "truncated"
                else:
                    visible_responses = 1
            else:
                trigger = "malformed"
        except socket.timeout:
            trigger = "timeout"
    if trigger in {"truncated", "timeout"}:
        tcp_attempts += 1
        tcp_exchange(tcp_fixture.endpoint(), identifier, timeout=1.0)
        visible_responses = 1
    return {
        "udpAttempts": 1,
        "udpValid": udp_valid,
        "tcpTrigger": trigger,
        "tcpAttempts": tcp_attempts,
        "visibleResponses": visible_responses,
    }


class RUsageInfoV4(ctypes.Structure):
    _fields_ = [
        ("ri_uuid", ctypes.c_ubyte * 16),
        ("ri_user_time", ctypes.c_uint64),
        ("ri_system_time", ctypes.c_uint64),
        ("ri_pkg_idle_wkups", ctypes.c_uint64),
        ("ri_interrupt_wkups", ctypes.c_uint64),
        ("ri_pageins", ctypes.c_uint64),
        ("ri_wired_size", ctypes.c_uint64),
        ("ri_resident_size", ctypes.c_uint64),
        ("ri_phys_footprint", ctypes.c_uint64),
        ("remainder", ctypes.c_uint64 * 64),
    ]


def physical_footprint_bytes() -> int | None:
    if sys.platform != "darwin":
        return None
    libproc = ctypes.CDLL("/usr/lib/libproc.dylib")
    info = RUsageInfoV4()
    result = libproc.proc_pid_rusage(os.getpid(), 4, ctypes.byref(info))
    return int(info.ri_phys_footprint) if result == 0 else None


def fd_count() -> int:
    return len(os.listdir("/dev/fd"))


class OwnershipTracker:
    """Observed ownership counters used by fixtures and allocation trials."""

    FIELDS = (
        "transactions",
        "queuedWireBytes",
        "reservationBytes",
        "tombstones",
        "connections",
        "connectionBufferBytes",
        "fixedComponentBytes",
    )

    def __init__(self) -> None:
        self.current = {field: 0 for field in self.FIELDS}
        self.peak = {field: 0 for field in self.FIELDS}

    def change(self, field: str, delta: int) -> None:
        if field not in self.current:
            raise KeyError(field)
        updated = self.current[field] + delta
        if updated < 0:
            raise AssertionError(f"negative ownership counter {field}: {updated}")
        self.current[field] = updated
        self.peak[field] = max(self.peak[field], updated)

    def snapshot(self) -> dict[str, int]:
        snapshot = dict(self.current)
        snapshot["liveTrackedBytes"] = (
            snapshot["queuedWireBytes"]
            + snapshot["reservationBytes"]
            + snapshot["connectionBufferBytes"]
            + snapshot["fixedComponentBytes"]
        )
        return snapshot

    def peak_snapshot(self) -> dict[str, int]:
        snapshot = dict(self.peak)
        snapshot["liveTrackedBytes"] = (
            snapshot["queuedWireBytes"]
            + snapshot["reservationBytes"]
            + snapshot["connectionBufferBytes"]
            + snapshot["fixedComponentBytes"]
        )
        return snapshot

    def assert_zero(self) -> None:
        if any(self.current.values()):
            raise AssertionError(f"ownership counters did not clean up: {self.current}")


class TransactionOwnerSimulation:
    def __init__(self, policy: dict[str, int], *, logical_queries: int = 1) -> None:
        self.policy = policy
        self.logical_queries = logical_queries
        self.tracker = OwnershipTracker()
        self.states: dict[int, str] = {}
        self.events: list[dict[str, Any]] = []
        self.visible_responses = 0
        self.duplicate_delivery_attempts_before_dedup = 0
        self.late_callbacks_suppressed = 0
        self.tcp_attempts: list[int] = []
        self.udp_attempts = 0
        self.udp_transmissions = 0
        self.terminal_owners: list[int] = []
        self.terminal_outcomes: list[str] = []
        self.cancellations = 0
        self.tombstones_created = 0
        self.tombstones_retired = 0
        self.connection_epochs_opened = 0
        self.coordinated_retry_batches = 0

    def record(
        self, event: str, owner: int | None = None, endpoint_ordinal: int | None = None
    ) -> None:
        item: dict[str, Any] = {"sequence": len(self.events) + 1, "event": event}
        if owner is not None:
            item["ownerOrdinal"] = owner
        if endpoint_ordinal is not None:
            item["endpointOrdinal"] = endpoint_ordinal
        item["ownership"] = self.tracker.snapshot()
        self.events.append(item)

    def open_connection(self, endpoint_ordinal: int) -> None:
        self.connection_epochs_opened += 1
        self.tracker.change("connections", 1)
        self.tracker.change(
            "connectionBufferBytes",
            CONNECTION_READ_BUFFER_BYTES + CONNECTION_WRITE_BUFFER_BYTES,
        )
        self.record("tcp-connection-open", endpoint_ordinal=endpoint_ordinal)

    def close_connection(
        self, endpoint_ordinal: int, event: str = "tcp-connection-close"
    ) -> None:
        self.tracker.change("connections", -1)
        self.tracker.change(
            "connectionBufferBytes",
            -(CONNECTION_READ_BUFFER_BYTES + CONNECTION_WRITE_BUFFER_BYTES),
        )
        self.record(event, endpoint_ordinal=endpoint_ordinal)

    def admit(self, owner: int) -> None:
        if owner in self.states:
            raise AssertionError("owner admitted twice")
        self.states[owner] = "live"
        self.tracker.change("transactions", 1)
        self.tracker.change("reservationBytes", per_query_reservation(self.policy))
        self.record("owner-admitted", owner)

    def queue(self, owner: int, byte_count: int) -> None:
        self.tracker.change("queuedWireBytes", byte_count)
        self.record("request-queued", owner)

    def dequeue(self, owner: int, byte_count: int) -> None:
        self.tracker.change("queuedWireBytes", -byte_count)
        self.record("request-dequeued", owner)

    def udp_attempt(self, owner: int, *, transmitted: bool) -> None:
        self.udp_attempts += 1
        if transmitted:
            self.udp_transmissions += 1
        self.record("udp-attempt" if transmitted else "udp-pre-send-failure", owner)

    def tcp_attempt(self, owner: int, endpoint_ordinal: int) -> None:
        self.tcp_attempts.append(endpoint_ordinal)
        self.record("tcp-attempt", owner, endpoint_ordinal)

    def response(self, owner: int, transport: str) -> None:
        state = self.states[owner]
        if state != "live":
            self.duplicate_delivery_attempts_before_dedup += 1
            self.late_callbacks_suppressed += 1
            self.record(f"late-{transport}-callback-suppressed", owner)
            return
        self.states[owner] = "responded"
        terminal_event = f"{transport}-response-terminal"
        self.terminal_owners.append(owner)
        self.terminal_outcomes.append(terminal_event)
        self.visible_responses += 1
        self.tracker.change("transactions", -1)
        self.tracker.change("reservationBytes", -per_query_reservation(self.policy))
        self.record(terminal_event, owner)

    def fail(self, owner: int, event: str) -> None:
        if self.states[owner] != "live":
            self.record(f"{event}-ignored-terminal", owner)
            return
        self.states[owner] = "failed"
        self.terminal_owners.append(owner)
        self.terminal_outcomes.append(event)
        self.tracker.change("transactions", -1)
        self.tracker.change("reservationBytes", -per_query_reservation(self.policy))
        self.record(event, owner)

    def cancel(self, owner: int) -> None:
        if self.states[owner] != "live":
            raise AssertionError("only a live owner can be cancelled")
        self.states[owner] = "cancelled-tombstoned"
        self.terminal_owners.append(owner)
        self.terminal_outcomes.append("owner-cancelled-tombstoned")
        self.cancellations += 1
        self.tombstones_created += 1
        self.tracker.change("tombstones", 1)
        self.record("owner-cancelled-tombstoned", owner)

    def retire_tombstone(self, owner: int, event: str) -> None:
        if self.states[owner] != "cancelled-tombstoned":
            raise AssertionError("owner has no live tombstone")
        self.states[owner] = "cancelled-retired"
        self.tombstones_retired += 1
        self.tracker.change("tombstones", -1)
        self.tracker.change("transactions", -1)
        self.tracker.change("reservationBytes", -per_query_reservation(self.policy))
        self.record(event, owner)

    def result(self) -> dict[str, Any]:
        self.tracker.assert_zero()
        return {
            "logicalQueries": self.logical_queries,
            "udpAttempts": self.udp_attempts,
            "udpTransmissions": self.udp_transmissions,
            "tcpAttempts": len(self.tcp_attempts),
            "tcpEndpointOrdinals": self.tcp_attempts,
            "visibleResponses": self.visible_responses,
            "terminalCount": len(self.terminal_owners),
            "terminalOwners": self.terminal_owners,
            "terminalOutcomes": self.terminal_outcomes,
            "duplicateDeliveryAttemptsBeforeDedup": self.duplicate_delivery_attempts_before_dedup,
            "lateCallbacksSuppressed": self.late_callbacks_suppressed,
            "cancellations": self.cancellations,
            "tombstonesCreated": self.tombstones_created,
            "tombstonesRetired": self.tombstones_retired,
            "connectionEpochsOpened": self.connection_epochs_opened,
            "coordinatedRetryBatches": self.coordinated_retry_batches,
            "peakOwnership": self.tracker.peak_snapshot(),
            "cleanupOwnership": self.tracker.snapshot(),
            "eventTrace": self.events,
        }


def memory_trial(policy: dict[str, int]) -> dict[str, Any]:
    gc.collect()
    baseline_footprint = physical_footprint_bytes()
    baseline_fds = fd_count()
    ownership = OwnershipTracker()
    reservation = per_query_reservation(policy)
    buffers = []
    for _ in range(policy["maxInFlightQueries"]):
        buffers.append(bytearray(reservation))
        ownership.change("transactions", 1)
        ownership.change("reservationBytes", reservation)
    queue = bytearray(policy["maxQueuedWireBytes"])
    ownership.change("queuedWireBytes", len(queue))
    read_buffer = bytearray(CONNECTION_READ_BUFFER_BYTES)
    write_buffer = bytearray(CONNECTION_WRITE_BUFFER_BYTES)
    ownership.change("connections", 1)
    ownership.change("connectionBufferBytes", len(read_buffer) + len(write_buffer))
    manager = bytearray(MANAGER_BASE_BYTES)
    diagnostics = bytearray(DIAGNOSTICS_RESERVE_BYTES)
    endpoints = bytearray(ENDPOINT_METADATA_BYTES * policy["maxConfiguredEndpoints"])
    ownership.change(
        "fixedComponentBytes", len(manager) + len(diagnostics) + len(endpoints)
    )
    for allocation in buffers + [
        queue,
        read_buffer,
        write_buffer,
        manager,
        diagnostics,
        endpoints,
    ]:
        if allocation:
            allocation[0] = 1
            allocation[-1] = 1
            for offset in range(0, len(allocation), 4096):
                allocation[offset] = 1
    peak_footprint = physical_footprint_bytes()
    allocated_bytes = sum(map(len, buffers)) + sum(
        map(len, [queue, read_buffer, write_buffer, manager, diagnostics, endpoints])
    )
    peak_ownership = ownership.peak_snapshot()
    ownership.change("queuedWireBytes", -len(queue))
    ownership.change("connectionBufferBytes", -(len(read_buffer) + len(write_buffer)))
    ownership.change("connections", -1)
    ownership.change(
        "fixedComponentBytes", -(len(manager) + len(diagnostics) + len(endpoints))
    )
    for _ in buffers:
        ownership.change("transactions", -1)
        ownership.change("reservationBytes", -reservation)
    del buffers, queue, read_buffer, write_buffer, manager, diagnostics, endpoints
    gc.collect()
    ownership.assert_zero()
    cleanup_ownership = ownership.snapshot()
    cleanup_footprint = physical_footprint_bytes()
    cleanup_fds = fd_count()
    return {
        "ledgerAccountedBytes": ledger(policy)["accountedBytes"],
        "allocatedBytes": allocated_bytes,
        "constructedEnvelopeMatchesLedger": allocated_bytes
        == ledger(policy)["accountedBytes"],
        "baselinePhysicalFootprintBytes": baseline_footprint,
        "peakPhysicalFootprintBytes": peak_footprint,
        "incrementalPhysicalFootprintBytes": (
            peak_footprint - baseline_footprint
            if peak_footprint is not None and baseline_footprint is not None
            else None
        ),
        "cleanupPhysicalFootprintBytes": cleanup_footprint,
        "baselineOpenFileDescriptors": baseline_fds,
        "cleanupOpenFileDescriptors": cleanup_fds,
        "openFileDescriptorDeltaAfterCleanup": cleanup_fds - baseline_fds,
        "peakOwnership": peak_ownership,
        "cleanupOwnership": cleanup_ownership,
        "liveTrackedAllocationBytesAfterCleanup": cleanup_ownership["liveTrackedBytes"],
        "processPeakRSSBytes": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    }


def closed_loopback_endpoint(family: int = socket.AF_INET) -> tuple[str, int, int]:
    host = "127.0.0.1" if family == socket.AF_INET else "::1"
    probe = socket.socket(family, socket.SOCK_STREAM)
    probe.bind((host, 0))
    endpoint = (host, probe.getsockname()[1], family)
    probe.close()
    return endpoint


def simulate_concurrent_connection_failure(count: int) -> dict[str, Any]:
    simulation = TransactionOwnerSimulation(DEFAULTS, logical_queries=count)
    frame_bytes = len(dns_query(0)) + TCP_FRAME_BYTES
    simulation.open_connection(1)
    for owner in range(1, count + 1):
        simulation.admit(owner)
        simulation.queue(owner, frame_bytes)
        simulation.dequeue(owner, frame_bytes)
        simulation.tcp_attempt(owner, 1)
    simulation.close_connection(1, "epoch-one-connection-fatal")
    simulation.coordinated_retry_batches += 1
    simulation.open_connection(2)
    for owner in range(1, count + 1):
        simulation.tcp_attempt(owner, 2)
    for owner in reversed(range(1, count + 1)):
        simulation.response(owner, "tcp")
    # Record an actually attempted late delivery before suppression. A map or
    # set is deliberately not used, so the evidence cannot erase duplicates.
    simulation.response(1, "retired-epoch-tcp")
    simulation.close_connection(2)
    return simulation.result()


def simulate_cancellation_race() -> dict[str, Any]:
    simulation = TransactionOwnerSimulation(DEFAULTS)
    frame_bytes = len(dns_query(0)) + TCP_FRAME_BYTES
    simulation.open_connection(1)
    simulation.admit(1)
    simulation.queue(1, frame_bytes)
    simulation.dequeue(1, frame_bytes)
    simulation.tcp_attempt(1, 1)
    simulation.cancel(1)
    simulation.response(1, "tcp")
    simulation.retire_tombstone(1, "late-response-consumed-tombstone-retired")
    simulation.close_connection(1)
    return simulation.result()


def simulate_duplicate_delivery() -> dict[str, Any]:
    simulation = TransactionOwnerSimulation(DEFAULTS)
    simulation.admit(1)
    simulation.response(1, "tcp")
    simulation.response(1, "tcp")
    return simulation.result()


def simulate_m2(
    trigger: str,
    *,
    promote: bool = False,
    late_udp: bool = False,
    cancel_during_tcp: bool = False,
) -> dict[str, Any]:
    simulation = TransactionOwnerSimulation(DEFAULTS)
    simulation.admit(1)
    transmitted = trigger not in {"datagram-size", "relay-association-failure"}
    simulation.udp_attempt(1, transmitted=transmitted)

    if trigger == "valid":
        simulation.response(1, "udp")
        return simulation.result()
    if trigger in {"malformed", "mismatched"}:
        simulation.fail(1, f"udp-{trigger}-terminal-no-shopping")
        return simulation.result()

    fallback_triggers = {
        "truncated",
        "datagram-size",
        "udp-timeout",
        "relay-association-failure",
        "relay-session-failure",
    }
    if trigger not in fallback_triggers:
        raise ValueError(f"unsupported M2 trigger: {trigger}")

    simulation.open_connection(1)
    simulation.tcp_attempt(1, 1)
    if cancel_during_tcp:
        simulation.cancel(1)
        simulation.response(1, "tcp")
        simulation.retire_tombstone(1, "tcp-late-response-consumed-after-cancel")
        simulation.close_connection(1)
        return simulation.result()
    if promote:
        simulation.close_connection(1, "same-endpoint-tcp-connection-fatal")
        simulation.open_connection(2)
        simulation.tcp_attempt(1, 2)
        simulation.response(1, "tcp-promoted-endpoint")
        simulation.close_connection(2)
    else:
        simulation.response(1, "tcp-same-endpoint")
        simulation.close_connection(1)
    if late_udp:
        simulation.response(1, "udp")
    return simulation.result()


def trace_item(
    event: str, owner: int | None = None, endpoint_ordinal: int | None = None
) -> dict[str, Any]:
    item: dict[str, Any] = {"event": event}
    if owner is not None:
        item["ownerOrdinal"] = owner
    if endpoint_ordinal is not None:
        item["endpointOrdinal"] = endpoint_ordinal
    return item


def event_trace_signature(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            key: event[key]
            for key in ("event", "ownerOrdinal", "endpointOrdinal")
            if key in event
        }
        for event in events
    ]


def zero_cleanup_ownership() -> dict[str, int]:
    result = {field: 0 for field in OwnershipTracker.FIELDS}
    result["liveTrackedBytes"] = 0
    return result


def reliability_expectation(
    *,
    logical_queries: int,
    udp_attempts: int,
    udp_transmissions: int,
    tcp_endpoint_ordinals: list[int],
    visible_responses: int,
    terminal_owners: list[int],
    terminal_outcomes: list[str],
    duplicate_attempts: int,
    late_callbacks: int,
    cancellations: int,
    tombstones_created: int,
    tombstones_retired: int,
    connection_epochs: int,
    coordinated_retry_batches: int,
    trace: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "logicalQueries": logical_queries,
        "udpAttempts": udp_attempts,
        "udpTransmissions": udp_transmissions,
        "tcpAttempts": len(tcp_endpoint_ordinals),
        "tcpEndpointOrdinals": tcp_endpoint_ordinals,
        "visibleResponses": visible_responses,
        "terminalCount": len(terminal_owners),
        "terminalOwners": terminal_owners,
        "terminalOutcomes": terminal_outcomes,
        "duplicateDeliveryAttemptsBeforeDedup": duplicate_attempts,
        "lateCallbacksSuppressed": late_callbacks,
        "cancellations": cancellations,
        "tombstonesCreated": tombstones_created,
        "tombstonesRetired": tombstones_retired,
        "connectionEpochsOpened": connection_epochs,
        "coordinatedRetryBatches": coordinated_retry_batches,
        "cleanupOwnership": zero_cleanup_ownership(),
        "eventTraceSignature": trace,
    }


def expected_reliability_matrix() -> dict[str, dict[str, Any]]:
    count = DEFAULTS["maxInFlightQueries"]
    concurrent_trace = [trace_item("tcp-connection-open", endpoint_ordinal=1)]
    for owner in range(1, count + 1):
        concurrent_trace.extend(
            [
                trace_item("owner-admitted", owner),
                trace_item("request-queued", owner),
                trace_item("request-dequeued", owner),
                trace_item("tcp-attempt", owner, 1),
            ]
        )
    concurrent_trace.extend(
        [
            trace_item("epoch-one-connection-fatal", endpoint_ordinal=1),
            trace_item("tcp-connection-open", endpoint_ordinal=2),
        ]
    )
    concurrent_trace.extend(
        trace_item("tcp-attempt", owner, 2) for owner in range(1, count + 1)
    )
    concurrent_trace.extend(
        trace_item("tcp-response-terminal", owner)
        for owner in reversed(range(1, count + 1))
    )
    concurrent_trace.extend(
        [
            trace_item("late-retired-epoch-tcp-callback-suppressed", 1),
            trace_item("tcp-connection-close", endpoint_ordinal=2),
        ]
    )

    def m2(
        *,
        udp_event: str,
        udp_transmissions: int,
        tcp_endpoints: list[int],
        terminal_event: str,
        visible_responses: int = 1,
        duplicate_attempts: int = 0,
        late_callbacks: int = 0,
        cancellations: int = 0,
        tombstones: int = 0,
        connection_epochs: int = 0,
        trace_tail: list[dict[str, Any]],
    ) -> dict[str, Any]:
        return reliability_expectation(
            logical_queries=1,
            udp_attempts=1,
            udp_transmissions=udp_transmissions,
            tcp_endpoint_ordinals=tcp_endpoints,
            visible_responses=visible_responses,
            terminal_owners=[1],
            terminal_outcomes=[terminal_event],
            duplicate_attempts=duplicate_attempts,
            late_callbacks=late_callbacks,
            cancellations=cancellations,
            tombstones_created=tombstones,
            tombstones_retired=tombstones,
            connection_epochs=connection_epochs,
            coordinated_retry_batches=0,
            trace=[trace_item("owner-admitted", 1), trace_item(udp_event, 1)]
            + trace_tail,
        )

    return {
        "concurrentConnectionFailure": reliability_expectation(
            logical_queries=count,
            udp_attempts=0,
            udp_transmissions=0,
            tcp_endpoint_ordinals=[1] * count + [2] * count,
            visible_responses=count,
            terminal_owners=list(reversed(range(1, count + 1))),
            terminal_outcomes=["tcp-response-terminal"] * count,
            duplicate_attempts=1,
            late_callbacks=1,
            cancellations=0,
            tombstones_created=0,
            tombstones_retired=0,
            connection_epochs=2,
            coordinated_retry_batches=1,
            trace=concurrent_trace,
        ),
        "cancellationTombstoneLateResponse": reliability_expectation(
            logical_queries=1,
            udp_attempts=0,
            udp_transmissions=0,
            tcp_endpoint_ordinals=[1],
            visible_responses=0,
            terminal_owners=[1],
            terminal_outcomes=["owner-cancelled-tombstoned"],
            duplicate_attempts=1,
            late_callbacks=1,
            cancellations=1,
            tombstones_created=1,
            tombstones_retired=1,
            connection_epochs=1,
            coordinated_retry_batches=0,
            trace=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("owner-admitted", 1),
                trace_item("request-queued", 1),
                trace_item("request-dequeued", 1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("owner-cancelled-tombstoned", 1),
                trace_item("late-tcp-callback-suppressed", 1),
                trace_item("late-response-consumed-tombstone-retired", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "duplicateDeliveryDetection": reliability_expectation(
            logical_queries=1,
            udp_attempts=0,
            udp_transmissions=0,
            tcp_endpoint_ordinals=[],
            visible_responses=1,
            terminal_owners=[1],
            terminal_outcomes=["tcp-response-terminal"],
            duplicate_attempts=1,
            late_callbacks=1,
            cancellations=0,
            tombstones_created=0,
            tombstones_retired=0,
            connection_epochs=0,
            coordinated_retry_batches=0,
            trace=[
                trace_item("owner-admitted", 1),
                trace_item("tcp-response-terminal", 1),
                trace_item("late-tcp-callback-suppressed", 1),
            ],
        ),
        "m2ValidUDP": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[],
            terminal_event="udp-response-terminal",
            trace_tail=[trace_item("udp-response-terminal", 1)],
        ),
        "m2MalformedNoShopping": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[],
            terminal_event="udp-malformed-terminal-no-shopping",
            visible_responses=0,
            trace_tail=[trace_item("udp-malformed-terminal-no-shopping", 1)],
        ),
        "m2MismatchedNoShopping": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[],
            terminal_event="udp-mismatched-terminal-no-shopping",
            visible_responses=0,
            trace_tail=[trace_item("udp-mismatched-terminal-no-shopping", 1)],
        ),
        "m2TruncatedSameEndpointTCP": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "m2DatagramSizeSameEndpointTCP": m2(
            udp_event="udp-pre-send-failure",
            udp_transmissions=0,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "m2TimeoutSameEndpointTCP": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "m2RelayAssociationFailureSameEndpointTCP": m2(
            udp_event="udp-pre-send-failure",
            udp_transmissions=0,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "m2RelaySessionFailureSameEndpointTCP": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
        "m2LaterEndpointPromotion": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1, 2],
            terminal_event="tcp-promoted-endpoint-response-terminal",
            connection_epochs=2,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("same-endpoint-tcp-connection-fatal", endpoint_ordinal=1),
                trace_item("tcp-connection-open", endpoint_ordinal=2),
                trace_item("tcp-attempt", 1, 2),
                trace_item("tcp-promoted-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=2),
            ],
        ),
        "m2LateUDPAfterTCPTerminal": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1],
            terminal_event="tcp-same-endpoint-response-terminal",
            duplicate_attempts=1,
            late_callbacks=1,
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("tcp-same-endpoint-response-terminal", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
                trace_item("late-udp-callback-suppressed", 1),
            ],
        ),
        "m2CancellationDuringTCP": m2(
            udp_event="udp-attempt",
            udp_transmissions=1,
            tcp_endpoints=[1],
            terminal_event="owner-cancelled-tombstoned",
            visible_responses=0,
            duplicate_attempts=1,
            late_callbacks=1,
            cancellations=1,
            tombstones=1,
            connection_epochs=1,
            trace_tail=[
                trace_item("tcp-connection-open", endpoint_ordinal=1),
                trace_item("tcp-attempt", 1, 1),
                trace_item("owner-cancelled-tombstoned", 1),
                trace_item("late-tcp-callback-suppressed", 1),
                trace_item("tcp-late-response-consumed-after-cancel", 1),
                trace_item("tcp-connection-close", endpoint_ordinal=1),
            ],
        ),
    }


def exact_reliability_projection(result: dict[str, Any]) -> dict[str, Any]:
    fields = (
        "logicalQueries",
        "udpAttempts",
        "udpTransmissions",
        "tcpAttempts",
        "tcpEndpointOrdinals",
        "visibleResponses",
        "terminalCount",
        "terminalOwners",
        "terminalOutcomes",
        "duplicateDeliveryAttemptsBeforeDedup",
        "lateCallbacksSuppressed",
        "cancellations",
        "tombstonesCreated",
        "tombstonesRetired",
        "connectionEpochsOpened",
        "coordinatedRetryBatches",
        "cleanupOwnership",
    )
    projection = {field: result[field] for field in fields}
    projection["eventTraceSignature"] = event_trace_signature(result["eventTrace"])
    return projection


def simulated_reliability_matrix() -> dict[str, Any]:
    matrix = {
        "concurrentConnectionFailure": simulate_concurrent_connection_failure(
            DEFAULTS["maxInFlightQueries"]
        ),
        "cancellationTombstoneLateResponse": simulate_cancellation_race(),
        "duplicateDeliveryDetection": simulate_duplicate_delivery(),
        "m2ValidUDP": simulate_m2("valid"),
        "m2MalformedNoShopping": simulate_m2("malformed"),
        "m2MismatchedNoShopping": simulate_m2("mismatched"),
        "m2TruncatedSameEndpointTCP": simulate_m2("truncated"),
        "m2DatagramSizeSameEndpointTCP": simulate_m2("datagram-size"),
        "m2TimeoutSameEndpointTCP": simulate_m2("udp-timeout"),
        "m2RelayAssociationFailureSameEndpointTCP": simulate_m2(
            "relay-association-failure"
        ),
        "m2RelaySessionFailureSameEndpointTCP": simulate_m2("relay-session-failure"),
        "m2LaterEndpointPromotion": simulate_m2("udp-timeout", promote=True),
        "m2LateUDPAfterTCPTerminal": simulate_m2("udp-timeout", late_udp=True),
        "m2CancellationDuringTCP": simulate_m2("udp-timeout", cancel_during_tcp=True),
    }
    expected = expected_reliability_matrix()
    if set(matrix) != set(expected):
        raise AssertionError(
            f"reliability scenario set drift: actual={sorted(matrix)}, expected={sorted(expected)}"
        )
    for name, result in matrix.items():
        actual_projection = exact_reliability_projection(result)
        if actual_projection != expected[name]:
            raise AssertionError(
                f"{name} exact reliability mismatch:\n"
                f"expected={json.dumps(expected[name], sort_keys=True)}\n"
                f"actual={json.dumps(actual_projection, sort_keys=True)}"
            )
        result["exactAssertion"] = {
            "passed": True,
            "eventCount": len(result["eventTrace"]),
            "eventTraceSHA256": hashlib.sha256(
                json.dumps(
                    actual_projection["eventTraceSignature"],
                    separators=(",", ":"),
                    sort_keys=True,
                ).encode("utf-8")
            ).hexdigest(),
        }
    return matrix


def environment() -> dict[str, Any]:
    git_revision = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    model = subprocess.run(
        ["sysctl", "-n", "hw.model"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "hardwareModel": model,
        "pythonVersion": platform.python_version(),
        "sourceRevision": git_revision,
        "taskID": TASK_ID,
        "privacy": "no serial number, hardware UUID, hostname, username, endpoint, or query name emitted",
    }


def self_test() -> dict[str, Any]:
    policy_results = []
    for vector in policy_validation_vectors():
        policy = dict(DEFAULTS if vector["base"] == "defaults" else CEILINGS)
        policy.update(vector.get("override", {}))
        errors = validate_policy(policy)
        if (not errors) != vector["expectedValid"]:
            raise AssertionError(
                f"{vector['name']}: expected valid={vector['expectedValid']}, errors={errors}"
            )
        if not vector["expectedValid"] and vector["expectedError"] not in errors:
            raise AssertionError(f"{vector['name']}: expected error absent: {errors}")
        if "expectedAccountedBytes" in vector:
            actual_accounted = ledger(policy)["accountedBytes"]
            if actual_accounted != vector["expectedAccountedBytes"]:
                raise AssertionError(
                    f"{vector['name']}: expected accounted bytes "
                    f"{vector['expectedAccountedBytes']}, actual={actual_accounted}"
                )
        policy_results.append(
            {
                "name": vector["name"],
                "expectedValid": vector["expectedValid"],
                "errors": errors,
            }
        )
    timing_boundary_vectors = timing_validator_vectors(assert_results=True)
    authority_negative_vectors = authority_negative_self_tests()
    wire_results = []
    for vector in WIRE_BOUNDARY_VECTORS:
        accepted = True
        try:
            validate_wire_message_length(vector["messageBytes"])
        except ValueError:
            accepted = False
        if accepted != vector["expectedAccepted"]:
            raise AssertionError(f"wire boundary mismatch: {vector}")
        wire_results.append({**vector, "actualAccepted": accepted})
    if CONNECTION_READ_BUFFER_BYTES < 65_535 + TCP_FRAME_BYTES:
        raise AssertionError("connection read buffer cannot hold maximum DNS/TCP frame")
    if CONNECTION_WRITE_BUFFER_BYTES < 65_535 + TCP_FRAME_BYTES:
        raise AssertionError(
            "connection write buffer cannot hold maximum DNS/TCP frame"
        )
    count = (
        len(policy_results)
        + len(timing_boundary_vectors)
        + len(authority_negative_vectors)
    )
    return {
        "count": count,
        "passed": count,
        "policyVectors": policy_results,
        "timingBoundaryVectors": timing_boundary_vectors,
        "authorityNegativeVectors": authority_negative_vectors,
        "wireBoundaryVectors": wire_results,
        "wireBufferMinimumBytes": 65_535 + TCP_FRAME_BYTES,
    }


def verify_policy_data(artifact: dict[str, Any]) -> dict[str, bool]:
    expected = canonical_policy_artifact()
    authorization = artifact.get("productionAuthorization")
    authorization_dict = authorization if isinstance(authorization, dict) else {}
    comparisons = {
        "topLevelFieldSet": set(artifact) == set(expected),
        "schemaVersion": artifact.get("schemaVersion") == SCHEMA_VERSION,
        "policyName": artifact.get("policyName") == POLICY_NAME,
        "taskID": artifact.get("taskID") == TASK_ID,
        "status": artifact.get("status") == POLICY_STATUS,
        "authorityClass": artifact.get("authorityClass") == AUTHORITY_CLASS,
        "candidateMeasurementsOnly": artifact.get("candidateMeasurementsOnly") is True,
        "productionAuthorization": authorization == PRODUCTION_AUTHORIZATION,
        "productionPermittedFalse": authorization_dict.get("permitted") is False,
        "adr022AcceptanceFalse": (
            authorization_dict.get("adr022MayAdvanceToAccepted") is False
        ),
        "blockingTaskIdentities": (
            authorization_dict.get("blockingTaskIDs") == BLOCKING_TASK_IDS
        ),
        "physicalEvidenceGate": (
            authorization_dict.get("physicalEvidenceGate") == PHYSICAL_EVIDENCE_GATE
        ),
        "profileStorage": artifact.get("profileStorage") == PROFILE_STORAGE,
        "defaults": artifact.get("defaults") == DEFAULTS,
        "minimums": artifact.get("minimums") == MINIMUMS,
        "hardCeilings": artifact.get("hardCeilings") == CEILINGS,
        "accountingConstants": artifact.get("accountingConstants")
        == accounting_constants(),
        "metadataSubledger": artifact.get("metadataSubledger") == METADATA_SUBLEDGER,
        "attemptPolicy": artifact.get("attemptPolicy") == ATTEMPT_POLICY,
        "timingSemantics": artifact.get("timingSemantics") == TIMING_SEMANTICS,
        "validationEquations": artifact.get("validationEquations")
        == VALIDATION_EQUATIONS,
        "timingProof": artifact.get("timingProof") == expected["timingProof"],
        "accountingProof": artifact.get("accountingProof")
        == expected["accountingProof"],
        "policyVectors": artifact.get("vectors") == expected["vectors"],
        "timingBoundaryVectors": (
            artifact.get("timingBoundaryVectors") == expected["timingBoundaryVectors"]
        ),
        "wireBoundaryVectors": artifact.get("wireBoundaryVectors")
        == WIRE_BOUNDARY_VECTORS,
        "canonicalArtifact": artifact == expected,
    }
    if not all(comparisons.values()):
        raise AssertionError(f"policy artifact drift: {comparisons}")
    return comparisons


def authority_negative_self_tests() -> list[dict[str, Any]]:
    cases: list[tuple[str, dict[str, Any]]] = []

    def mutated(name: str) -> dict[str, Any]:
        artifact = canonical_policy_artifact()
        cases.append((name, artifact))
        return artifact

    mutated("production-permitted-true")["productionAuthorization"]["permitted"] = True
    mutated("adr022-acceptance-true")["productionAuthorization"][
        "adr022MayAdvanceToAccepted"
    ] = True
    mutated("authority-class-changed")["authorityClass"] = "authoritative"
    mutated("candidate-classification-missing").pop("candidateMeasurementsOnly")
    mutated("blocking-task-identity-changed")["productionAuthorization"][
        "blockingTaskIDs"
    ][0] = "TASK-INVALID"
    mutated("physical-gate-disabled")["productionAuthorization"][
        "physicalEvidenceGate"
    ]["required"] = False
    mutated("attempt-policy-missing").pop("attemptPolicy")
    mutated("validation-equations-missing").pop("validationEquations")
    mutated("metadata-subledger-changed")["metadataSubledger"]["perQuery"][
        "reserved"
    ] = 0
    mutated("wire-vector-missing")["wireBoundaryVectors"].pop()

    results = []
    for name, artifact in cases:
        rejected = False
        try:
            verify_policy_data(artifact)
        except AssertionError:
            rejected = True
        if not rejected:
            raise AssertionError(
                f"authority negative vector unexpectedly passed: {name}"
            )
        results.append({"name": name, "expectedRejected": True, "actualRejected": True})
    return results


def verify_policy_artifact(path: Path) -> dict[str, Any]:
    artifact = json.loads(path.read_text(encoding="utf-8"))
    comparisons = verify_policy_data(artifact)
    return {"path": str(path), "passed": True, "comparisons": comparisons}


def run_measurements(warmup: int, repeats: int) -> dict[str, Any]:
    original_getaddrinfo = socket.getaddrinfo
    resolver_calls = 0

    def forbidden_getaddrinfo(*args: Any, **kwargs: Any) -> Any:
        nonlocal resolver_calls
        resolver_calls += 1
        raise AssertionError("physical/OS resolver access is forbidden in this harness")

    socket.getaddrinfo = forbidden_getaddrinfo
    fixtures: list[Any] = []
    fd_baseline = fd_count()
    report: dict[str, Any] | None = None
    try:
        ipv4 = TCPFixture(socket.AF_INET, "valid").start()
        fixtures.append(ipv4)
        ipv6_available = True
        try:
            ipv6 = TCPFixture(socket.AF_INET6, "valid").start()
            fixtures.append(ipv6)
        except OSError:
            ipv6_available = False
            ipv6 = None
        delayed = TCPFixture(socket.AF_INET, "valid", delay_seconds=0.1).start()
        fixtures.append(delayed)
        malformed = TCPFixture(socket.AF_INET, "malformed").start()
        fixtures.append(malformed)
        stalling = TCPFixture(
            socket.AF_INET, "stall-response", delay_seconds=0.2
        ).start()
        fixtures.append(stalling)

        for index in range(warmup):
            tcp_exchange(ipv4.endpoint(), 0x0100 + index)
            tcp_exchange(delayed.endpoint(), 0x0200 + index)

        ipv4_samples: list[float] = []
        delayed_samples: list[float] = []
        for index in range(repeats):
            started = time.monotonic()
            tcp_exchange(ipv4.endpoint(), 0x1000 + index)
            ipv4_samples.append(time.monotonic() - started)
            started = time.monotonic()
            tcp_exchange(delayed.endpoint(), 0x1100 + index)
            delayed_samples.append(time.monotonic() - started)

        framing_boundaries = tcp_framing_boundaries(ipv4)

        ipv6_result: dict[str, Any]
        if ipv6 is not None:
            response = tcp_exchange(ipv6.endpoint(), 0x2001)
            ipv6_result = {"available": True, "responseBytes": len(response)}
        else:
            ipv6_result = {
                "available": False,
                "reason": "host loopback IPv6 unavailable",
            }

        unreachable = closed_loopback_endpoint()
        if ipv6 is not None:
            v4_failure_then_v6_attempts, v4_failure_then_v6_response = tcp_failover(
                [closed_loopback_endpoint(socket.AF_INET), ipv6.endpoint()]
            )
            v6_failure_then_v4_attempts, v6_failure_then_v4_response = tcp_failover(
                [closed_loopback_endpoint(socket.AF_INET6), ipv4.endpoint()]
            )
            dual_ordered: dict[str, Any] = {
                "ipv4ThenIPv6": {
                    "attempts": v4_failure_then_v6_attempts,
                    "responseBytes": len(v4_failure_then_v6_response),
                },
                "ipv6ThenIPv4": {
                    "attempts": v6_failure_then_v4_attempts,
                    "responseBytes": len(v6_failure_then_v4_response),
                },
            }
        else:
            dual_ordered = {
                "available": False,
                "reason": "numeric IPv6 loopback unavailable; dual-family evidence cannot pass",
            }
        try:
            tcp_failover([unreachable], timeout=0.05)
            unreachable_result = "unexpected-success"
        except RuntimeError:
            unreachable_result = "bounded-failure"
        try:
            tcp_exchange(malformed.endpoint(), 0x2300, timeout=0.2)
            malformed_result = "unexpected-success"
        except (EOFError, OSError, ValueError, socket.timeout):
            malformed_result = "connection-fatal"
        started = time.monotonic()
        try:
            tcp_exchange(stalling.endpoint(), 0x2400, timeout=0.05)
            stall_result = "unexpected-success"
        except (EOFError, OSError, ValueError, socket.timeout):
            stall_result = "timeout-connection-fatal"
        stall_elapsed = time.monotonic() - started

        failing_batch = TCPFixture(socket.AF_INET, "close-after-first").start()
        fixtures.append(failing_batch)
        succeeding_batch = TCPFixture(
            socket.AF_INET, "batch-valid", batch_size=DEFAULTS["maxInFlightQueries"]
        ).start()
        fixtures.append(succeeding_batch)
        batch_result = retry_batch(
            failing_batch, succeeding_batch, DEFAULTS["maxInFlightQueries"]
        )
        owner_simulation = simulated_reliability_matrix()

        tcp_for_udp = TCPFixture(socket.AF_INET, "valid").start()
        fixtures.append(tcp_for_udp)
        udp_valid = UDPFixture(socket.AF_INET, "valid", tcp_for_udp.port).start()
        fixtures.append(udp_valid)
        udp_success = udp_then_optional_tcp(udp_valid, tcp_for_udp, 0x4001)
        udp_valid.close()
        fixtures.remove(udp_valid)

        udp_tc = UDPFixture(socket.AF_INET, "truncated", tcp_for_udp.port).start()
        fixtures.append(udp_tc)
        udp_truncated = udp_then_optional_tcp(udp_tc, tcp_for_udp, 0x4002)
        udp_tc.close()
        fixtures.remove(udp_tc)

        udp_timeout = UDPFixture(socket.AF_INET, "timeout", tcp_for_udp.port).start()
        fixtures.append(udp_timeout)
        udp_timed_out = udp_then_optional_tcp(udp_timeout, tcp_for_udp, 0x4003)
        udp_timeout.close()
        fixtures.remove(udp_timeout)

        udp_malformed = UDPFixture(
            socket.AF_INET, "malformed", tcp_for_udp.port
        ).start()
        fixtures.append(udp_malformed)
        udp_malformed_result = udp_then_optional_tcp(udp_malformed, tcp_for_udp, 0x4004)
        udp_malformed.close()
        fixtures.remove(udp_malformed)

        report = {
            "method": {
                "warmupIterationsPerLatencyFixture": warmup,
                "measuredIterationsPerLatencyFixture": repeats,
                "clock": "time.monotonic",
                "addresses": [
                    "numeric IPv4 loopback",
                    "numeric IPv6 loopback when available",
                ],
                "unreachableFixture": "closed numeric IPv4 loopback port",
                "externalNetwork": False,
                "publicResolver": False,
            },
            "latency": {
                "ipv4LoopbackTCP": distribution(ipv4_samples),
                "ipv4LoopbackTCPWith100msServerDelay": distribution(delayed_samples),
            },
            "fixtures": {
                "ipv4Only": {
                    "responseBytes": len(tcp_exchange(ipv4.endpoint(), 0x2100))
                },
                "ipv6Only": ipv6_result,
                "dualOrdered": dual_ordered,
                "loopback": "covered for both available families",
                "unreachable": unreachable_result,
                "malformed": malformed_result,
                "stalling": {
                    "result": stall_result,
                    "elapsedMilliseconds": round(stall_elapsed * 1000.0, 3),
                },
                "maximumWireBoundaries": framing_boundaries,
                "concurrentConnectionFailureWire": batch_result,
                "transactionOwnerSimulation": owner_simulation,
                "m2UDPValid": udp_success,
                "m2UDPTruncatedThenTCP": udp_truncated,
                "m2UDPTimeoutThenTCP": udp_timed_out,
                "m2UDPMalformedNoShopping": udp_malformed_result,
            },
            "physicalResolverSentinel": {
                "getaddrinfoCalls": resolver_calls,
                "passed": resolver_calls == 0,
                "note": "all fixture sockets use numeric loopback tuples; the sentinel aborts any hostname resolution",
            },
        }
    finally:
        socket.getaddrinfo = original_getaddrinfo
        for fixture in reversed(fixtures):
            fixture.close()
        gc.collect()
        fd_after = fd_count()
        if fd_after != fd_baseline:
            raise AssertionError(
                f"fixture descriptor leak: baseline={fd_baseline}, after={fd_after}"
            )
        if report is not None:
            report["cleanup"] = {
                "baselineOpenFileDescriptors": fd_baseline,
                "cleanupOpenFileDescriptors": fd_after,
                "openFileDescriptorDeltaAfterCleanup": fd_after - fd_baseline,
                "allOwnershipScenariosZero": all(
                    all(not value for value in scenario["cleanupOwnership"].values())
                    for scenario in report["fixtures"][
                        "transactionOwnerSimulation"
                    ].values()
                ),
            }
    if report is None:
        raise AssertionError("measurement report was not constructed")
    return report


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def summarize_measurements(paths: list[Path]) -> dict[str, Any]:
    records = [(path, json.loads(path.read_text(encoding="utf-8"))) for path in paths]
    fixture_runs = [(path, data) for path, data in records if "measurements" in data]
    memory_runs = [(path, data) for path, data in records if "memoryTrial" in data]
    if len(fixture_runs) < 3:
        raise AssertionError("summary requires at least three controlled-fixture runs")

    raw_artifacts = [
        {"path": str(path), "sha256": sha256_file(path)} for path, _ in records
    ]
    latency_summary: dict[str, Any] = {}
    for key in ("ipv4LoopbackTCP", "ipv4LoopbackTCPWith100msServerDelay"):
        medians = [
            data["measurements"]["latency"][key]["medianMilliseconds"]
            for _, data in fixture_runs
        ]
        p99s = [
            data["measurements"]["latency"][key]["p99Milliseconds"]
            for _, data in fixture_runs
        ]
        latency_summary[key] = {
            "runMediansMilliseconds": medians,
            "runP99Milliseconds": p99s,
            "medianOfRunMediansMilliseconds": statistics.median(medians),
            "maximumRunP99Milliseconds": max(p99s),
        }

    representative_fixtures = fixture_runs[0][1]["measurements"]["fixtures"]
    scenario_summary: dict[str, Any] = {}
    for name, scenario in representative_fixtures["transactionOwnerSimulation"].items():
        scenario_summary[name] = {
            "logicalQueries": scenario["logicalQueries"],
            "udpAttempts": scenario["udpAttempts"],
            "udpTransmissions": scenario["udpTransmissions"],
            "tcpAttempts": scenario["tcpAttempts"],
            "tcpEndpointOrdinals": scenario["tcpEndpointOrdinals"],
            "visibleResponses": scenario["visibleResponses"],
            "terminalCount": scenario["terminalCount"],
            "terminalOwners": scenario["terminalOwners"],
            "terminalOutcomes": scenario["terminalOutcomes"],
            "duplicateDeliveryAttemptsBeforeDedup": scenario[
                "duplicateDeliveryAttemptsBeforeDedup"
            ],
            "lateCallbacksSuppressed": scenario["lateCallbacksSuppressed"],
            "cancellations": scenario["cancellations"],
            "tombstonesCreated": scenario["tombstonesCreated"],
            "tombstonesRetired": scenario["tombstonesRetired"],
            "connectionEpochsOpened": scenario["connectionEpochsOpened"],
            "coordinatedRetryBatches": scenario["coordinatedRetryBatches"],
            "cleanupOwnership": scenario["cleanupOwnership"],
            "exactAssertion": scenario["exactAssertion"],
        }

    memory_summary: dict[str, list[dict[str, Any]]] = {"default": [], "hard": []}
    for path, data in memory_runs:
        measurement = data["measurement"]
        memory_summary[data["memoryTrial"]].append(
            {
                "path": str(path),
                "sha256": sha256_file(path),
                "ledgerAccountedBytes": measurement["ledgerAccountedBytes"],
                "allocatedBytes": measurement["allocatedBytes"],
                "constructedEnvelopeMatchesLedger": measurement[
                    "constructedEnvelopeMatchesLedger"
                ],
                "incrementalPhysicalFootprintBytes": measurement[
                    "incrementalPhysicalFootprintBytes"
                ],
                "openFileDescriptorDeltaAfterCleanup": measurement[
                    "openFileDescriptorDeltaAfterCleanup"
                ],
                "cleanupOwnership": measurement["cleanupOwnership"],
            }
        )

    return {
        "schemaVersion": SCHEMA_VERSION,
        "taskID": TASK_ID,
        "generatedAtUTC": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "authority": {
            "authorityClass": AUTHORITY_CLASS,
            "candidateMeasurementsOnly": True,
            "productionAuthorization": False,
            "blockingTaskIDs": BLOCKING_TASK_IDS,
            "physicalEvidenceGate": PHYSICAL_EVIDENCE_GATE,
            "reason": (
                "ADR-014 selected-SSH evidence and the accepted cross-layer ADR-009 "
                "residual component ledger do not yet exist"
            ),
        },
        "fixtureRuns": len(fixture_runs),
        "warmupIterationsPerRun": fixture_runs[0][1]["measurements"]["method"][
            "warmupIterationsPerLatencyFixture"
        ],
        "measuredIterationsPerRun": fixture_runs[0][1]["measurements"]["method"][
            "measuredIterationsPerLatencyFixture"
        ],
        "latencyAcrossRuns": latency_summary,
        "wireBoundaries": representative_fixtures["maximumWireBoundaries"],
        "dualFamilyOrders": representative_fixtures["dualOrdered"],
        "transactionOwnerScenarios": scenario_summary,
        "allResolverSentinelCallsZero": all(
            data["measurements"]["physicalResolverSentinel"]["getaddrinfoCalls"] == 0
            for _, data in fixture_runs
        ),
        "allFixtureCleanupOwnershipZero": all(
            all(not value for value in scenario["cleanupOwnership"].values())
            for _, data in fixture_runs
            for scenario in data["measurements"]["fixtures"][
                "transactionOwnerSimulation"
            ].values()
        ),
        "isolatedMemoryTrials": memory_summary,
        "rawArtifacts": raw_artifacts,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--warmup", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=30)
    parser.add_argument("--self-test-only", action="store_true")
    parser.add_argument("--emit-policy", action="store_true")
    parser.add_argument("--memory-trial", choices=("default", "hard"))
    parser.add_argument("--verify-policy", type=Path)
    parser.add_argument("--summarize", nargs="+", type=Path)
    args = parser.parse_args()
    if args.warmup < 1 or args.repeats < 5:
        parser.error("warmup must be >=1 and repeats must be >=5")

    tests = self_test()
    if args.emit_policy:
        report = canonical_policy_artifact()
    elif args.summarize:
        report = summarize_measurements(args.summarize)
    elif args.verify_policy:
        report = {
            "schemaVersion": SCHEMA_VERSION,
            "selfTest": tests,
            "policyArtifactVerification": verify_policy_artifact(args.verify_policy),
        }
    elif args.self_test_only:
        report = {"schemaVersion": SCHEMA_VERSION, "selfTest": tests}
    elif args.memory_trial:
        selected = DEFAULTS if args.memory_trial == "default" else CEILINGS
        report = {
            "schemaVersion": SCHEMA_VERSION,
            "taskID": TASK_ID,
            "generatedAtUTC": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "environment": environment(),
            "memoryTrial": args.memory_trial,
            "ledger": ledger(selected),
            "measurement": memory_trial(selected),
        }
    else:
        report = {
            "schemaVersion": SCHEMA_VERSION,
            "taskID": TASK_ID,
            "generatedAtUTC": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "environment": environment(),
            "policy": {
                "defaults": DEFAULTS,
                "ceilings": CEILINGS,
                "minimums": MINIMUMS,
                "defaultLedger": ledger(DEFAULTS),
                "hardEnvelopeLedger": ledger(CEILINGS),
                "defaultTimingRequirements": timing_requirements(DEFAULTS),
                "hardEnvelopeTimingRequirements": timing_requirements(CEILINGS),
            },
            "selfTest": tests,
            "measurements": run_measurements(args.warmup, args.repeats),
            "memory": {
                "defaultEnvelope": memory_trial(DEFAULTS),
                "hardEnvelope": memory_trial(CEILINGS),
                "interpretation": (
                    "Physical-footprint deltas validate that the controlled allocation remains bounded. "
                    "The byte ledger, not allocator RSS behavior, is the admission proof."
                ),
            },
        }
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    else:
        sys.stdout.write(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
