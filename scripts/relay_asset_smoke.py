#!/usr/bin/env python3
"""Native/emulated runtime-boundary gate for one manifest-selected relay asset."""

from __future__ import annotations

import argparse
import ctypes
import errno
import hashlib
import json
import os
import platform
import re
import select
import selectors
import shutil
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import relay_release


MAX_CAPTURE_BYTES = 4096
MAX_REPORT_BYTES = 32768
MAX_COMMAND_ARGUMENTS = 12
MAX_SAFE_VALUE_BYTES = 96
PROCESS_TIMEOUT_SECONDS = 5.0
CLIENT_HELLO = b"RLXR" + struct.pack(">HHI", 1, 0, 4096)
SERVER_HELLO = b"RLXR" + struct.pack(">HHII", 1, 0, 0, 4096)
REJECTED_HELLO = b"RLXR" + struct.pack(">HHII", 1, 2, 0, 0)
SUPPORTED_TARGETS = tuple(
    f"{target['os']}/{target['arch']}" for target in relay_release.TARGETS
)
SAFE_LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}\Z")
SAFE_ERROR_CODE = re.compile(r"[a-z0-9][a-z0-9_-]{0,95}\Z")
SAFE_ARGUMENTS = frozenset(
    {
        "--identity",
        "--stdio",
        "--protocol",
        "--daemon",
        "--listen",
        "payload.example",
        "1",
        "2",
    }
)
DARWIN_SANDBOX_PROFILE = """(version 1)
(allow default)
(deny file-write*)
(deny network*)
(deny process-fork)
"""
CONTAINMENT_PROBE = r"""
import errno
import os
import socket
import subprocess
import sys

def require_denied(action):
    try:
        value = action()
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EPERM):
            return
        raise
    if isinstance(value, subprocess.Popen):
        value.kill()
        value.wait()
    if isinstance(value, socket.socket):
        value.close()
    raise SystemExit(91)

def bind_listener():
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        listener.bind(("127.0.0.1", 0))
    finally:
        listener.close()

require_denied(lambda: open(sys.argv[1], "wb"))
require_denied(bind_listener)
require_denied(lambda: subprocess.Popen(["/bin/sleep", "1"]))
sys.stdout.write("containment-ok\n")
"""


class GateFailure(Exception):
    """Finite, privacy-safe gate failure."""

    def __init__(
        self,
        code: str,
        *,
        exit_code: int | None = None,
        process_started: bool = False,
    ):
        super().__init__(code)
        self.code = code
        self.exit_code = exit_code
        self.process_started = process_started


def stable_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized_host_target() -> str:
    os_name = platform.system().lower()
    architecture = platform.machine().lower()
    architecture = {"x86_64": "amd64", "aarch64": "arm64"}.get(
        architecture, architecture
    )
    return f"{os_name}/{architecture}"


def bounded_label(value: str) -> str:
    return value if SAFE_LABEL.fullmatch(value) else "invalid"


def safe_error_code(value: str) -> str:
    return value if SAFE_ERROR_CODE.fullmatch(value) else "internal_gate_failure"


def safe_command(command: list[str], emulator_arguments: int = 0) -> list[str]:
    """Return a fixed-vocabulary semantic command, never host argv/path data."""
    if len(command) <= emulator_arguments:
        return []
    result = ["emulator"] if emulator_arguments else []
    result.append("relay")
    for argument in command[emulator_arguments + 1 : MAX_COMMAND_ARGUMENTS]:
        result.append(argument if argument in SAFE_ARGUMENTS else "<redacted>")
    return result


class _LandlockRulesetAttr(ctypes.Structure):
    _fields_ = [("handled_access_fs", ctypes.c_uint64)]


class _SockFilter(ctypes.Structure):
    _fields_ = [
        ("code", ctypes.c_ushort),
        ("jt", ctypes.c_ubyte),
        ("jf", ctypes.c_ubyte),
        ("k", ctypes.c_uint32),
    ]


