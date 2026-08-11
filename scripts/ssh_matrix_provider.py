#!/usr/bin/env python3
"""Built-in, privacy-safe OpenSSH fixture providers for the M0 matrix.

The provider stores transient routing data and generated private keys only in a
task-scoped, gitignored state directory. Public lifecycle reports contain no
host, address, account, key path, or private material.
"""

from __future__ import annotations

import argparse
import base64
import getpass
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Mapping


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
if str(REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(REPOSITORY_ROOT))

from scripts import ssh_matrix_fixture as fixture  # noqa: E402


DEFAULT_STATE_ROOT = (
    REPOSITORY_ROOT / ".temp" / fixture.TASK_ID / "provider-state"
)
LIMA_INSTANCE = "relux-m0-260715-39xz9g"
RELUX_ALIAS = "relux"
STATE_ROOT_ENV = "RELUX_SSH_MATRIX_STATE_ROOT"

REMOTE_STDIO = {
    "echo": (
        "python3 -u -c 'import shutil,sys; "
        "shutil.copyfileobj(sys.stdin.buffer,sys.stdout.buffer,length=65536)'"
    ),
    "sink": (
        "python3 -u -c 'import sys; "
        "while sys.stdin.buffer.read(65536): pass'"
    ),
}

ENDPOINT_WORKER = r'''
import hashlib,json,signal,socket,struct,threading,time
TASK_ID = "TASK-260715-39xz9g"
MODES = ("echo","sink","early-close","half-close","reset","disconnect")
stopping = threading.Event()
listeners = {}

def handle(connection, mode):
    with connection:
        if mode == "early-close":
            return
        if mode == "reset":
            connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
            return
        if mode == "disconnect":
            connection.recv(65536)
            return
        if mode == "half-close":
            data = connection.recv(65536)
            if data:
                connection.sendall(data)
            connection.shutdown(socket.SHUT_WR)
            while connection.recv(65536):
                pass
            return
        while True:
            data = connection.recv(65536)
            if not data:
                return
            if mode == "echo":
                connection.sendall(data)

def serve(listener, mode):
    while not stopping.is_set():
        try:
            connection, _ = listener.accept()
        except OSError:
            return
        threading.Thread(target=handle, args=(connection, mode), daemon=True).start()

for mode in MODES:
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(32)
    listeners[mode] = listener
    threading.Thread(target=serve, args=(listener, mode), daemon=True).start()

print(json.dumps({mode:{"host":"127.0.0.1","port":listener.getsockname()[1]}
                  for mode,listener in listeners.items()}, sort_keys=True), flush=True)

def stop(*_):
    stopping.set()
    for listener in listeners.values():
        listener.close()
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGHUP, stop)
while True:
    time.sleep(60)
'''


class ProviderError(fixture.FixtureError):
    """A provider failure whose message is safe to persist."""


def _run(
    arguments: list[str],
    *,
    input_bytes: bytes | None = None,
    timeout: int = 30,
) -> subprocess.CompletedProcess[bytes]:
    try:
        completed = subprocess.run(
            arguments,
            input=input_bytes,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ProviderError("fixture command failed safely") from error
    if completed.returncode != 0:
        raise ProviderError(
            f"fixture command exited {completed.returncode}; output redacted"
        )
    return completed


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def _fingerprint_blob(encoded: str) -> str:
    try:
        blob = base64.b64decode(encoded, validate=True)
    except ValueError as error:
        raise ProviderError("invalid public host-key encoding") from error
    digest = base64.b64encode(hashlib.sha256(blob).digest()).decode().rstrip("=")
    return f"SHA256:{digest}"


def _fingerprint_public_key(path: Path) -> str:
    fields = path.read_text(encoding="utf-8").split()
    if len(fields) < 2:
        raise ProviderError("generated public host key is malformed")
    return _fingerprint_blob(fields[1])


def _scan_fingerprints(host: str, port: int) -> list[str]:
    scanned = _run(
        ["/usr/bin/ssh-keyscan", "-T", "5", "-p", str(port), host], timeout=10
    ).stdout.decode("utf-8", errors="strict")
    fingerprints = []
    for line in scanned.splitlines():
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) >= 3:
            fingerprints.append(_fingerprint_blob(fields[2]))
    if not fingerprints:
        raise ProviderError("pre-auth host-key scan returned no public keys")
    return sorted(set(fingerprints))


