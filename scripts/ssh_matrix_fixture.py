#!/usr/bin/env python3
"""Privacy-safe, reproducible SSH M0 fixture helpers.

The module deliberately owns no credentials. It validates the public fixture
manifest, produces and consumes deterministic traffic without retaining it,
and implements the direct-tcpip destination behaviors used by matrix runners.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import os
import re
import shlex
import socket
import struct
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Callable, Iterable, Mapping


TASK_ID = "TASK-260715-39xz9g"
REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = (
    REPOSITORY_ROOT
    / ".research"
    / "fixtures"
    / f"{TASK_ID}_ssh-matrix-fixture-manifest-v1.json"
)
DEFAULT_PROVIDER_SCRIPT = REPOSITORY_ROOT / "scripts" / "ssh_matrix_provider.py"
FIVE_GIB = 5 * 1024 * 1024 * 1024
DEFAULT_BLOCK_BYTES = 1024 * 1024
REQUIRED_SERVERS = {
    "linux-current",
    "macos-current",
    "macos-approved-older-profile",
    "relux-real",
}
REQUIRED_SCENARIOS = {
    "success",
    "host-key-first-use",
    "host-key-change",
    "auth-rejection",
    "channel-rejection",
    "early-close",
    "half-close",
    "reset",
    "server-rekey",
    "latency",
    "loss",
    "disconnect",
}
REQUIRED_ENDPOINTS = {
    "echo",
    "sink",
    "early-close",
    "half-close",
    "reset",
    "disconnect",
}
REQUIRED_NETWORK_PROFILES = {"baseline", "latency-75ms", "loss-10-percent"}
REQUIRED_CANDIDATES = ("libssh2", "reluxniossh")
PROVIDER_ENV_BY_SERVER = {
    "linux-current": "RELUX_SSH_MATRIX_LINUX_PROVIDER",
    "macos-current": "RELUX_SSH_MATRIX_MACOS_PROVIDER",
    "macos-approved-older-profile": "RELUX_SSH_MATRIX_MACOS_PROVIDER",
    "relux-real": "RELUX_SSH_MATRIX_RELUX_PROVIDER",
}
DRIVER_ENV_BY_CANDIDATE = {
    "libssh2": "RELUX_SSH_MATRIX_LIBSSH2_DRIVER",
    "reluxniossh": "RELUX_SSH_MATRIX_RELUXNIOSSH_DRIVER",
}
BUILTIN_PROVIDER_COMMANDS = {
    name: shlex.join([sys.executable, str(DEFAULT_PROVIDER_SCRIPT), "dispatch"])
    for name in set(PROVIDER_ENV_BY_SERVER.values())
}
SCENARIO_SERVER = {
    "host-key-first-use": "macos-current",
    "host-key-change": "macos-current",
    "auth-rejection": "macos-current",
    "channel-rejection": "macos-current",
    "early-close": "macos-current",
    "half-close": "macos-current",
    "reset": "macos-current",
    "server-rekey": "macos-approved-older-profile",
    "latency": "macos-current",
    "loss": "macos-current",
    "disconnect": "macos-current",
}
STDIO_FIXTURES = {
    "echo": "python3 -u scripts/ssh_matrix_fixture.py stdio-echo",
    "sink": "python3 -u scripts/ssh_matrix_fixture.py stdio-sink",
}
PUBLIC_OBSERVATION_KEYS = {
    "architecture",
    "hostKeyFingerprints",
    "opensshVersion",
    "osName",
    "osVersion",
    "privilege",
    "reachable",
    "userKeyTypes",
}
PUBLIC_OBSERVATION_CODES = {
    "success": "success:byte-exact",
    "host-key-first-use": "host-key-first-use:credentials-withheld",
    "host-key-change": "host-key-change:changed-key-rejected",
    "auth-rejection": "auth-rejection:publickey-rejected",
    "channel-rejection": "channel-rejection:direct-tcpip-rejected",
    "early-close": "early-close:eof-before-payload",
    "half-close": "half-close:independent-directions",
    "reset": "reset:connection-reset",
    "server-rekey": "server-rekey:byte-exact",
    "latency": "latency:75ms-path-observed",
    "loss": "loss:every-tenth-connection",
    "disconnect": "disconnect:connection-lost",
}
SCENARIO_FIXTURE_EVIDENCE = {
    "host-key-first-use": "host-key-first-use:empty-trust-store",
    "host-key-change": "host-key-change:alternate-host-key",
    "auth-rejection": "auth-rejection:unapproved-user-key",
    "channel-rejection": "channel-rejection:closed-loopback-destination",
    "early-close": "early-close:listener-ready",
    "half-close": "half-close:listener-ready",
    "reset": "reset:listener-ready",
    "server-rekey": "server-rekey:32k-limit",
    "latency": "latency:75ms-proxy",
    "loss": "loss:drop-every-10",
    "disconnect": "disconnect:listener-ready",
}
ENVIRONMENT_NAME = re.compile(r"^[A-Z][A-Z0-9_]*$")
OPENSSH_SHA256_FINGERPRINT = re.compile(r"^SHA256:([A-Za-z0-9+/]{43})$")
SHA256_HEX_DIGEST = re.compile(r"^SHA256:[0-9a-f]{64}$")
SECRET_MARKERS = (
    "BEGIN PRIVATE KEY",
    "BEGIN OPENSSH PRIVATE KEY",
    "password=",
    "identityfile ",
)


class FixtureError(RuntimeError):
    """A fail-closed fixture contract violation."""


ExternalInvoker = Callable[[str, Mapping[str, object]], dict]


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict:
    try:
        encoded = path.read_bytes()
        manifest = json.loads(encoded)
    except (OSError, json.JSONDecodeError) as error:
        raise FixtureError(f"unable to load fixture manifest: {error}") from error
    if not isinstance(manifest, dict):
        raise FixtureError("fixture manifest must be a JSON object")
    if encoded != canonical_json(manifest):
        raise FixtureError("fixture manifest must use canonical sorted JSON")
    return manifest


def _require_exact_ids(items: object, required: set[str], label: str) -> dict[str, dict]:
    if not isinstance(items, list) or not all(isinstance(item, dict) for item in items):
        raise FixtureError(f"{label} must be an array of objects")
    indexed = {item.get("id"): item for item in items}
    if None in indexed or len(indexed) != len(items):
        raise FixtureError(f"{label} IDs must be present and unique")
    if set(indexed) != required:
        raise FixtureError(
            f"{label} matrix mismatch: expected {sorted(required)}, got {sorted(indexed)}"
        )
    return indexed


def _validate_fingerprint(value: object, context: str) -> None:
    match = OPENSSH_SHA256_FINGERPRINT.fullmatch(value) if isinstance(value, str) else None
    if match is None:
        raise FixtureError(f"{context} must contain an SHA256 host-key fingerprint")
    payload = match.group(1)
    try:
        digest = base64.b64decode(payload + "=", validate=True)
    except (binascii.Error, ValueError) as error:
        raise FixtureError(
            f"{context} must contain an SHA256 host-key fingerprint"
        ) from error
    canonical = base64.b64encode(digest).decode("ascii").rstrip("=")
    if len(digest) != hashlib.sha256().digest_size or canonical != payload:
        raise FixtureError(f"{context} must contain an SHA256 host-key fingerprint")


def _validate_sha256_digest(value: object, context: str) -> None:
    if not isinstance(value, str) or SHA256_HEX_DIGEST.fullmatch(value) is None:
        raise FixtureError(f"{context} must contain a canonical SHA256 content digest")


def validate_manifest(manifest: dict) -> None:
    if manifest.get("schemaVersion") != 1 or manifest.get("taskId") != TASK_ID:
        raise FixtureError("fixture manifest schema or task ID mismatch")
    if manifest.get("payloadRetention") != "none":
        raise FixtureError("fixture payload retention must be none")
    if set(PROVIDER_ENV_BY_SERVER) != REQUIRED_SERVERS:
        raise FixtureError("provider registry does not cover the server matrix")
    if set(DRIVER_ENV_BY_CANDIDATE) != set(REQUIRED_CANDIDATES):
        raise FixtureError("candidate driver registry is incomplete")
    if set(SCENARIO_SERVER) != REQUIRED_SCENARIOS - {"success"}:
        raise FixtureError("scenario execution registry is incomplete")

    serialized = canonical_json(manifest).decode().lower()
    for marker in SECRET_MARKERS:
        if marker.lower() in serialized:
            raise FixtureError(f"fixture manifest contains forbidden secret marker {marker!r}")

    servers = _require_exact_ids(manifest.get("servers"), REQUIRED_SERVERS, "servers")
    for server_id, server in servers.items():
        identity = server.get("identity")
        if not isinstance(identity, dict) or identity.get("privilege") != "non-root":
            raise FixtureError(f"{server_id} must use a non-root identity")
        secret_reference = identity.get("secretReference")
        if not isinstance(secret_reference, str) or not secret_reference.startswith(
            ("ssh-config://", "lima-store://", "ephemeral-memory://")
        ):
            raise FixtureError(f"{server_id} must use an approved external secret reference")
        if server.get("reachability") != "verified":
            raise FixtureError(f"{server_id} reachability is not verified")
        if not isinstance(server.get("opensshVersion"), str):
            raise FixtureError(f"{server_id} OpenSSH version is missing")
        host_keys = server.get("hostKeys")
        if not isinstance(host_keys, list) or not host_keys:
            raise FixtureError(f"{server_id} host keys are missing")
        for key in host_keys:
            _validate_fingerprint(key.get("fingerprintSHA256"), server_id)
        if not server.get("userKeyTypes"):
            raise FixtureError(f"{server_id} user-key types are missing")

    algorithms = manifest.get("algorithmProfiles")
    if not isinstance(algorithms, dict):
        raise FixtureError("algorithmProfiles must be an object")
    if algorithms.get("primary") != {
        "cipher": "aes256-ctr",
        "hostKey": "ssh-ed25519",
        "keyExchange": "curve25519-sha256",
        "mac": "hmac-sha2-256",
        "userKey": "ssh-ed25519",
    }:
        raise FixtureError("primary approved algorithm profile drift")
    if algorithms.get("fallback") != {
        "cipher": "aes128-ctr",
        "hostKey": "ecdsa-sha2-nistp256",
        "keyExchange": "diffie-hellman-group14-sha256",
        "mac": "hmac-sha2-512",
        "userKey": "ecdsa-sha2-nistp256",
    }:
        raise FixtureError("fallback approved algorithm profile drift")

    _require_exact_ids(manifest.get("endpoints"), REQUIRED_ENDPOINTS, "endpoints")
    scenarios = _require_exact_ids(
        manifest.get("scenarios"), REQUIRED_SCENARIOS, "scenarios"
    )
    for scenario_id, scenario in scenarios.items():
        if not scenario.get("reproduction") or not scenario.get("expected"):
            raise FixtureError(f"{scenario_id} lacks reproduction or expected behavior")

    network = _require_exact_ids(
        manifest.get("networkProfiles"), REQUIRED_NETWORK_PROFILES, "networkProfiles"
    )
    if network["latency-75ms"].get("latencyMilliseconds") != 75:
        raise FixtureError("latency profile drift")
    if network["loss-10-percent"].get("deterministicDropEvery") != 10:
        raise FixtureError("loss profile drift")

    traffic = manifest.get("traffic")
    if not isinstance(traffic, dict):
        raise FixtureError("traffic configuration is missing")
    if traffic.get("bytes") < FIVE_GIB or traffic.get("retainPayload") is not False:
        raise FixtureError("traffic must stream at least 5 GiB without retaining payload")
    if traffic.get("blockBytes") != DEFAULT_BLOCK_BYTES:
        raise FixtureError("traffic block size drift")
    _validate_sha256_digest(traffic.get("expectedSHA256"), "traffic")

    teardown = manifest.get("teardown")
    if not isinstance(teardown, dict) or teardown.get("persistentRootService") is not False:
        raise FixtureError("teardown must prohibit persistent root services")
    if not teardown.get("steps") or not teardown.get("evidence"):
        raise FixtureError("teardown steps and evidence are required")


def deterministic_block(seed: str, block_bytes: int = DEFAULT_BLOCK_BYTES) -> bytes:
    if not seed or block_bytes <= 0:
        raise FixtureError("traffic seed and block size must be non-empty and positive")
    seed_bytes = seed.encode("utf-8")
    result = bytearray()
    counter = 0
    while len(result) < block_bytes:
        result.extend(hashlib.sha256(seed_bytes + struct.pack(">Q", counter)).digest())
        counter += 1
    return bytes(result[:block_bytes])


def expected_stream_hash(
    total_bytes: int, seed: str, block_bytes: int = DEFAULT_BLOCK_BYTES
) -> str:
    if total_bytes < 0:
        raise FixtureError("traffic byte count cannot be negative")
    block = deterministic_block(seed, block_bytes)
    digest = hashlib.sha256()
    remaining = total_bytes
    while remaining:
        chunk = block[: min(remaining, len(block))]
        digest.update(chunk)
        remaining -= len(chunk)
    return f"SHA256:{digest.hexdigest()}"


def stream_source(
    output: BinaryIO, total_bytes: int, seed: str, block_bytes: int = DEFAULT_BLOCK_BYTES
) -> tuple[int, str]:
    block = deterministic_block(seed, block_bytes)
    digest = hashlib.sha256()
    written = 0
    while written < total_bytes:
        chunk = block[: min(total_bytes - written, len(block))]
        output.write(chunk)
        digest.update(chunk)
        written += len(chunk)
    return written, f"SHA256:{digest.hexdigest()}"


def stream_sink(
    source: BinaryIO, expected_bytes: int, expected_hash: str, read_bytes: int = 1024 * 1024
) -> tuple[int, str]:
    if expected_bytes < 0 or read_bytes <= 0:
        raise FixtureError("sink counts must be non-negative and reads must be positive")
    digest = hashlib.sha256()
    received = 0
    while True:
        chunk = source.read(read_bytes)
        if not chunk:
            break
        received += len(chunk)
        if received > expected_bytes:
            raise FixtureError("sink received more bytes than expected")
        digest.update(chunk)
    observed = f"SHA256:{digest.hexdigest()}"
    if received != expected_bytes or observed != expected_hash:
        raise FixtureError(
            f"sink mismatch: bytes={received}/{expected_bytes}, hash={observed}/{expected_hash}"
        )
    return received, observed


@dataclass(frozen=True)
class EndpointResult:
    received_bytes: int
    sha256: str


def serve_endpoint(connection: socket.socket, mode: str) -> EndpointResult:
    if mode not in REQUIRED_ENDPOINTS:
        raise FixtureError(f"unsupported endpoint mode {mode!r}")
    digest = hashlib.sha256()
    received = 0
    if mode == "early-close":
        connection.shutdown(socket.SHUT_WR)
        while connection.recv(64 * 1024):
            pass
        return EndpointResult(0, f"SHA256:{digest.hexdigest()}")
    if mode == "reset":
        connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        return EndpointResult(0, f"SHA256:{digest.hexdigest()}")

    while True:
        chunk = connection.recv(64 * 1024)
        if not chunk:
            break
        received += len(chunk)
        digest.update(chunk)
        if mode == "disconnect":
            break
        if mode in {"echo", "half-close"}:
            connection.sendall(chunk)
        if mode == "half-close":
            connection.shutdown(socket.SHUT_WR)
            mode = "sink"
    return EndpointResult(received, f"SHA256:{digest.hexdigest()}")


def deterministic_drop_indexes(total_connections: int, every: int) -> Iterable[int]:
    if total_connections < 0 or every <= 0:
        raise FixtureError("loss-control counts must be non-negative and positive")
    return (index for index in range(1, total_connections + 1) if index % every == 0)


def apply_latency(milliseconds: int, sleeper=time.sleep) -> None:
    if milliseconds < 0:
        raise FixtureError("latency cannot be negative")
    sleeper(milliseconds / 1000)


class EndpointListener:
    """Task-owned numeric-loopback listener for one destination behavior."""

    def __init__(self, mode: str):
        if mode not in REQUIRED_ENDPOINTS:
            raise FixtureError(f"unsupported endpoint mode {mode!r}")
        self.mode = mode
        self.results: list[EndpointResult] = []
        self._lock = threading.Lock()
        self._connections: set[socket.socket] = set()
        self._listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._listener.bind(("127.0.0.1", 0))
        self._listener.listen()
        self._listener.settimeout(0.1)
        self.host, self.port = self._listener.getsockname()
        self._stopped = threading.Event()
        self._thread = threading.Thread(target=self._accept, daemon=True)
        self._thread.start()

    def _accept(self) -> None:
        while not self._stopped.is_set():
            try:
                connection, _ = self._listener.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            with self._lock:
                self._connections.add(connection)
            threading.Thread(
                target=self._serve,
                args=(connection,),
                daemon=True,
            ).start()

    def _serve(self, connection: socket.socket) -> None:
        try:
            result = serve_endpoint(connection, self.mode)
            with self._lock:
                self.results.append(result)
        except OSError:
            pass
        finally:
            with self._lock:
                self._connections.discard(connection)
            connection.close()

    def stop(self) -> None:
        self._stopped.set()
        self._listener.close()
        with self._lock:
            connections = list(self._connections)
        for connection in connections:
            try:
                connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            connection.close()
        self._thread.join(timeout=2)

    def public_address(self) -> dict[str, object]:
        return {"host": self.host, "port": self.port}


class EndpointFixtureSet:
    """Owns the complete direct-tcpip destination set and its teardown."""

    def __init__(self):
        self.listeners = {mode: EndpointListener(mode) for mode in sorted(REQUIRED_ENDPOINTS)}

    def public_addresses(self) -> dict[str, dict[str, object]]:
        return {mode: listener.public_address() for mode, listener in self.listeners.items()}

    def stop(self) -> None:
        for listener in self.listeners.values():
            listener.stop()


class TCPImpairmentProxy:
    """Applies latency or deterministic connection loss to an SSH TCP path."""

    def __init__(
        self,
        upstream_host: str,
        upstream_port: int,
        *,
        latency_milliseconds: int = 0,
        deterministic_drop_every: int = 0,
    ):
        if latency_milliseconds < 0 or deterministic_drop_every < 0:
            raise FixtureError("network impairment values cannot be negative")
        self.upstream = (upstream_host, upstream_port)
        self.latency_milliseconds = latency_milliseconds
        self.deterministic_drop_every = deterministic_drop_every
        self.connection_count = 0
        self.dropped_connections: list[int] = []
        self._connections: set[socket.socket] = set()
        self._lock = threading.Lock()
        self._stopped = threading.Event()
        self._listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._listener.bind(("127.0.0.1", 0))
        self._listener.listen()
        self._listener.settimeout(0.1)
        self.host, self.port = self._listener.getsockname()
        self._thread = threading.Thread(target=self._accept, daemon=True)
        self._thread.start()

    def _accept(self) -> None:
        while not self._stopped.is_set():
            try:
                downstream, _ = self._listener.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            with self._lock:
                self.connection_count += 1
                ordinal = self.connection_count
            if self.deterministic_drop_every and ordinal % self.deterministic_drop_every == 0:
                downstream.setsockopt(
                    socket.SOL_SOCKET,
                    socket.SO_LINGER,
                    struct.pack("ii", 1, 0),
                )
                downstream.close()
                with self._lock:
                    self.dropped_connections.append(ordinal)
                continue
            try:
                upstream = socket.create_connection(self.upstream, timeout=2)
            except OSError:
                downstream.close()
                continue
            with self._lock:
                self._connections.update((downstream, upstream))
            threading.Thread(
                target=self._bridge,
                args=(downstream, upstream),
                daemon=True,
            ).start()

    def _bridge(self, downstream: socket.socket, upstream: socket.socket) -> None:
        pumps = [
            threading.Thread(target=self._pump, args=(downstream, upstream), daemon=True),
            threading.Thread(target=self._pump, args=(upstream, downstream), daemon=True),
        ]
        for pump in pumps:
            pump.start()
        for pump in pumps:
            pump.join()
        for connection in (downstream, upstream):
            with self._lock:
                self._connections.discard(connection)
            connection.close()

    def _pump(self, source: socket.socket, destination: socket.socket) -> None:
        try:
            while True:
                chunk = source.recv(64 * 1024)
                if not chunk:
                    try:
                        destination.shutdown(socket.SHUT_WR)
                    except OSError:
                        pass
                    return
                apply_latency(self.latency_milliseconds)
                destination.sendall(chunk)
        except OSError:
            return

    def stop(self) -> None:
        self._stopped.set()
        self._listener.close()
        with self._lock:
            connections = list(self._connections)
        for connection in connections:
            try:
                connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            connection.close()
        self._thread.join(timeout=2)

    def public_address(self) -> dict[str, object]:
        return {"host": self.host, "port": self.port}


def consume_stream(source: BinaryIO, read_bytes: int = 64 * 1024) -> EndpointResult:
    if read_bytes <= 0:
        raise FixtureError("stream read size must be positive")
    digest = hashlib.sha256()
    received = 0
    while True:
        chunk = source.read(read_bytes)
        if not chunk:
            return EndpointResult(received, f"SHA256:{digest.hexdigest()}")
        received += len(chunk)
        digest.update(chunk)


def echo_stream(source: BinaryIO, output: BinaryIO, read_bytes: int = 64 * 1024) -> EndpointResult:
    if read_bytes <= 0:
        raise FixtureError("stream read size must be positive")
    digest = hashlib.sha256()
    received = 0
    while True:
        chunk = source.read(read_bytes)
        if not chunk:
            return EndpointResult(received, f"SHA256:{digest.hexdigest()}")
        received += len(chunk)
        digest.update(chunk)
        output.write(chunk)
        if hasattr(output, "flush"):
            output.flush()


def command_environment_name(reference: str) -> str:
    prefix = "command-env://"
    if not reference.startswith(prefix):
        raise FixtureError("external command reference must use command-env://")
    name = reference[len(prefix) :]
    if not ENVIRONMENT_NAME.fullmatch(name):
        raise FixtureError("external command reference has an invalid environment name")
    return name


class EnvironmentCommandInvoker:
    """Runs provider/driver commands named by environment, never recording secrets."""

    def __init__(self, environment: Mapping[str, str] | None = None):
        self.environment = dict(os.environ if environment is None else environment)

    def __call__(self, reference: str, request: Mapping[str, object]) -> dict:
        name = command_environment_name(reference)
        command = self.environment.get(name) or BUILTIN_PROVIDER_COMMANDS.get(name)
        if not command:
            raise FixtureError(f"external command reference {name} is unavailable")
        arguments = shlex.split(command)
        if not arguments:
            raise FixtureError(f"external command reference {name} is empty")
        try:
            completed = subprocess.run(
                arguments,
                input=canonical_json(dict(request)),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
                check=False,
                env=self.environment,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise FixtureError(f"external command reference {name} failed safely") from error
        if completed.returncode != 0:
            raise FixtureError(
                f"external command reference {name} exited {completed.returncode}; output redacted"
            )
        try:
            response = json.loads(completed.stdout)
        except json.JSONDecodeError as error:
            raise FixtureError(f"external command reference {name} returned invalid JSON") from error
        if not isinstance(response, dict):
            raise FixtureError(f"external command reference {name} must return an object")
        return response


def _provider_reference(server_id: str) -> str:
    try:
        return f"command-env://{PROVIDER_ENV_BY_SERVER[server_id]}"
    except KeyError as error:
        raise FixtureError(f"no provider command is registered for {server_id}") from error


def _driver_reference(candidate_id: str) -> str:
    try:
        return f"command-env://{DRIVER_ENV_BY_CANDIDATE[candidate_id]}"
    except KeyError as error:
        raise FixtureError(f"no candidate driver is registered for {candidate_id}") from error


def _validate_public_observation(server: dict, response: dict) -> dict:
    if response.get("status") != "ok":
        raise FixtureError(f"{server['id']} provider did not report success")
    observation = response.get("observation")
    if not isinstance(observation, dict) or set(observation) != PUBLIC_OBSERVATION_KEYS:
        raise FixtureError(f"{server['id']} provider returned an invalid public observation")
    if observation.get("reachable") is not True or observation.get("privilege") != "non-root":
        raise FixtureError(f"{server['id']} provider did not prove least-privilege reachability")
    fingerprints = observation.get("hostKeyFingerprints")
    if not isinstance(fingerprints, list) or not fingerprints:
        raise FixtureError(f"{server['id']} provider did not observe host keys")
    for fingerprint in fingerprints:
        _validate_fingerprint(fingerprint, server["id"])
    if not isinstance(observation.get("userKeyTypes"), list) or not observation["userKeyTypes"]:
        raise FixtureError(f"{server['id']} provider did not report user-key types")
    pinned_fingerprints = {
        key["fingerprintSHA256"]
        for key in server["hostKeys"]
        if key.get("fingerprintMode") != "per-run-observed"
    }
    expected_os = server["os"]
    if (
        observation["opensshVersion"] != server["opensshVersion"]
        or observation["osName"] != expected_os["name"]
        or observation["osVersion"] != expected_os["version"]
        or observation["architecture"] != expected_os["architecture"]
        or (pinned_fingerprints and set(fingerprints) != pinned_fingerprints)
        or set(observation["userKeyTypes"]) != set(server["userKeyTypes"])
    ):
        raise FixtureError(f"{server['id']} observed public facts drifted from the manifest")
    return observation


def _validate_runtime(server_id: str, response: dict) -> dict:
    runtime = response.get("runtime")
    if not isinstance(runtime, dict):
        raise FixtureError(f"{server_id} provider omitted its in-memory runtime descriptor")
    if not isinstance(runtime.get("host"), str) or not runtime["host"]:
        raise FixtureError(f"{server_id} runtime host is missing")
    port = runtime.get("port")
    if not isinstance(port, int) or not 0 < port <= 65535:
        raise FixtureError(f"{server_id} runtime port is invalid")
    if not isinstance(runtime.get("identityReference"), str):
        raise FixtureError(f"{server_id} runtime identity reference is missing")
    endpoints = runtime.get("destinationEndpoints")
    if not isinstance(endpoints, dict) or set(endpoints) != REQUIRED_ENDPOINTS:
        raise FixtureError(f"{server_id} runtime destination endpoints are incomplete")
    for endpoint_id, address in endpoints.items():
        if not isinstance(address, dict):
            raise FixtureError(f"{server_id}/{endpoint_id} endpoint address is invalid")
        try:
            socket.inet_pton(socket.AF_INET, address.get("host"))
        except (OSError, TypeError):
            raise FixtureError(
                f"{server_id}/{endpoint_id} endpoint must use numeric IPv4"
            ) from None
        endpoint_port = address.get("port")
        if not isinstance(endpoint_port, int) or not 0 < endpoint_port <= 65535:
            raise FixtureError(f"{server_id}/{endpoint_id} endpoint port is invalid")
    return runtime


def _network_profile(manifest: dict, profile_id: str) -> dict:
    for profile in manifest["networkProfiles"]:
        if profile["id"] == profile_id:
            return profile
    raise FixtureError(f"network profile {profile_id} is missing")


def _run_candidate_case(
    invoke: ExternalInvoker,
    manifest: dict,
    candidate_id: str,
    scenario_id: str,
    server_id: str,
    runtime: dict,
    fixture_evidence_code: str | None = None,
) -> dict:
    profile_id = {
        "latency": "latency-75ms",
        "loss": "loss-10-percent",
    }.get(scenario_id, "baseline")
    profile = _network_profile(manifest, profile_id)
    proxy = None
    ssh_endpoint = {"host": runtime["host"], "port": runtime["port"]}
    if profile["latencyMilliseconds"] or profile["deterministicDropEvery"]:
        proxy = TCPImpairmentProxy(
            runtime["host"],
            runtime["port"],
            latency_milliseconds=profile["latencyMilliseconds"],
            deterministic_drop_every=profile["deterministicDropEvery"],
        )
        ssh_endpoint = proxy.public_address()
    try:
        response = invoke(
            _driver_reference(candidate_id),
            {
                "protocol": "relux-ssh-matrix-driver-v1",
                "candidateId": candidate_id,
                "scenarioId": scenario_id,
                "serverId": server_id,
                "serverRuntime": runtime,
                "sshEndpoint": ssh_endpoint,
                "destinationEndpoints": runtime["destinationEndpoints"],
                "stdioExec": runtime.get("stdioExec", STDIO_FIXTURES),
                "networkProfile": profile,
                "fixtureEvidenceCode": fixture_evidence_code,
            },
        )
        if proxy is not None:
            if scenario_id == "latency" and proxy.connection_count < 1:
                raise FixtureError("latency scenario did not exercise its SSH impairment proxy")
            if scenario_id == "loss" and (
                proxy.connection_count < 10 or proxy.dropped_connections != [10]
            ):
                raise FixtureError("loss scenario did not exercise deterministic connection loss")
    finally:
        if proxy is not None:
            proxy.stop()
    if response.get("status") != "pass" or response.get("scenarioId") != scenario_id:
        raise FixtureError(
            f"{candidate_id}/{server_id}/{scenario_id} did not return an observed pass"
        )
    code = response.get("observationCode")
    if code != PUBLIC_OBSERVATION_CODES[scenario_id]:
        raise FixtureError(
            f"{candidate_id}/{server_id}/{scenario_id} returned an invalid observation code"
        )
    return {
        "candidateId": candidate_id,
        "observationCode": code,
        "scenarioId": scenario_id,
        "serverId": server_id,
        "status": "pass",
    }


def _prepare_scenario_control(
    invoke: ExternalInvoker,
    scenario_id: str,
    server_id: str,
    runtime: dict,
) -> tuple[dict, str]:
    response = invoke(
        _provider_reference(server_id),
        {
            "protocol": "relux-ssh-matrix-provider-v1",
            "action": "control",
            "scenarioId": scenario_id,
            "serverId": server_id,
            "runtime": runtime,
        },
    )
    expected_evidence = SCENARIO_FIXTURE_EVIDENCE[scenario_id]
    if (
        response.get("status") != "ok"
        or response.get("scenarioId") != scenario_id
        or response.get("fixtureEvidenceCode") != expected_evidence
    ):
        raise FixtureError(f"{server_id}/{scenario_id} provider control was not observed")
    controlled_runtime = runtime
    if isinstance(response.get("runtime"), dict):
        controlled_runtime = _validate_runtime(server_id, response)
    return controlled_runtime, expected_evidence


def run_orchestration(manifest: dict, invoke: ExternalInvoker) -> dict:
    """Run the public matrix contract while keeping runtime credentials in memory."""

    validate_manifest(manifest)
    servers = {server["id"]: server for server in manifest["servers"]}
    prepared: list[tuple[dict, str]] = []
    runtimes: dict[str, dict] = {}
    server_observations = []
    lifecycle_observations = []
    matrix_observations = []
    failure: Exception | None = None
    try:
        for server_id in sorted(REQUIRED_SERVERS):
            server = servers[server_id]
            reference = _provider_reference(server_id)
            prepared.append((server, reference))
            prepare = invoke(
                reference,
                {
                    "protocol": "relux-ssh-matrix-provider-v1",
                    "action": "prepare",
                    "serverId": server_id,
                    "secretReference": server["identity"]["secretReference"],
                },
            )
            runtime = _validate_runtime(server_id, prepare)
            runtimes[server_id] = runtime
            rotation = invoke(
                reference,
                {
                    "protocol": "relux-ssh-matrix-provider-v1",
                    "action": "rotate",
                    "serverId": server_id,
                    "runtime": runtime,
                },
            )
            disposition = rotation.get("disposition")
            expected_disposition = (
                "external-owner-managed" if server_id == "relux-real" else "rotated"
            )
            if (
                rotation.get("status") != "ok"
                or disposition != expected_disposition
            ):
                raise FixtureError(f"{server_id} provider did not prove rotation disposition")
            if isinstance(rotation.get("runtime"), dict):
                runtime = _validate_runtime(server_id, rotation)
                runtimes[server_id] = runtime
            probe = invoke(
                reference,
                {
                    "protocol": "relux-ssh-matrix-provider-v1",
                    "action": "probe",
                    "serverId": server_id,
                    "runtime": runtime,
                },
            )
            observation = _validate_public_observation(server, probe)
            server_observations.append({"serverId": server_id, **observation})
            lifecycle_observations.append(
                {
                    "prepare": "observed",
                    "probe": "observed",
                    "rotation": disposition,
                    "serverId": server_id,
                }
            )

        for candidate_id in REQUIRED_CANDIDATES:
            for server_id in sorted(REQUIRED_SERVERS):
                matrix_observations.append(
                    _run_candidate_case(
                        invoke,
                        manifest,
                        candidate_id,
                        "success",
                        server_id,
                        runtimes[server_id],
                    )
                )
            for scenario_id in sorted(REQUIRED_SCENARIOS - {"success"}):
                server_id = SCENARIO_SERVER[scenario_id]
                controlled_runtime, fixture_evidence = _prepare_scenario_control(
                    invoke,
                    scenario_id,
                    server_id,
                    runtimes[server_id],
                )
                matrix_observations.append(
                    _run_candidate_case(
                        invoke,
                        manifest,
                        candidate_id,
                        scenario_id,
                        server_id,
                        controlled_runtime,
                        fixture_evidence,
                    )
                )
    except Exception as error:
        failure = error
    teardown_failures = []
    for server, reference in reversed(prepared):
        try:
            response = invoke(
                reference,
                {
                    "protocol": "relux-ssh-matrix-provider-v1",
                    "action": "teardown",
                    "serverId": server["id"],
                    "runtime": runtimes.get(server["id"]),
                },
            )
            if response.get("status") != "ok" or response.get("residualResources") != 0:
                raise FixtureError(f"{server['id']} provider teardown left residual resources")
            for lifecycle in lifecycle_observations:
                if lifecycle["serverId"] == server["id"]:
                    lifecycle["teardown"] = "observed-zero-residual"
        except Exception as error:
            teardown_failures.append(error)
    if teardown_failures:
        raise FixtureError(f"{len(teardown_failures)} provider teardown action(s) failed")
    if failure is not None:
        raise failure

    report = {
        "candidates": list(REQUIRED_CANDIDATES),
        "lifecycleObservations": lifecycle_observations,
        "matrixObservations": matrix_observations,
        "payloadRetention": "none",
        "schemaVersion": 1,
        "serverObservations": server_observations,
        "taskId": TASK_ID,
    }
    serialized = canonical_json(report).decode().lower()
    for marker in SECRET_MARKERS:
        if marker.lower() in serialized:
            raise FixtureError("orchestration report contains a forbidden secret marker")
    expected_cases = len(REQUIRED_CANDIDATES) * (
        len(REQUIRED_SERVERS) + len(REQUIRED_SCENARIOS) - 1
    )
    if len(matrix_observations) != expected_cases:
        raise FixtureError("orchestration report has incomplete candidate coverage")
    return report


def _command_verify(arguments: argparse.Namespace) -> int:
    validate_manifest(load_manifest(arguments.manifest))
    print(f"fixture manifest OK: {arguments.manifest}")
    return 0


def _command_hash(arguments: argparse.Namespace) -> int:
    print(expected_stream_hash(arguments.bytes, arguments.seed, arguments.block_bytes))
    return 0


def _command_source(arguments: argparse.Namespace) -> int:
    stream_source(sys.stdout.buffer, arguments.bytes, arguments.seed, arguments.block_bytes)
    return 0


def _command_sink(arguments: argparse.Namespace) -> int:
    count, digest = stream_sink(
        sys.stdin.buffer, arguments.expected_bytes, arguments.expected_sha256
    )
    print(json.dumps({"bytes": count, "sha256": digest}, sort_keys=True), file=sys.stderr)
    return 0


def _command_stdio_echo(arguments: argparse.Namespace) -> int:
    result = echo_stream(sys.stdin.buffer, sys.stdout.buffer, arguments.read_bytes)
    print(json.dumps(result.__dict__, sort_keys=True), file=sys.stderr)
    return 0


def _command_stdio_sink(arguments: argparse.Namespace) -> int:
    result = consume_stream(sys.stdin.buffer, arguments.read_bytes)
    print(json.dumps(result.__dict__, sort_keys=True), file=sys.stderr)
    return 0


def _command_serve_endpoint(arguments: argparse.Namespace) -> int:
    listener = EndpointListener(arguments.mode)
    print(
        json.dumps(
            {"host": listener.host, "mode": arguments.mode, "port": listener.port},
            sort_keys=True,
        ),
        flush=True,
    )
    try:
        while True:
            time.sleep(60)
    finally:
        listener.stop()


def _command_preflight(arguments: argparse.Namespace) -> int:
    validate_manifest(load_manifest(arguments.manifest))
    requirements = {
        "candidateDrivers": DRIVER_ENV_BY_CANDIDATE,
        "builtInProviderCommands": sorted(BUILTIN_PROVIDER_COMMANDS),
        "providerCommands": PROVIDER_ENV_BY_SERVER,
        "protocols": [
            "relux-ssh-matrix-driver-v1",
            "relux-ssh-matrix-provider-v1",
        ],
        "secretValuesRecorded": False,
        "taskId": TASK_ID,
    }
    print(canonical_json(requirements).decode(), end="")
    return 0


def _command_orchestrate(arguments: argparse.Namespace) -> int:
    manifest = load_manifest(arguments.manifest)
    report = run_orchestration(manifest, EnvironmentCommandInvoker())
    encoded = canonical_json(report)
    if arguments.output is None:
        sys.stdout.buffer.write(encoded)
    else:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_bytes(encoded)
        print(f"privacy-safe orchestration report: {arguments.output}")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    verify = commands.add_parser("verify-manifest")
    verify.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    verify.set_defaults(action=_command_verify)

    traffic_hash = commands.add_parser("traffic-hash")
    traffic_hash.add_argument("--bytes", type=int, default=FIVE_GIB)
    traffic_hash.add_argument("--seed", default=TASK_ID)
    traffic_hash.add_argument("--block-bytes", type=int, default=DEFAULT_BLOCK_BYTES)
    traffic_hash.set_defaults(action=_command_hash)

    source = commands.add_parser("traffic-source")
    source.add_argument("--bytes", type=int, default=FIVE_GIB)
    source.add_argument("--seed", default=TASK_ID)
    source.add_argument("--block-bytes", type=int, default=DEFAULT_BLOCK_BYTES)
    source.set_defaults(action=_command_source)

    sink = commands.add_parser("traffic-sink")
    sink.add_argument("--expected-bytes", type=int, required=True)
    sink.add_argument("--expected-sha256", required=True)
    sink.set_defaults(action=_command_sink)

    stdio_echo = commands.add_parser("stdio-echo")
    stdio_echo.add_argument("--read-bytes", type=int, default=64 * 1024)
    stdio_echo.set_defaults(action=_command_stdio_echo)

    stdio_sink = commands.add_parser("stdio-sink")
    stdio_sink.add_argument("--read-bytes", type=int, default=64 * 1024)
    stdio_sink.set_defaults(action=_command_stdio_sink)

    endpoint = commands.add_parser("serve-endpoint")
    endpoint.add_argument("--mode", choices=sorted(REQUIRED_ENDPOINTS), required=True)
    endpoint.set_defaults(action=_command_serve_endpoint)

    preflight = commands.add_parser("orchestration-preflight")
    preflight.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    preflight.set_defaults(action=_command_preflight)

    orchestrate = commands.add_parser("orchestrate")
    orchestrate.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    orchestrate.add_argument("--output", type=Path)
    orchestrate.set_defaults(action=_command_orchestrate)
    return root


def main(argv: list[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    try:
        return arguments.action(arguments)
    except (FixtureError, BrokenPipeError) as error:
        print(f"ssh-matrix-fixture: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