class _SockFprog(ctypes.Structure):
    _fields_ = [("length", ctypes.c_ushort), ("filter", ctypes.POINTER(_SockFilter))]


def _linux_containment_preexec() -> None:
    """Deny filesystem mutation, sockets, and non-thread process creation."""
    libc = ctypes.CDLL(None, use_errno=True)
    syscall = libc.syscall
    syscall.restype = ctypes.c_long

    landlock_create_ruleset = 444
    landlock_restrict_self = 446
    landlock_create_ruleset_version = 1
    abi = syscall(
        landlock_create_ruleset,
        ctypes.c_void_p(),
        ctypes.c_size_t(0),
        ctypes.c_uint(landlock_create_ruleset_version),
    )
    if abi < 1:
        raise OSError(ctypes.get_errno(), "landlock unavailable")

    write_rights = (
        (1 << 1)
        | (1 << 4)
        | (1 << 5)
        | (1 << 6)
        | (1 << 7)
        | (1 << 8)
        | (1 << 9)
        | (1 << 10)
        | (1 << 11)
        | (1 << 12)
    )
    if abi >= 2:
        write_rights |= 1 << 13
    if abi >= 3:
        write_rights |= 1 << 14
    ruleset_attr = _LandlockRulesetAttr(write_rights)
    ruleset_fd = syscall(
        landlock_create_ruleset,
        ctypes.byref(ruleset_attr),
        ctypes.sizeof(ruleset_attr),
        ctypes.c_uint(0),
    )
    if ruleset_fd < 0:
        raise OSError(ctypes.get_errno(), "landlock ruleset failed")

    pr_set_no_new_privs = 38
    pr_set_seccomp = 22
    seccomp_mode_filter = 2
    if libc.prctl(pr_set_no_new_privs, 1, 0, 0, 0) != 0:
        os.close(ruleset_fd)
        raise OSError(ctypes.get_errno(), "no-new-privileges failed")
    if syscall(landlock_restrict_self, ruleset_fd, ctypes.c_uint(0)) != 0:
        saved_errno = ctypes.get_errno()
        os.close(ruleset_fd)
        raise OSError(saved_errno, "landlock restriction failed")
    os.close(ruleset_fd)

    architecture = platform.machine().lower()
    if architecture == "x86_64":
        clone, fork, vfork, clone3, socket_call = 56, 57, 58, 435, 41
    elif architecture in ("aarch64", "arm64"):
        clone, fork, vfork, clone3, socket_call = 220, -1, -1, 435, 198
    else:
        raise OSError(errno.ENOTSUP, "unsupported seccomp architecture")

    bpf_load_word_absolute = 0x20
    bpf_jump_equal = 0x15
    bpf_jump_set = 0x45
    bpf_return = 0x06
    seccomp_return_allow = 0x7FFF0000
    seccomp_return_errno = 0x00050000 | errno.EPERM
    clone_thread = 0x00010000
    instructions = [
        _SockFilter(bpf_load_word_absolute, 0, 0, 0),
        _SockFilter(bpf_jump_equal, 6, 0, clone),
        _SockFilter(bpf_jump_equal, 4, 0, fork),
        _SockFilter(bpf_jump_equal, 3, 0, vfork),
        _SockFilter(bpf_jump_equal, 2, 0, clone3),
        _SockFilter(bpf_jump_equal, 1, 0, socket_call),
        _SockFilter(bpf_return, 0, 0, seccomp_return_allow),
        _SockFilter(bpf_return, 0, 0, seccomp_return_errno),
        _SockFilter(bpf_load_word_absolute, 0, 0, 16),
        _SockFilter(bpf_jump_set, 0, 1, clone_thread),
        _SockFilter(bpf_return, 0, 0, seccomp_return_allow),
        _SockFilter(bpf_return, 0, 0, seccomp_return_errno),
    ]
    filter_array = (_SockFilter * len(instructions))(*instructions)
    filter_program = _SockFprog(len(instructions), filter_array)
    if (
        libc.prctl(
            pr_set_seccomp,
            seccomp_mode_filter,
            ctypes.byref(filter_program),
            0,
            0,
        )
        != 0
    ):
        raise OSError(ctypes.get_errno(), "seccomp restriction failed")