def _parse_key_values(encoded: bytes) -> dict[str, str]:
    values = {}
    for line in encoded.decode("utf-8", errors="strict").splitlines():
        key, separator, value = line.partition("=")
        if separator and key:
            values[key] = value
    return values


def _ssh_version() -> str:
    completed = subprocess.run(
        ["/usr/bin/ssh", "-V"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False
    )
    text = (completed.stderr or completed.stdout).decode("utf-8", errors="replace")
    match = re.search(r"OpenSSH_[^,\s]+", text)
    if completed.returncode != 0 or match is None:
        raise ProviderError("unable to observe the local OpenSSH version")
    return match.group(0)


class BuiltinProvider:
    def __init__(self, state_root: Path | None = None):
        configured = os.environ.get(STATE_ROOT_ENV)
        self.state_root = Path(configured) if configured else (state_root or DEFAULT_STATE_ROOT)
        self._processes: dict[int, subprocess.Popen[bytes]] = {}
        self._process_owners: dict[int, tuple[str, dict[str, object]]] = {}

    def handle(self, request: Mapping[str, object]) -> dict:
        if request.get("protocol") != "relux-ssh-matrix-provider-v1":
            raise ProviderError("provider protocol mismatch")
        server_id = request.get("serverId")
        if server_id not in fixture.REQUIRED_SERVERS:
            raise ProviderError("provider server ID is not in the fixture matrix")
        action = request.get("action")
        if action == "prepare":
            return self._prepare(str(server_id))
        if action == "rotate":
            return self._rotate(str(server_id))
        if action == "probe":
            return self._probe(str(server_id))
        if action == "control":
            scenario_id = request.get("scenarioId")
            if scenario_id not in fixture.SCENARIO_FIXTURE_EVIDENCE:
                raise ProviderError("provider scenario control is not approved")
            return self._control(str(server_id), str(scenario_id))
        if action == "teardown":
            return self._teardown(str(server_id))
        raise ProviderError("provider action is not supported")

    def _server_dir(self, server_id: str) -> Path:
        return self.state_root / server_id

    def _state_path(self, server_id: str) -> Path:
        return self._server_dir(server_id) / "state.json"

    def _load_state(self, server_id: str) -> dict:
        try:
            state = json.loads(self._state_path(server_id).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ProviderError(f"{server_id} provider state is unavailable") from error
        if not isinstance(state, dict) or state.get("serverId") != server_id:
            raise ProviderError(f"{server_id} provider state is invalid")
        return state

    def _save_state(self, server_id: str, state: dict) -> None:
        directory = self._server_dir(server_id)
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(directory, 0o700)
        path = self._state_path(server_id)
        temporary = path.with_suffix(".json.tmp")
        temporary.write_bytes(fixture.canonical_json(state))
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)

    def _record_process(
        self,
        server_id: str,
        process: subprocess.Popen[bytes],
        marker: str,
        kind: str,
    ) -> dict[str, object]:
        record: dict[str, object] = {
            "kind": kind,
            "marker": marker,
            "pid": process.pid,
        }
        self._processes[process.pid] = process
        self._process_owners[process.pid] = (server_id, record)
        try:
            state = self._load_state(server_id)
            state.setdefault("processes", []).append(record)
            self._save_state(server_id, state)
        except Exception:
            self._terminate_owned_process(process.pid, marker)
            raise
        return record

    def _set_lima_ownership(self, owned: bool) -> None:
        state = self._load_state("linux-current")
        state["limaInstanceOwned"] = owned
        self._save_state("linux-current", state)

    def _prepare(self, server_id: str) -> dict:
        directory = self._server_dir(server_id)
        existing_linux_instance = (
            server_id == "linux-current" and self._lima_instance_exists()
        )
        if directory.exists() or existing_linux_instance:
            self._teardown(server_id)
        self._save_state(
            server_id,
            {
                "limaInstanceOwned": False,
                "phase": "preparing",
                "processes": [],
                "serverId": server_id,
            },
        )
        if server_id.startswith("macos-"):
            prepared = self._prepare_macos(server_id)
        elif server_id == "linux-current":
            prepared = self._prepare_linux()
        else:
            prepared = self._prepare_relux()
        state = self._load_state(server_id)
        state.update(prepared)
        state["phase"] = "ready"
        self._save_state(server_id, state)
        return {"status": "ok", "runtime": state["runtime"]}

    def _generate_key(self, path: Path, key_type: str, comment: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        arguments = [
            "/usr/bin/ssh-keygen",
            "-q",
            "-t",
            key_type,
            "-N",
            "",
            "-C",
            comment,
            "-f",
            str(path),
        ]
        if key_type == "ecdsa":
            arguments[4:4] = ["-b", "256"]
        _run(arguments)
        os.chmod(path, 0o600)

    def _start_endpoint_supervisor(
        self, server_id: str, command_prefix: list[str] | None
    ) -> tuple[dict, dict]:
        directory = self._server_dir(server_id)
        output_path = directory / "endpoints.json"
        error_path = directory / "endpoints.log"
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        if command_prefix is None:
            arguments = [sys.executable, "-u", "-c", ENDPOINT_WORKER]
        else:
            remote_command = f"python3 -u -c {shlex.quote(ENDPOINT_WORKER)}"
            arguments = [*command_prefix, remote_command]
        with output_path.open("wb") as output, error_path.open("wb") as error:
            process = subprocess.Popen(
                arguments,
                stdin=subprocess.DEVNULL,
                stdout=output,
                stderr=error,
                start_new_session=True,
            )
        process_record = self._record_process(
            server_id,
            process,
            fixture.TASK_ID,
            "endpoints",
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise ProviderError("endpoint supervisor exited; output redacted")
            try:
                text = output_path.read_text(encoding="utf-8").strip()
                if text:
                    endpoints = json.loads(text.splitlines()[0])
                    fixture._validate_runtime(
                        server_id,
                        {
                            "runtime": {
                                "host": "127.0.0.1",
                                "port": 22,
                                "identityReference": "validation-only",
                                "destinationEndpoints": endpoints,
                            }
                        },
                    )
                    return endpoints, process_record
            except (OSError, json.JSONDecodeError, fixture.FixtureError):
                pass
            time.sleep(0.05)
        self._terminate_owned_process(process.pid, fixture.TASK_ID)
        raise ProviderError("endpoint supervisor did not become ready")

    def _prepare_macos(self, server_id: str) -> dict:
        directory = self._server_dir(server_id)
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        fallback = server_id == "macos-approved-older-profile"
        host_key = directory / "host-key"
        user_key = directory / "user-key-initial"
        self._generate_key(host_key, "ecdsa" if fallback else "ed25519", f"{fixture.TASK_ID}-{server_id}-host")
        self._generate_key(user_key, "ecdsa" if fallback else "ed25519", f"{fixture.TASK_ID}-{server_id}-user")
        authorized = directory / "authorized_keys"
        authorized.write_text(user_key.with_suffix(".pub").read_text(encoding="utf-8"), encoding="utf-8")
        os.chmod(authorized, 0o600)
        endpoints, _endpoint_process = self._start_endpoint_supervisor(server_id, None)
        port = _free_port()
        _sshd_process = self._start_macos_sshd(server_id, port, host_key)
        runtime = {
            "account": getpass.getuser(),
            "destinationEndpoints": endpoints,
            "host": "127.0.0.1",
            "identityReference": f"ephemeral-file://{user_key}",
            "port": port,
            "stdioExec": REMOTE_STDIO,
        }
        return {
            "hostKey": str(host_key),
            "hostKeyType": "ecdsa-sha2-nistp256" if fallback else "ssh-ed25519",
            "runtime": runtime,
            "serverId": server_id,
            "userKey": str(user_key),
            "userKeyType": "ecdsa-sha2-nistp256" if fallback else "ssh-ed25519",
        }

    def _start_macos_sshd(self, server_id: str, port: int, host_key: Path) -> dict:
        directory = self._server_dir(server_id)
        configuration = directory / "sshd_config"
        log = directory / "sshd.log"
        fallback = server_id == "macos-approved-older-profile"
        directives = [
            f"Port {port}",
            "ListenAddress 127.0.0.1",
            "Protocol 2",
            f"HostKey {host_key}",
            f"PidFile {directory / 'sshd.pid'}",
            f"AuthorizedKeysFile {directory / 'authorized_keys'}",
            "StrictModes no",
            "PasswordAuthentication no",
            "KbdInteractiveAuthentication no",
            "PubkeyAuthentication yes",
            "UsePAM no",
            "PermitRootLogin no",
            f"AllowUsers {getpass.getuser()}",
            "AllowTcpForwarding yes",
            "RekeyLimit 32K 0",
            "LogLevel VERBOSE",
        ]
        if fallback:
            directives.extend(
                [
                    "KexAlgorithms diffie-hellman-group14-sha256",
                    "HostKeyAlgorithms ecdsa-sha2-nistp256",
                    "Ciphers aes128-ctr",
                    "MACs hmac-sha2-512",
                ]
            )
        configuration.write_text("\n".join(directives) + "\n", encoding="utf-8")
        _run(["/usr/sbin/sshd", "-t", "-f", str(configuration)])
        process = subprocess.Popen(
            ["/usr/sbin/sshd", "-D", "-E", str(log), "-f", str(configuration)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        process_record = self._record_process(
            server_id,
            process,
            str(directory),
            "sshd",
        )
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise ProviderError("task-owned macOS sshd exited; output redacted")
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                    return process_record
            except OSError:
                time.sleep(0.05)
        self._terminate_owned_process(process.pid, str(directory))
        raise ProviderError("task-owned macOS sshd did not become reachable")

    def _lima_config(self) -> tuple[Path, str]:
        config = Path.home() / ".lima" / LIMA_INSTANCE / "ssh.config"
        return config, f"lima-{LIMA_INSTANCE}"

    def _prepare_linux(self) -> dict:
        listing = subprocess.run(
            ["limactl", "list", LIMA_INSTANCE, "--json"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if listing.returncode != 0 or not listing.stdout.strip():
            self._set_lima_ownership(True)
            _run(
                [
                    "limactl", "start", "-y", "--name", LIMA_INSTANCE,
                    "--mount-none", "--containerd", "none", "--cpus", "1",
                    "--memory", "1", "--disk", "5", "template:ubuntu-24.04",
                ],
                timeout=180,
            )
        else:
            self._set_lima_ownership(True)
            _run(["limactl", "start", LIMA_INSTANCE], timeout=60)
        config, alias = self._lima_config()
        endpoints, _endpoint_process = self._start_endpoint_supervisor(
            "linux-current", ["/usr/bin/ssh", "-F", str(config), alias]
        )
        runtime = self._install_linux_identity("initial")
        runtime["destinationEndpoints"] = endpoints
        runtime["stdioExec"] = REMOTE_STDIO
        return {
            "runtime": runtime,
            "serverId": "linux-current",
            "userKey": runtime["identityReference"].removeprefix("ephemeral-file://"),
        }

    def _ssh_config_values(self, config: Path | None, alias: str) -> dict[str, str]:
        arguments = ["/usr/bin/ssh", "-G"]
        if config is not None:
            arguments.extend(["-F", str(config)])
        arguments.append(alias)
        completed = _run(arguments)
        values = {}
        for line in completed.stdout.decode("utf-8", errors="strict").splitlines():
            key, separator, value = line.partition(" ")
            if separator:
                values[key.lower()] = value
        for required in ("hostname", "port", "user"):
            if not values.get(required):
                raise ProviderError("SSH configuration is missing a required runtime field")
        return values

    def _install_linux_identity(self, generation: str) -> dict:
        directory = self._server_dir("linux-current")
        key = directory / f"user-key-{generation}"
        self._generate_key(key, "ed25519", f"{fixture.TASK_ID}-linux-current")
        public_key = key.with_suffix(".pub").read_text(encoding="utf-8").strip()
        cleanup = (
            "set -eu; umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; "
            f"grep -v {shlex.quote(fixture.TASK_ID + '-linux-current')} ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp || true; "
            f"printf '%s\\n' {shlex.quote(public_key)} >> ~/.ssh/authorized_keys.tmp; "
            "mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
        )
        _run(["limactl", "shell", LIMA_INSTANCE, "--", "bash", "-lc", cleanup])
        config, alias = self._lima_config()
        values = self._ssh_config_values(config, alias)
        return {
            "account": values["user"],
            "host": values["hostname"],
            "identityReference": f"ephemeral-file://{key}",
            "port": int(values["port"]),
        }

    def _prepare_relux(self) -> dict:
        values = self._ssh_config_values(None, RELUX_ALIAS)
        endpoints, _endpoint_process = self._start_endpoint_supervisor(
            "relux-real",
            [
                "/usr/bin/ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                RELUX_ALIAS,
            ],
        )
        runtime = {
            "account": values["user"],
            "destinationEndpoints": endpoints,
            "host": values["hostname"],
            "identityReference": "ssh-config://relux",
            "port": int(values["port"]),
            "stdioExec": REMOTE_STDIO,
        }
        return {
            "runtime": runtime,
            "serverId": "relux-real",
        }

    def _rotate(self, server_id: str) -> dict:
        state = self._load_state(server_id)
        if server_id == "relux-real":
            return {
                "disposition": "external-owner-managed",
                "runtime": state["runtime"],
                "status": "ok",
            }
        if server_id == "linux-current":
            previous = Path(state["userKey"])
            runtime = self._install_linux_identity("rotated")
            runtime["destinationEndpoints"] = state["runtime"]["destinationEndpoints"]
            runtime["stdioExec"] = REMOTE_STDIO
            previous.unlink(missing_ok=True)
            previous.with_suffix(".pub").unlink(missing_ok=True)
            state["runtime"] = runtime
            state["userKey"] = runtime["identityReference"].removeprefix("ephemeral-file://")
        else:
            previous = Path(state["userKey"])
            rotated = self._server_dir(server_id) / "user-key-rotated"
            key_type = "ecdsa" if server_id == "macos-approved-older-profile" else "ed25519"
            self._generate_key(rotated, key_type, f"{fixture.TASK_ID}-{server_id}-user")
            authorized = self._server_dir(server_id) / "authorized_keys"
            authorized.write_text(rotated.with_suffix(".pub").read_text(encoding="utf-8"), encoding="utf-8")
            os.chmod(authorized, 0o600)
            previous.unlink(missing_ok=True)
            previous.with_suffix(".pub").unlink(missing_ok=True)
            state["userKey"] = str(rotated)
            state["runtime"]["identityReference"] = f"ephemeral-file://{rotated}"
        self._save_state(server_id, state)
        self._prove_reachability(server_id, state)
        return {"disposition": "rotated", "runtime": state["runtime"], "status": "ok"}

    def _identity_path(self, runtime: dict) -> Path:
        reference = runtime["identityReference"]
        if not reference.startswith("ephemeral-file://"):
            raise ProviderError("runtime identity is not a task-owned ephemeral key")
        return Path(reference.removeprefix("ephemeral-file://"))

    def _prove_reachability(self, server_id: str, state: dict) -> dict[str, str]:
        runtime = state["runtime"]
        remote_probe = (
            "set -eu; test \"$(id -u)\" -ne 0; "
            "printf 'reachable=1\\nprivilege=non-root\\nos='; uname -s; "
            "printf 'arch='; uname -m; "
            "printf 'openssh='; ssh -V 2>&1 | sed -E 's/[ ,].*//'"
        )
        if server_id == "relux-real":
            completed = _run(
                [
                    "/usr/bin/ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                    RELUX_ALIAS, remote_probe,
                ]
            )
        else:
            key = self._identity_path(runtime)
            completed = _run(
                [
                    "/usr/bin/ssh", "-F", "/dev/null", "-o", "BatchMode=yes",
                    "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=no",
                    "-o", "UserKnownHostsFile=/dev/null", "-i", str(key),
                    "-p", str(runtime["port"]),
                    f"{runtime['account']}@{runtime['host']}", remote_probe,
                ]
            )
        facts = _parse_key_values(completed.stdout)
        if facts.get("reachable") != "1" or facts.get("privilege") != "non-root":
            raise ProviderError(f"{server_id} did not prove least-privilege reachability")
        return facts

    def _probe(self, server_id: str) -> dict:
        state = self._load_state(server_id)
        facts = self._prove_reachability(server_id, state)
        runtime = state["runtime"]
        if server_id.startswith("macos-"):
            fingerprints = [_fingerprint_public_key(Path(state["hostKey"] + ".pub"))]
            os_name = "macOS"
            os_version = _run(["/usr/bin/sw_vers", "-productVersion"]).stdout.decode().strip()
            openssh = _ssh_version()
            user_types = [state["userKeyType"]]
        else:
            fingerprints = _scan_fingerprints(runtime["host"], runtime["port"])
            os_name = "Ubuntu" if server_id == "linux-current" else "macOS"
            os_version = "24.04" if server_id == "linux-current" else "runtime-current"
            openssh = facts["openssh"]
            user_types = ["ssh-ed25519"]
        return {
            "observation": {
                "architecture": facts["arch"],
                "hostKeyFingerprints": fingerprints,
                "opensshVersion": openssh,
                "osName": os_name,
                "osVersion": os_version,
                "privilege": "non-root",
                "reachable": True,
                "userKeyTypes": user_types,
            },
            "status": "ok",
        }

    def _control(self, server_id: str, scenario_id: str) -> dict:
        state = self._load_state(server_id)
        runtime = dict(state["runtime"])
        if server_id not in {"macos-current", "macos-approved-older-profile"}:
            raise ProviderError("destructive scenario controls are restricted to task-owned macOS fixtures")
        directory = self._server_dir(server_id)
        if scenario_id == "host-key-first-use":
            known_hosts = directory / "known-hosts-empty"
            known_hosts.write_bytes(b"")
            runtime["scenarioControl"] = {
                "knownHostsReference": f"ephemeral-file://{known_hosts}"
            }
        elif scenario_id == "host-key-change":
            previous_fingerprint = _fingerprint_public_key(Path(state["hostKey"] + ".pub"))
            old_process = next(
                process for process in state["processes"] if process.get("kind") == "sshd"
            )
            self._terminate_owned_process(old_process["pid"], old_process["marker"])
            changed = directory / f"host-key-changed-{int(time.time_ns())}"
            key_type = "ecdsa" if server_id == "macos-approved-older-profile" else "ed25519"
            self._generate_key(changed, key_type, f"{fixture.TASK_ID}-{server_id}-changed")
            replacement = self._start_macos_sshd(server_id, runtime["port"], changed)
            replacement["kind"] = "sshd"
            state["processes"] = [
                replacement if process is old_process else process for process in state["processes"]
            ]
            state["hostKey"] = str(changed)
            runtime["scenarioControl"] = {"approvedFingerprint": previous_fingerprint}
        elif scenario_id == "auth-rejection":
            rejected = directory / f"user-key-rejected-{int(time.time_ns())}"
            self._generate_key(rejected, "ed25519", f"{fixture.TASK_ID}-{server_id}-rejected")
            runtime["identityReference"] = f"ephemeral-file://{rejected}"
            runtime["scenarioControl"] = {"authentication": "unapproved-public-key"}
        elif scenario_id == "channel-rejection":
            runtime["scenarioControl"] = {
                "rejectedDestination": {"host": "127.0.0.1", "port": _free_port()}
            }
        elif scenario_id == "server-rekey":
            runtime["scenarioControl"] = {"rekeyLimitBytes": 32 * 1024}
        else:
            endpoint = {
                "early-close": "early-close", "half-close": "half-close",
                "reset": "reset", "disconnect": "disconnect",
            }.get(scenario_id)
            if endpoint:
                runtime["scenarioControl"] = {"endpoint": endpoint}
            elif scenario_id == "latency":
                runtime["scenarioControl"] = {"latencyMilliseconds": 75}
            elif scenario_id == "loss":
                runtime["scenarioControl"] = {"deterministicDropEvery": 10}
        state["runtime"] = state["runtime"]
        self._save_state(server_id, state)
        return {
            "fixtureEvidenceCode": fixture.SCENARIO_FIXTURE_EVIDENCE[scenario_id],
            "runtime": runtime,
            "scenarioId": scenario_id,
            "status": "ok",
        }

    def _terminate_owned_process(self, pid: int, marker: str) -> None:
        if not isinstance(pid, int) or pid <= 1:
            raise ProviderError("refusing to terminate an invalid process ID")
        inspected = subprocess.run(
            ["/bin/ps", "-p", str(pid), "-o", "command="],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if inspected.returncode != 0:
            self._processes.pop(pid, None)
            self._process_owners.pop(pid, None)
            return
        command = inspected.stdout.decode("utf-8", errors="replace")
        if marker not in command and fixture.TASK_ID not in command:
            raise ProviderError("refusing to terminate a process outside task ownership")
        os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            tracked = self._processes.get(pid)
            if tracked is not None and tracked.poll() is not None:
                tracked.wait()
                self._processes.pop(pid, None)
                self._process_owners.pop(pid, None)
                return
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                self._processes.pop(pid, None)
                self._process_owners.pop(pid, None)
                return
            time.sleep(0.05)
        os.kill(pid, signal.SIGKILL)
        tracked = self._processes.pop(pid, None)
        self._process_owners.pop(pid, None)
        if tracked is not None:
            tracked.wait(timeout=2)

    def _lima_instance_exists(self) -> bool:
        completed = _run(["limactl", "list", "--json"], timeout=30)
        try:
            encoded = completed.stdout.decode("utf-8", errors="strict")
            decoder = json.JSONDecoder()
            offset = 0
            records = []
            while offset < len(encoded):
                while offset < len(encoded) and encoded[offset].isspace():
                    offset += 1
                if offset == len(encoded):
                    break
                value, offset = decoder.raw_decode(encoded, offset)
                records.extend(value if isinstance(value, list) else [value])
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ProviderError("unable to verify Lima fixture absence") from error
        if not all(isinstance(record, dict) and isinstance(record.get("name"), str) for record in records):
            raise ProviderError("unable to verify Lima fixture absence")
        return any(record["name"] == LIMA_INSTANCE for record in records)

    def _teardown(self, server_id: str) -> dict:
        path = self._state_path(server_id)
        state = None
        if path.exists():
            state = self._load_state(server_id)
        processes = {
            process["pid"]: process
            for process in (state or {}).get("processes", [])
            if isinstance(process, dict) and isinstance(process.get("pid"), int)
        }
        for pid, (owner, process) in self._process_owners.items():
            if owner == server_id:
                processes[pid] = process
        cleanup_failures = []
        for process in reversed(list(processes.values())):
            try:
                self._terminate_owned_process(process["pid"], process["marker"])
            except (OSError, ProviderError, subprocess.TimeoutExpired) as error:
                cleanup_failures.append(error)
        if server_id == "linux-current":
            try:
                if self._lima_instance_exists():
                    _run(["limactl", "delete", "-f", LIMA_INSTANCE], timeout=60)
                if self._lima_instance_exists():
                    raise ProviderError("Lima fixture instance remains after delete")
            except (OSError, ProviderError, subprocess.TimeoutExpired) as error:
                cleanup_failures.append(error)
        if cleanup_failures:
            first_failure = cleanup_failures[0]
            if isinstance(first_failure, ProviderError):
                raise first_failure
            raise ProviderError(
                "provider teardown could not verify zero residual resources"
            ) from first_failure
        directory = self._server_dir(server_id)
        if directory.exists():
            shutil.rmtree(directory)
        residual = int(directory.exists())
        return {"residualResources": residual, "status": "ok" if residual == 0 else "fail"}


def _tag_process_kinds(state_root: Path, server_id: str) -> None:
    path = state_root / server_id / "state.json"
    state = json.loads(path.read_text(encoding="utf-8"))
    if server_id.startswith("macos-") and len(state.get("processes", [])) == 2:
        state["processes"][0]["kind"] = "endpoints"
        state["processes"][1]["kind"] = "sshd"
    elif state.get("processes"):
        state["processes"][0]["kind"] = "endpoints"
    path.write_bytes(fixture.canonical_json(state))
    os.chmod(path, 0o600)


def dispatch(provider: BuiltinProvider, request: Mapping[str, object]) -> dict:
    response = provider.handle(request)
    if request.get("action") == "prepare":
        _tag_process_kinds(provider.state_root, str(request["serverId"]))
    return response


def run_lifecycle(provider: BuiltinProvider) -> dict:
    manifest = fixture.load_manifest()
    servers = {server["id"]: server for server in manifest["servers"]}
    prepared = []
    observations = []
    failure: Exception | None = None
    try:
        for server_id in sorted(fixture.REQUIRED_SERVERS):
            prepared.append(server_id)
            dispatch(
                provider,
                {
                    "action": "prepare", "protocol": "relux-ssh-matrix-provider-v1",
                    "secretReference": servers[server_id]["identity"]["secretReference"],
                    "serverId": server_id,
                },
            )
            rotation = dispatch(
                provider,
                {"action": "rotate", "protocol": "relux-ssh-matrix-provider-v1", "serverId": server_id},
            )
            expected = "external-owner-managed" if server_id == "relux-real" else "rotated"
            if rotation.get("disposition") != expected:
                raise ProviderError(f"{server_id} lifecycle rotation evidence drifted")
            probe = dispatch(
                provider,
                {"action": "probe", "protocol": "relux-ssh-matrix-provider-v1", "serverId": server_id},
            )
            public = fixture._validate_public_observation(servers[server_id], probe)
            observations.append(
                {
                    "architecture": public["architecture"],
                    "hostKeyFingerprints": public["hostKeyFingerprints"],
                    "opensshVersion": public["opensshVersion"],
                    "osName": public["osName"],
                    "osVersion": public["osVersion"],
                    "privilege": public["privilege"],
                    "reachable": public["reachable"],
                    "rotation": expected,
                    "serverId": server_id,
                    "userKeyTypes": public["userKeyTypes"],
                }
            )
        for scenario_id in sorted(fixture.SCENARIO_FIXTURE_EVIDENCE):
            server_id = fixture.SCENARIO_SERVER[scenario_id]
            control = dispatch(
                provider,
                {
                    "action": "control", "protocol": "relux-ssh-matrix-provider-v1",
                    "scenarioId": scenario_id, "serverId": server_id,
                },
            )
            if control.get("fixtureEvidenceCode") != fixture.SCENARIO_FIXTURE_EVIDENCE[scenario_id]:
                raise ProviderError(f"{scenario_id} lifecycle control evidence drifted")
    except Exception as error:
        failure = error
    teardown = []
    teardown_failures = []
    for server_id in reversed(prepared):
        try:
            response = dispatch(
                provider,
                {"action": "teardown", "protocol": "relux-ssh-matrix-provider-v1", "serverId": server_id},
            )
            teardown.append(
                {
                    "residualResources": response["residualResources"],
                    "serverId": server_id,
                }
            )
            if response.get("status") != "ok" or response.get("residualResources") != 0:
                teardown_failures.append(server_id)
        except Exception:
            teardown_failures.append(server_id)
    if teardown_failures:
        raise ProviderError(
            "provider lifecycle teardown could not verify zero residual resources"
        ) from failure
    if failure is not None:
        raise failure
    if any(row["residualResources"] != 0 for row in teardown):
        raise ProviderError("provider lifecycle teardown left residual resources")
    return {
        "payloadRetention": "none",
        "scenarioControls": sorted(fixture.SCENARIO_FIXTURE_EVIDENCE.values()),
        "schemaVersion": 1,
        "serverObservations": observations,
        "taskId": fixture.TASK_ID,
        "teardown": teardown,
    }


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("dispatch")
    lifecycle = commands.add_parser("lifecycle")
    lifecycle.add_argument("--output", type=Path)
    return root


def main(argv: list[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    provider = BuiltinProvider()
    try:
        if arguments.command == "dispatch":
            request = json.load(sys.stdin)
            if not isinstance(request, dict):
                raise ProviderError("provider request must be a JSON object")
            print(fixture.canonical_json(dispatch(provider, request)).decode(), end="")
        else:
            report = run_lifecycle(provider)
            encoded = fixture.canonical_json(report)
            if arguments.output is None:
                sys.stdout.buffer.write(encoded)
            else:
                arguments.output.parent.mkdir(parents=True, exist_ok=True)
                arguments.output.write_bytes(encoded)
                print(f"privacy-safe provider lifecycle report: {arguments.output}")
        return 0
    except (ProviderError, fixture.FixtureError, OSError, json.JSONDecodeError) as error:
        print(f"ssh-matrix-provider: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