def contained_process_options(command: list[str]) -> tuple[list[str], dict[str, Any]]:
    if sys.platform == "darwin":
        sandbox_exec = Path("/usr/bin/sandbox-exec")
        if not sandbox_exec.is_file():
            raise GateFailure("runtime_containment_unavailable")
        return [str(sandbox_exec), "-p", DARWIN_SANDBOX_PROFILE, *command], {}
    if sys.platform.startswith("linux"):
        return command, {"preexec_fn": _linux_containment_preexec}
    raise GateFailure("runtime_containment_unsupported")


def terminate_process_group(process: subprocess.Popen[bytes]) -> int:
    if process.poll() is not None:
        assert process.returncode is not None
        return process.returncode
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return process.wait(timeout=PROCESS_TIMEOUT_SECONDS)


def close_process_pipes(process: subprocess.Popen[bytes]) -> None:
    for stream in (process.stdin, process.stdout, process.stderr):
        if stream is not None and not stream.closed:
            stream.close()


def collect_process(
    process: subprocess.Popen[bytes], timeout: float = PROCESS_TIMEOUT_SECONDS
) -> tuple[int, bytes, bytes]:
    selector = selectors.DefaultSelector()
    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    assert process.stdout is not None
    assert process.stderr is not None
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    selector.register(process.stderr, selectors.EVENT_READ, "stderr")
    deadline = time.monotonic() + timeout
    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise GateFailure("process_timeout")
            for key, _ in selector.select(min(remaining, 0.1)):
                chunk = os.read(key.fileobj.fileno(), 4096)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                buffer = buffers[key.data]
                buffer.extend(chunk)
                if len(buffer) > MAX_CAPTURE_BYTES:
                    raise GateFailure(f"{key.data}_limit_exceeded")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise GateFailure("process_timeout")
        return_code = process.wait(timeout=remaining)
        return return_code, bytes(buffers["stdout"]), bytes(buffers["stderr"])
    except (subprocess.TimeoutExpired, GateFailure) as error:
        exit_code = terminate_process_group(process)
        code = (
            error.code
            if isinstance(error, GateFailure)
            else "process_timeout_or_output_limit"
        )
        raise GateFailure(
            code,
            exit_code=exit_code,
            process_started=True,
        ) from None
    finally:
        selector.close()
        close_process_pipes(process)


def run_bounded(
    command: list[str],
    input_bytes: bytes,
    cwd: Path,
    environment: dict[str, str],
    *,
    contained: bool = True,
) -> tuple[int, bytes, bytes]:
    actual_command = command
    process_options: dict[str, Any] = {}
    if contained:
        actual_command, process_options = contained_process_options(command)
    try:
        process = subprocess.Popen(
            actual_command,
            cwd=cwd,
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            bufsize=0,
            **process_options,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise GateFailure("process_start_failed") from error
    assert process.stdin is not None
    try:
        process.stdin.write(input_bytes)
        process.stdin.close()
        process.stdin = None
        return collect_process(process)
    except (BrokenPipeError, OSError) as error:
        exit_code = terminate_process_group(process)
        close_process_pipes(process)
        raise GateFailure(
            "process_input_failed",
            exit_code=exit_code,
            process_started=True,
        ) from error


def read_exact(
    stream: Any, width: int, deadline: float, process: subprocess.Popen[bytes]
) -> bytes:
    result = bytearray()
    while len(result) < width:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            exit_code = terminate_process_group(process)
            raise GateFailure(
                "signal_smoke_handshake_timeout",
                exit_code=exit_code,
                process_started=True,
            )
        readable, _, _ = select.select([stream], [], [], min(remaining, 0.1))
        if not readable:
            if process.poll() is not None:
                raise GateFailure(
                    "signal_smoke_early_exit",
                    exit_code=process.returncode,
                    process_started=True,
                )
            continue
        chunk = os.read(stream.fileno(), width - len(result))
        if not chunk:
            raise GateFailure(
                "signal_smoke_truncated_stdout",
                exit_code=process.poll(),
                process_started=True,
            )
        result.extend(chunk)
    return bytes(result)


def direct_children(pid: int) -> list[int]:
    ps = shutil.which("ps", path="/usr/bin:/bin")
    if ps is None:
        raise GateFailure("process_observer_unavailable")
    result = subprocess.run(
        [ps, "-Ao", "pid=,ppid="],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        env={"PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"},
        timeout=PROCESS_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        raise GateFailure("process_observer_failed")
    children: list[int] = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0].isdigit() and fields[1].isdigit():
            if int(fields[1]) == pid:
                children.append(int(fields[0]))
    return children


def process_sockets(pid: int) -> list[str]:
    if sys.platform.startswith("linux"):
        descriptor_root = Path(f"/proc/{pid}/fd")
        try:
            return [
                entry.name
                for entry in descriptor_root.iterdir()
                if entry.readlink().as_posix().startswith("socket:[")
            ]
        except (FileNotFoundError, PermissionError, OSError) as error:
            raise GateFailure("socket_observer_failed") from error
    if sys.platform == "darwin":
        lsof = shutil.which("lsof", path="/usr/sbin:/usr/bin:/bin")
        if lsof is None:
            raise GateFailure("socket_observer_unavailable")
        result = subprocess.run(
            [lsof, "-nP", "-a", "-p", str(pid), "-i"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env={"PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"},
            timeout=PROCESS_TIMEOUT_SECONDS,
        )
        if result.returncode == 1 and not result.stdout:
            return []
        if result.returncode != 0:
            raise GateFailure("socket_observer_failed")
        return result.stdout.splitlines()[1:]
    raise GateFailure("socket_observer_unavailable")


def no_process(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except PermissionError:
        return False
    return False


class SmokeGate:
    def __init__(
        self,
        target: str,
        runner_kind: str,
        runner_name: str,
        runner_owner: str,
        evidence_path: Path,
        emulator: list[str] | None = None,
        require_native: bool = False,
    ) -> None:
        self.target = target
        self.runner_kind = runner_kind
        self.runner_name = runner_name
        self.runner_owner = runner_owner
        self.evidence_path = evidence_path
        self.emulator = emulator or []
        self.require_native = require_native
        self.started = time.monotonic_ns()
        self.report: dict[str, Any] = {
            "schemaVersion": 1,
            "status": "running",
            "target": target,
            "runner": {
                "kind": runner_kind,
                "name": bounded_label(runner_name),
                "hostTarget": normalized_host_target(),
                "emulator": {
                    "configured": bool(self.emulator),
                    "argumentCount": min(len(self.emulator), MAX_COMMAND_ARGUMENTS),
                },
            },
            "nativeEvidence": {
                "owner": bounded_label(runner_owner),
                "requirement": f"native unprivileged runtime evidence for {target}",
                "satisfied": False,
            },
            "checks": [],
        }

    def record(
        self,
        name: str,
        started: int,
        status_value: str,
        exit_code: int | None = None,
        command: list[str] | None = None,
        process_started: bool = False,
    ) -> None:
        if len(self.report["checks"]) >= 64:
            raise GateFailure("report_check_limit_exceeded")
        safe_name = bounded_label(name)
        check: dict[str, Any] = {
            "name": safe_name,
            "status": status_value,
            "durationMilliseconds": round(
                (time.monotonic_ns() - started) / 1_000_000, 3
            ),
            "exitCode": exit_code,
            "processStarted": process_started,
        }
        if command is not None:
            check["command"] = safe_command(command, len(self.emulator))
        self.report["checks"].append(check)

    def validate_runner(self) -> None:
        started = time.monotonic_ns()
        host_target = normalized_host_target()
        if (
            SAFE_LABEL.fullmatch(self.runner_name) is None
            or SAFE_LABEL.fullmatch(self.runner_owner) is None
            or len(self.emulator) > MAX_COMMAND_ARGUMENTS
            or any(
                not argument
                or len(argument.encode("utf-8", errors="ignore")) > MAX_SAFE_VALUE_BYTES
                for argument in self.emulator
            )
        ):
            self.record("runner-metadata", started, "fail")
            raise GateFailure("runner_metadata_invalid")
        self.record("runner-metadata", started, "pass")
        if os.geteuid() == 0:
            self.record("unprivileged-runner", started, "fail")
            raise GateFailure("privileged_runner_forbidden")
        if self.runner_kind == "native":
            if host_target != self.target:
                self.record("runner-architecture", started, "fail")
                raise GateFailure("native_runner_identity_mismatch")
            self.report["nativeEvidence"]["satisfied"] = True
        elif not self.emulator:
            self.record("runner-architecture", started, "fail")
            raise GateFailure("emulator_command_required")
        if self.require_native and self.runner_kind != "native":
            self.record("runner-architecture", started, "fail")
            raise GateFailure("required_native_runner_missing")
        self.record("runner-architecture", started, "pass")
        self.record("unprivileged-runner", started, "pass")

    def validate_asset(self, executable: Path, manifest_path: Path) -> dict[str, Any]:
        started = time.monotonic_ns()
        try:
            manifest = relay_release.load_identity_manifest(manifest_path)
            target = relay_release.target_for_name(self.target)
            artifact = manifest["artifacts"][relay_release.TARGETS.index(target)]
            filename = relay_release.target_filename(target)
            expected_target = {
                "os": target["os"],
                "arch": target["arch"],
                "goTarget": self.target,
                "canonicalTarget": target["canonicalTarget"],
                "filename": filename,
                "sbom": f"{filename}.spdx.json",
            }
            if any(
                artifact.get(key) != value for key, value in expected_target.items()
            ):
                raise GateFailure("asset_manifest_target_mismatch")
            status_value = executable.lstat()
            if (
                not stat.S_ISREG(status_value.st_mode)
                or status_value.st_size <= 0
                or status_value.st_mode & 0o111 == 0
                or type(artifact.get("size")) is not int
                or not isinstance(artifact.get("sha256"), str)
                or relay_release.SHA256_PATTERN.fullmatch(artifact["sha256"]) is None
                or status_value.st_size != artifact["size"]
                or sha256(executable) != artifact["sha256"]
            ):
                raise GateFailure("asset_manifest_mismatch")
            relay_release.verify_binary_format(executable, target)
        except GateFailure:
            self.record("asset-manifest-and-architecture", started, "fail")
            raise
        except (OSError, KeyError, IndexError, relay_release.ReleaseError) as error:
            self.record("asset-manifest-and-architecture", started, "fail")
            raise GateFailure("asset_manifest_or_architecture_mismatch") from error
        self.report["artifact"] = {
            "filename": filename,
            "sizeBytes": artifact["size"],
            "sha256": artifact["sha256"],
            "canonicalTarget": artifact["canonicalTarget"],
            "binaryFormat": (
                "ELF64 little-endian" if target["os"] == "linux" else "Mach-O 64-bit"
            ),
        }
        self.report["revisions"] = {
            "sourceCommit": manifest["sourceCommit"],
            "relayVersion": manifest["relayVersion"],
            "relayProtocolVersion": manifest["relayProtocolVersion"],
            "go": manifest["toolchain"]["go"],
            "syft": manifest["toolchain"]["syft"],
        }
        self.record("asset-manifest-and-architecture", started, "pass")
        return manifest

    def runtime_environment(self, home: Path, temporary: Path) -> dict[str, str]:
        return {
            "PATH": "/usr/bin:/bin",
            "HOME": str(home),
            "TMPDIR": str(temporary),
            "TMP": str(temporary),
            "TEMP": str(temporary),
            "XDG_CACHE_HOME": str(home),
            "XDG_CONFIG_HOME": str(home),
            "LC_ALL": "C",
            "LANG": "C",
            "TZ": "UTC",
            "PYTHONDONTWRITEBYTECODE": "1",
        }

    def runtime_command(self, executable: Path, arguments: list[str]) -> list[str]:
        return [*self.emulator, str(executable), *arguments]

    def validate_containment(
        self,
        cwd: Path,
        environment: dict[str, str],
        outside_write_probe: Path,
    ) -> None:
        started = time.monotonic_ns()
        exit_code: int | None = None
        process_started = False
        command = [sys.executable, "-c", CONTAINMENT_PROBE, str(outside_write_probe)]
        try:
            exit_code, stdout, stderr = run_bounded(
                command,
                b"",
                cwd,
                environment,
            )
            process_started = True
            if (
                exit_code != 0
                or stdout != b"containment-ok\n"
                or stderr
                or outside_write_probe.exists()
            ):
                raise GateFailure(
                    "runtime_containment_probe_failed",
                    exit_code=exit_code,
                    process_started=True,
                )
        except GateFailure as error:
            self.record(
                "runtime-containment",
                started,
                "fail",
                error.exit_code if error.exit_code is not None else exit_code,
                process_started=error.process_started or process_started,
            )
            raise
        self.record(
            "runtime-containment",
            started,
            "pass",
            exit_code,
            process_started=True,
        )

    def expect_process(
        self,
        name: str,
        command: list[str],
        input_bytes: bytes,
        cwd: Path,
        environment: dict[str, str],
        expected_exit: int,
        expected_stdout: bytes,
        expected_stderr: bytes,
    ) -> bytes:
        started = time.monotonic_ns()
        exit_code: int | None = None
        process_started = False
        try:
            exit_code, stdout, stderr = run_bounded(
                command, input_bytes, cwd, environment
            )
            process_started = True
            if (
                exit_code != expected_exit
                or stdout != expected_stdout
                or stderr != expected_stderr
            ):
                raise GateFailure(
                    f"{name}_contract_mismatch",
                    exit_code=exit_code,
                    process_started=True,
                )
        except GateFailure as error:
            self.record(
                name,
                started,
                "fail",
                error.exit_code if error.exit_code is not None else exit_code,
                command,
                error.process_started or process_started,
            )
            raise
        self.record(name, started, "pass", exit_code, command, True)
        return stdout

    def signal_smoke(
        self,
        executable: Path,
        cwd: Path,
        environment: dict[str, str],
    ) -> None:
        command = self.runtime_command(executable, ["--stdio", "--protocol", "1"])
        started = time.monotonic_ns()
        exit_code: int | None = None
        process_started = False
        try:
            actual_command, process_options = contained_process_options(command)
            process = subprocess.Popen(
                actual_command,
                cwd=cwd,
                env=environment,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
                bufsize=0,
                **process_options,
            )
            process_started = True
        except (OSError, subprocess.SubprocessError, GateFailure) as error:
            self.record("signal-exit", started, "fail", command=command)
            if isinstance(error, GateFailure):
                raise
            raise GateFailure("signal_smoke_start_failed") from error
        try:
            assert process.stdin is not None
            assert process.stdout is not None
            process.stdin.write(CLIENT_HELLO)
            process.stdin.flush()
            reply = read_exact(
                process.stdout,
                len(SERVER_HELLO),
                time.monotonic() + PROCESS_TIMEOUT_SECONDS,
                process,
            )
            if reply != SERVER_HELLO:
                raise GateFailure("signal_smoke_stdout_contamination")

            observation_started = time.monotonic_ns()
            children = direct_children(process.pid)
            self.record(
                "no-child-processes",
                observation_started,
                "pass" if not children else "fail",
            )
            if children:
                raise GateFailure("child_process_detected")

            observation_started = time.monotonic_ns()
            sockets = process_sockets(process.pid)
            self.record(
                "no-listeners-or-sockets",
                observation_started,
                "pass" if not sockets else "fail",
            )
            if sockets:
                raise GateFailure("runtime_socket_detected")

            process.send_signal(signal.SIGTERM)
            exit_code, stdout, stderr = collect_process(process)
            if exit_code != 130 or stdout or stderr:
                raise GateFailure(
                    "signal_exit_contract_mismatch",
                    exit_code=exit_code,
                    process_started=True,
                )
            if not no_process(process.pid):
                raise GateFailure(
                    "process_residue_detected",
                    exit_code=exit_code,
                    process_started=True,
                )
        except (BrokenPipeError, OSError, GateFailure) as error:
            observed_exit = terminate_process_group(process)
            self.record(
                "signal-exit",
                started,
                "fail",
                (
                    error.exit_code
                    if isinstance(error, GateFailure) and error.exit_code is not None
                    else observed_exit
                ),
                command,
                process_started,
            )
            if isinstance(error, GateFailure):
                raise
            raise GateFailure(
                "signal_smoke_io_failed",
                exit_code=observed_exit,
                process_started=True,
            ) from error
        finally:
            close_process_pipes(process)
        self.record("signal-exit", started, "pass", 130, command, True)

    def exercise_runtime(self, executable: Path, manifest_path: Path) -> None:
        runtime_parent = self.evidence_path.parent.resolve()
        runtime_parent.mkdir(parents=True, exist_ok=True)
        runtime_root = Path(
            tempfile.mkdtemp(
                prefix=f"runtime-{self.target.replace('/', '-')}-", dir=runtime_parent
            )
        )
        working = runtime_root / "cwd"
        home = runtime_root / "home"
        temporary = runtime_root / "tmp"
        outside_write_probe = runtime_parent / f"{runtime_root.name}-outside-write"
        for directory in (working, home, temporary):
            directory.mkdir(mode=0o700)
            directory.chmod(0o555)
        environment = self.runtime_environment(home, temporary)
        environment["RELUX_SMOKE_EXTERNAL_WRITE_PROBE"] = str(outside_write_probe)
        try:
            self.validate_containment(working, environment, outside_write_probe)
            identity_command = self.runtime_command(
                executable, ["--identity", "--protocol", "1"]
            )
            started = time.monotonic_ns()
            exit_code: int | None = None
            process_started = False
            try:
                exit_code, identity_output, diagnostics = run_bounded(
                    identity_command, b"", working, environment
                )
                process_started = True
                if exit_code != 0 or diagnostics:
                    raise GateFailure(
                        "identity_process_contract_mismatch",
                        exit_code=exit_code,
                        process_started=True,
                    )
                relay_release.verify_identity_against_manifest(
                    identity_output, manifest_path, executable, self.target
                )
                identity = json.loads(identity_output)
            except (json.JSONDecodeError, relay_release.ReleaseError) as error:
                failure = GateFailure(
                    "identity_manifest_mismatch",
                    exit_code=exit_code,
                    process_started=process_started,
                )
                self.record(
                    "identity-and-self-hash",
                    started,
                    "fail",
                    exit_code,
                    identity_command,
                    process_started,
                )
                raise failure from error
            except GateFailure as error:
                self.record(
                    "identity-and-self-hash",
                    started,
                    "fail",
                    error.exit_code if error.exit_code is not None else exit_code,
                    identity_command,
                    error.process_started or process_started,
                )
                raise
            self.record(
                "identity-and-self-hash",
                started,
                "pass",
                exit_code,
                identity_command,
                True,
            )
            self.report["identity"] = identity

            stdio_command = self.runtime_command(
                executable, ["--stdio", "--protocol", "1"]
            )
            self.expect_process(
                "stdio-eof-and-stdout-framing",
                stdio_command,
                CLIENT_HELLO,
                working,
                environment,
                0,
                SERVER_HELLO,
                b"",
            )

            malformed = bytearray(CLIENT_HELLO)
            malformed[:4] = b"SECR"
            self.expect_process(
                "stderr-redaction",
                stdio_command,
                bytes(malformed),
                working,
                environment,
                65,
                REJECTED_HELLO,
                b"relux-relay: protocol rejected\n",
            )

            for suffix, arguments in (
                ("daemon", ["--daemon", "--protocol", "1"]),
                ("listener", ["--listen", "--protocol", "1"]),
                ("payload", ["payload.example", "--protocol", "1"]),
                ("version", ["--stdio", "--protocol", "2"]),
            ):
                command = self.runtime_command(executable, arguments)
                self.expect_process(
                    f"unsupported-{suffix}",
                    command,
                    b"",
                    working,
                    environment,
                    64,
                    b"",
                    b"relux-relay: unsupported invocation\n",
                )

            self.signal_smoke(executable, working, environment)
            file_started = time.monotonic_ns()
            unexpected = [
                path.relative_to(runtime_root).as_posix()
                for path in runtime_root.rglob("*")
                if not path.is_dir()
            ]
            unexpected.extend(
                f"{directory.relative_to(runtime_root).as_posix()}:mode"
                for directory in (working, home, temporary)
                if stat.S_IMODE(directory.stat().st_mode) != 0o555
            )
            self.record(
                "no-runtime-files-or-system-write-fallback",
                file_started,
                "pass" if not unexpected else "fail",
            )
            if unexpected:
                raise GateFailure("runtime_file_residue_detected")
        finally:
            cleanup_started = time.monotonic_ns()
            try:
                if outside_write_probe.exists():
                    outside_write_probe.unlink()
                for directory in (working, home, temporary):
                    if directory.exists():
                        directory.chmod(0o700)
                shutil.rmtree(runtime_root)
            except OSError as error:
                self.record("runtime-cleanup", cleanup_started, "fail")
                raise GateFailure("runtime_cleanup_failed") from error
            self.record("runtime-cleanup", cleanup_started, "pass")

    def finish(self, status_value: str, error_code: str | None = None) -> None:
        self.report["status"] = status_value
        self.report["durationMilliseconds"] = round(
            (time.monotonic_ns() - self.started) / 1_000_000, 3
        )
        if error_code is not None:
            self.report["errorCode"] = safe_error_code(error_code)
        self.evidence_path.parent.mkdir(parents=True, exist_ok=True)
        encoded = stable_json(self.report)
        if len(encoded) > MAX_REPORT_BYTES:
            encoded = stable_json(
                {
                    "schemaVersion": 1,
                    "status": "fail",
                    "target": self.target,
                    "runner": {
                        "kind": self.runner_kind,
                        "name": bounded_label(self.runner_name),
                        "hostTarget": normalized_host_target(),
                    },
                    "errorCode": "report_size_limit_exceeded",
                    "checks": [],
                }
            )
        self.evidence_path.write_bytes(encoded)


def run_gate(arguments: argparse.Namespace) -> int:
    gate = SmokeGate(
        target=arguments.target,
        runner_kind=arguments.runner_kind,
        runner_name=arguments.runner_name,
        runner_owner=arguments.runner_owner,
        evidence_path=Path(arguments.evidence),
        emulator=arguments.emulator,
        require_native=arguments.require_native,
    )
    try:
        gate.validate_runner()
        executable = Path(os.path.abspath(arguments.executable))
        manifest_path = Path(os.path.abspath(arguments.manifest))
        gate.validate_asset(executable, manifest_path)
        gate.exercise_runtime(executable, manifest_path)
    except GateFailure as error:
        gate.finish("fail", error.code)
        print(f"relay-asset-smoke: {error.code}", file=sys.stderr)
        return 1
    gate.finish("pass")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--target", required=True, choices=SUPPORTED_TARGETS)
    result.add_argument("--runner-kind", required=True, choices=("native", "emulated"))
    result.add_argument("--runner-name", required=True)
    result.add_argument("--runner-owner", required=True)
    result.add_argument("--require-native", action="store_true")
    result.add_argument("--emulator", action="append", default=[])
    result.add_argument("--manifest", required=True)
    result.add_argument("--executable", required=True)
    result.add_argument("--evidence", required=True)
    return result


def main() -> int:
    return run_gate(parser().parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
