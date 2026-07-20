#!/usr/bin/env python3
"""Verify, build, and test the bounded Relux libssh2 client-rekey fork."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import pwd
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
NATIVE_MANIFEST_PATH = REPOSITORY_ROOT / "NativeDependencies" / "manifest.json"
FORK_ROOT = REPOSITORY_ROOT / "Dependencies" / "ReluxLibSSH2"
PATCH_MANIFEST_PATH = FORK_ROOT / "PATCH_MANIFEST.json"
DEPENDENCY_NAME = "libssh2-openssl"
SOURCE_DATE_EPOCH = "1784505600"


class ForkError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def artifact_hashes(path: Path) -> dict[str, str]:
    if not path.is_dir():
        raise ForkError(f"missing XCFramework: {path}")
    return {
        str(file.relative_to(path)): sha256_file(file)
        for file in sorted(path.rglob("*"))
        if file.is_file()
    }


def load_json(path: Path) -> dict[str, Any]:
    with path.open("rb") as stream:
        return json.load(stream)


def load_configuration() -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = load_json(NATIVE_MANIFEST_PATH)
    if manifest.get("schema_version") != 1:
        raise ForkError("unsupported native dependency manifest schema")
    try:
        item = manifest["dependencies"][DEPENDENCY_NAME]
    except KeyError as error:
        raise ForkError(f"missing {DEPENDENCY_NAME} native manifest entry") from error
    return manifest, item


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    environment: dict[str, str] | None = None,
    capture: bool = False,
) -> str:
    merged_environment = os.environ.copy()
    if environment:
        merged_environment.update(environment)
    print(f"+ {shlex.join(command)}", flush=True)
    result = subprocess.run(
        command,
        cwd=cwd,
        env=merged_environment,
        check=False,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
        text=True,
    )
    if result.returncode != 0:
        output = result.stdout.strip() if result.stdout else ""
        suffix = f"\n{output}" if output else ""
        raise ForkError(f"command failed: {shlex.join(command)}{suffix}")
    return result.stdout if capture and result.stdout else ""


def verify_patch_manifest(item: dict[str, Any]) -> None:
    patch_manifest = load_json(PATCH_MANIFEST_PATH)
    if patch_manifest.get("schema_version") != 1:
        raise ForkError("unsupported patch manifest schema")
    source = item["source"]["libssh2"]
    upstream = patch_manifest["upstream"]
    if upstream["revision"] != source["revision"]:
        raise ForkError("patch and native manifests disagree on libssh2 revision")
    if upstream["archive_sha256"] != source["archive_sha256"]:
        raise ForkError("patch and native manifests disagree on libssh2 archive hash")

    patches = patch_manifest["patches"]
    policy = patch_manifest["delta_policy"]
    if len(patches) > policy["maximum_patch_count"] or len(patches) != 1:
        raise ForkError("libssh2 fork must contain exactly one bounded patch")
    if policy["crypto_or_algorithm_changes_allowed"] is not False:
        raise ForkError("libssh2 fork policy must prohibit crypto/algorithm changes")
    if policy["private_headers_exported"] is not False:
        raise ForkError("libssh2 fork policy must prohibit private header export")

    patch_entry = patches[0]
    patch_path = FORK_ROOT / patch_entry["path"]
    if sha256_file(patch_path) != patch_entry["sha256"]:
        raise ForkError("libssh2 patch hash does not match PATCH_MANIFEST.json")
    patch_text = patch_path.read_text(encoding="utf-8")
    changed_paths = {
        match.group(1)
        for match in re.finditer(r"^\+\+\+ b/(.+)$", patch_text, re.MULTILINE)
    }
    allowed_paths = set(patch_entry["allowed_paths"])
    if changed_paths != allowed_paths:
        raise ForkError(
            f"patch paths are not the exact allowlist: {sorted(changed_paths)}"
        )
    if len(changed_paths) > policy["maximum_changed_paths"]:
        raise ForkError("libssh2 patch exceeds maximum changed path count")
    required_fragments = (
        "LIBSSH2_API int libssh2_session_rekey(LIBSSH2_SESSION *session);",
        "ssh2_kex_exchange(session, 1, &session->startup_key_state)",
        "BLOCK_ADJUST(rc, session,",
    )
    if any(fragment not in patch_text for fragment in required_fragments):
        raise ForkError("libssh2 patch does not contain the required public wrapper")
    prohibited = ("src/kex.c", "src/openssl.c", "src/crypto", "src/hostkey.c")
    if any(path in patch_text for path in prohibited):
        raise ForkError("libssh2 patch touches prohibited crypto/algorithm surfaces")


def verify_archive(path: Path, expected_sha256: str, name: str) -> None:
    if not path.is_file():
        raise ForkError(f"missing {name} source archive: {path}")
    actual = sha256_file(path)
    if actual != expected_sha256:
        raise ForkError(
            f"{name} source checksum mismatch before patching: expected "
            f"{expected_sha256}, got {actual}"
        )


def extract_archive(path: Path, destination: Path, top_level: str) -> Path:
    destination.mkdir(parents=True)
    with tarfile.open(path, "r:gz") as archive:
        members = archive.getmembers()
        if not members:
            raise ForkError(f"empty source archive: {path}")
        prefix = f"{top_level}/"
        for member in members:
            if member.name != top_level and not member.name.startswith(prefix):
                raise ForkError(f"unexpected archive root in {path}: {member.name}")
            candidate = Path(member.name)
            if candidate.is_absolute() or ".." in candidate.parts:
                raise ForkError(f"unsafe archive member in {path}: {member.name}")
            if member.isdev():
                raise ForkError(f"device archive member is prohibited: {member.name}")
        archive.extractall(destination, filter="data")
    root = destination / top_level
    if not root.is_dir():
        raise ForkError(f"archive did not produce expected root: {root}")
    return root


def verify_license_inputs(
    item: dict[str, Any], libssh2_source: Path, openssl_source: Path
) -> None:
    roots = {"libssh2": libssh2_source, "openssl": openssl_source}
    for component in item["license"]["components"]:
        path = roots[component["archive"]] / component["path"]
        if not path.is_file():
            raise ForkError(f"missing license input: {path}")
        actual = sha256_file(path)
        if actual != component["sha256"]:
            raise ForkError(
                f"license checksum mismatch for {component['name']}: "
                f"expected {component['sha256']}, got {actual}"
            )


def file_state(root: Path) -> dict[str, str]:
    state: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            state[relative] = f"symlink:{os.readlink(path)}"
        elif path.is_file():
            state[relative] = sha256_file(path)
    return state


def prepare_sources(
    item: dict[str, Any], libssh2_archive: Path, openssl_archive: Path, work: Path
) -> tuple[Path, Path, Path]:
    verify_patch_manifest(item)
    libssh2_pin = item["source"]["libssh2"]
    openssl_pin = item["source"]["openssl"]

    # Both source identities are verified before either archive is extracted or
    # the fork patch is applied. A mismatch therefore fails closed at the seam.
    verify_archive(libssh2_archive, libssh2_pin["archive_sha256"], "libssh2")
    verify_archive(openssl_archive, openssl_pin["archive_sha256"], "OpenSSL")

    upstream = work / "upstream"
    libssh2_source = extract_archive(
        libssh2_archive, upstream / "libssh2", libssh2_pin["top_level_directory"]
    )
    openssl_source = extract_archive(
        openssl_archive, upstream / "openssl", openssl_pin["top_level_directory"]
    )
    verify_license_inputs(item, libssh2_source, openssl_source)

    patched_source = work / "libssh2-patched"
    shutil.copytree(libssh2_source, patched_source, symlinks=True)
    for patch_entry in load_json(PATCH_MANIFEST_PATH)["patches"]:
        run(
            [
                "patch",
                "--batch",
                "--forward",
                "--no-backup-if-mismatch",
                "-p1",
                "-i",
                str((FORK_ROOT / patch_entry["path"]).resolve()),
            ],
            cwd=patched_source,
        )

    pristine_state = file_state(libssh2_source)
    patched_state = file_state(patched_source)
    changed_paths = {
        path
        for path in set(pristine_state) | set(patched_state)
        if pristine_state.get(path) != patched_state.get(path)
    }
    allowed_paths = set(load_json(PATCH_MANIFEST_PATH)["patches"][0]["allowed_paths"])
    if changed_paths != allowed_paths:
        raise ForkError(
            f"applied libssh2 delta is not the exact allowlist: {sorted(changed_paths)}"
        )
    public_header = (patched_source / "include" / "libssh2.h").read_text()
    session_source = (patched_source / "src" / "session.c").read_text()
    if "LIBSSH2_API int libssh2_session_rekey" not in public_header:
        raise ForkError("patched public header does not export libssh2_session_rekey")
    if "ssh2_kex_exchange(session, 1, &session->startup_key_state)" not in session_source:
        raise ForkError("patched wrapper does not invoke the existing reexchange path")
    return libssh2_source, patched_source, openssl_source


def write_notices(
    item: dict[str, Any], libssh2_source: Path, openssl_source: Path, output: Path
) -> None:
    roots = {"libssh2": libssh2_source, "openssl": openssl_source}
    sections = [
        "ReluxTunnel libssh2/OpenSSL third-party notices",
        "Generated only from checksum-verified pinned source archives.",
    ]
    for component in item["license"]["components"]:
        license_path = roots[component["archive"]] / component["path"]
        sections.extend(
            [
                "",
                "=" * 72,
                f"{component['name']} @ {component['revision']}",
                f"SPDX-License-Identifier: {component['spdx']}",
                f"Source license: {component['path']}",
                "=" * 72,
                license_path.read_text(encoding="utf-8").rstrip(),
            ]
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(sections) + "\n", encoding="utf-8")


def build_environment() -> dict[str, str]:
    return {
        "ZERO_AR_DATE": "1",
        "SOURCE_DATE_EPOCH": SOURCE_DATE_EPOCH,
        "LC_ALL": "C",
        "LANG": "C",
    }


def build_openssl(
    item: dict[str, Any], source: Path, build: dict[str, str], work: Path, sdk: str
) -> Path:
    architecture = build["architecture"]
    source_copy = work / f"openssl-{sdk}-{architecture}"
    shutil.copytree(source, source_copy, symlinks=True)
    install_root = work / f"openssl-install-{sdk}-{architecture}"
    logical_prefix = Path("/ReluxNative/OpenSSL-3.5.7")
    install = install_root / logical_prefix.relative_to("/")
    common_flags = list(item["compiler"]["common_c_flags"])
    configure = [
        "./Configure",
        build["openssl_target"],
        *item["compiler"]["openssl_configure_options"],
        build["minimum_flag"],
        *common_flags,
        f"--prefix={logical_prefix}",
        f"--openssldir={logical_prefix / 'ssl'}",
    ]
    run(configure, cwd=source_copy, environment=build_environment())
    jobs = str(max(1, os.cpu_count() or 1))
    run(["make", "-j", jobs, "build_libs"], cwd=source_copy, environment=build_environment())
    run(
        ["make", "install_sw", f"DESTDIR={install_root}"],
        cwd=source_copy,
        environment=build_environment(),
    )
    crypto = install / "lib" / "libcrypto.a"
    if not crypto.is_file():
        raise ForkError(f"OpenSSL build did not produce {crypto}")
    return install


def build_libssh2(
    item: dict[str, Any], source: Path, openssl: Path, build: dict[str, str],
    work: Path, sdk: str
) -> Path:
    architecture = build["architecture"]
    build_dir = work / f"libssh2-build-{sdk}-{architecture}"
    sdk_path = run(["xcrun", "--sdk", sdk, "--show-sdk-path"], capture=True).strip()
    clang = run(["xcrun", "--sdk", sdk, "--find", "clang"], capture=True).strip()
    flags = [
        *item["compiler"]["common_c_flags"],
        *(f"-D{definition}" for definition in item["compiler"]["libssh2_compile_definitions"]),
        f"-ffile-prefix-map={work}=.",
    ]
    command = [
        "cmake",
        "-S",
        str(source),
        "-B",
        str(build_dir),
        "-G",
        "Ninja",
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DCMAKE_C_COMPILER={clang}",
        f"-DCMAKE_C_COMPILER_TARGET={build['target_triple']}",
        f"-DCMAKE_OSX_SYSROOT={sdk_path}",
        f"-DCMAKE_OSX_ARCHITECTURES={architecture}",
        f"-DCMAKE_OSX_DEPLOYMENT_TARGET={build['target_triple'].split('ios')[-1].split('-')[0] if 'ios' in build['target_triple'] else build['target_triple'].split('macos')[-1]}",
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        f"-DOPENSSL_ROOT_DIR={openssl}",
        f"-DOPENSSL_INCLUDE_DIR={openssl / 'include'}",
        f"-DOPENSSL_CRYPTO_LIBRARY={openssl / 'lib' / 'libcrypto.a'}",
        f"-DCMAKE_C_FLAGS={' '.join(flags)}",
        *item["compiler"]["libssh2_cmake_flags"],
    ]
    run(command, environment=build_environment())
    run(
        ["cmake", "--build", str(build_dir), "--parallel"],
        environment=build_environment(),
    )
    archive = build_dir / "src" / "libssh2.a"
    if not archive.is_file():
        raise ForkError(f"libssh2 build did not produce {archive}")
    return archive


def normalize_xcframework(path: Path) -> None:
    info_path = path / "Info.plist"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    info["AvailableLibraries"] = sorted(
        info["AvailableLibraries"], key=lambda library: library["LibraryIdentifier"]
    )
    with info_path.open("wb") as stream:
        plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=True)


def stage_public_headers(patched_source: Path, output: Path) -> None:
    output.mkdir(parents=True)
    for name in ("libssh2.h", "libssh2_publickey.h", "libssh2_sftp.h"):
        shutil.copy2(patched_source / "include" / name, output / name)
    shutil.copy2(FORK_ROOT / "include" / "module.modulemap", output / "module.modulemap")


def build_xcframework(
    item: dict[str, Any], libssh2_archive: Path, openssl_archive: Path,
    output: Path, notices: Path
) -> None:
    with tempfile.TemporaryDirectory(prefix="relux-libssh2-build-") as temporary:
        work = Path(temporary)
        pristine, patched, openssl_source = prepare_sources(
            item, libssh2_archive, openssl_archive, work
        )
        write_notices(item, pristine, openssl_source, notices)
        headers = work / "Headers"
        stage_public_headers(patched, headers)
        xcframework_arguments: list[str] = []

        for slice_ in item["compiler"]["slices"]:
            architecture_archives: list[Path] = []
            for build in slice_["builds"]:
                openssl_install = build_openssl(
                    item, openssl_source, build, work, slice_["sdk"]
                )
                libssh2 = build_libssh2(
                    item, patched, openssl_install, build, work, slice_["sdk"]
                )
                combined = work / (
                    f"libReluxLibSSH2-{slice_['sdk']}-{build['architecture']}.a"
                )
                run(
                    [
                        "xcrun",
                        "--sdk",
                        slice_["sdk"],
                        "libtool",
                        "-static",
                        "-o",
                        str(combined),
                        str(libssh2),
                        str(openssl_install / "lib" / "libcrypto.a"),
                    ],
                    environment=build_environment(),
                )
                architecture_archives.append(combined)

            universal = work / slice_["library_identifier"] / "libReluxLibSSH2.a"
            universal.parent.mkdir()
            if len(architecture_archives) == 1:
                shutil.copy2(architecture_archives[0], universal)
            else:
                run(
                    [
                        "xcrun",
                        "lipo",
                        "-create",
                        *map(str, architecture_archives),
                        "-output",
                        str(universal),
                    ]
                )
            xcframework_arguments.extend(
                ["-library", str(universal), "-headers", str(headers)]
            )

        candidate = work / "ReluxLibSSH2.xcframework"
        run(
            [
                "xcodebuild",
                "-create-xcframework",
                *xcframework_arguments,
                "-output",
                str(candidate),
            ]
        )
        normalize_xcframework(candidate)
        run(
            [
                str(REPOSITORY_ROOT / "scripts" / "native-dependency-tool.py"),
                "inspect",
                "--dependency",
                DEPENDENCY_NAME,
                "--xcframework",
                str(candidate),
            ]
        )
        output = output.resolve()
        if output.suffix != ".xcframework" or output == REPOSITORY_ROOT:
            raise ForkError(f"refusing unsafe XCFramework output path: {output}")
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists():
            shutil.rmtree(output)
        shutil.copytree(candidate, output, copy_function=shutil.copy2)

    print(json.dumps(artifact_hashes(output), indent=2, sort_keys=True))


def verify_xcode_build(item: dict[str, Any]) -> None:
    output = run(["xcodebuild", "-version"], capture=True)
    expected = f"Build version {item['compiler']['xcode_build']}"
    if expected not in output:
        raise ForkError(f"Xcode build mismatch: expected {expected}, got {output.strip()}")


def verify_artifact(item: dict[str, Any]) -> None:
    verify_patch_manifest(item)
    verify_xcode_build(item)
    artifact = REPOSITORY_ROOT / item["integration"]["artifact_path"]
    run(
        [
            str(REPOSITORY_ROOT / "scripts" / "native-dependency-tool.py"),
            "inspect",
            "--dependency",
            DEPENDENCY_NAME,
            "--xcframework",
            str(artifact),
            "--verify-lock",
        ]
    )
    for slice_ in item["compiler"]["slices"]:
        slice_dir = artifact / slice_["library_identifier"]
        archive = slice_dir / "libReluxLibSSH2.a"
        symbols = run(["nm", "-gU", str(archive)], capture=True)
        for symbol in item["integration"]["required_symbols"]:
            if f"_{symbol}" not in symbols.split():
                raise ForkError(f"missing public symbol {symbol} in {archive}")
        headers = slice_dir / "Headers"
        actual_headers = sorted(path.name for path in headers.iterdir() if path.is_file())
        if actual_headers != sorted(item["integration"]["public_headers"]):
            raise ForkError(f"unexpected public headers in {slice_dir}: {actual_headers}")
        public_header = (headers / "libssh2.h").read_text(encoding="utf-8")
        if "LIBSSH2_API int libssh2_session_rekey" not in public_header:
            raise ForkError("XCFramework public header omits libssh2_session_rekey")
        if (headers / "libssh2_priv.h").exists():
            raise ForkError("private libssh2 header leaked into XCFramework")

    notice_path = REPOSITORY_ROOT / item["license"]["notices_output"]
    if not notice_path.is_file():
        raise ForkError(f"missing generated notices: {notice_path}")
    actual_notice_hash = sha256_file(notice_path)
    if actual_notice_hash != item["license"]["notices_sha256"]:
        raise ForkError(
            f"notice hash mismatch: expected {item['license']['notices_sha256']}, "
            f"got {actual_notice_hash}"
        )
    package = (REPOSITORY_ROOT / "Package.swift").read_text(encoding="utf-8")
    if 'name: "ReluxLibSSH2"' not in package or item["integration"]["artifact_path"] not in package:
        raise ForkError("Package.swift does not expose the ReluxLibSSH2 binary target")


def unused_tcp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def assert_rekey_log(log: str) -> None:
    marker = "Entering interactive session for SSH2."
    if marker not in log:
        raise ForkError("sshd log does not contain authenticated session marker")
    post_auth = log.split(marker, 1)[1]
    received = post_auth.find("SSH2_MSG_KEXINIT received")
    sent = post_auth.find("SSH2_MSG_KEXINIT sent")
    if received < 0 or sent < 0 or received > sent:
        raise ForkError("first post-auth rekey was not initiated by the client")
    if "ssh_packet_send2: rekex triggered" not in post_auth:
        raise ForkError("OpenSSH RekeyLimit did not trigger a server-initiated rekey")
    if post_auth.count("SSH2_MSG_NEWKEYS sent") < 2:
        raise ForkError("sshd did not send NEWKEYS for both client and server rekeys")
    if post_auth.count("SSH2_MSG_NEWKEYS received") < 2:
        raise ForkError("sshd did not receive NEWKEYS for both client and server rekeys")
    if post_auth.count("ssh_set_newkeys: rekeying out") < 2:
        raise ForkError("sshd did not install outbound keys for both rekeys")
    if post_auth.count("ssh_set_newkeys: rekeying in") < 2:
        raise ForkError("sshd did not install inbound keys for both rekeys")


def test_rekey(item: dict[str, Any]) -> None:
    verify_artifact(item)
    sshd = Path("/usr/sbin/sshd")
    ssh_keygen = shutil.which("ssh-keygen")
    if not sshd.is_file() or not ssh_keygen:
        raise ForkError("rekey test requires /usr/sbin/sshd and ssh-keygen")

    artifact = REPOSITORY_ROOT / item["integration"]["artifact_path"]
    macos_slice = next(
        slice_ for slice_ in item["compiler"]["slices"] if slice_["platform"] == "macos"
    )
    slice_dir = artifact / macos_slice["library_identifier"]
    username = pwd.getpwuid(os.getuid()).pw_name

    with tempfile.TemporaryDirectory(prefix="relux-libssh2-rekey-test-") as temporary:
        work = Path(temporary)
        client = work / "rekey-test"
        run(
            [
                "clang",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-I",
                str(slice_dir / "Headers"),
                str(FORK_ROOT / "Tests" / "rekey_test.c"),
                str(slice_dir / "libReluxLibSSH2.a"),
                "-framework",
                "Security",
                "-framework",
                "CoreFoundation",
                "-o",
                str(client),
            ]
        )

        host_key = work / "sshd-host-key"
        client_key = work / "client-key"
        run([ssh_keygen, "-q", "-t", "ed25519", "-N", "", "-f", str(host_key)])
        run([ssh_keygen, "-q", "-t", "ed25519", "-N", "", "-f", str(client_key)])
        authorized_keys = work / "authorized_keys"
        shutil.copy2(client_key.with_suffix(".pub"), authorized_keys)
        os.chmod(host_key, 0o600)
        os.chmod(client_key, 0o600)
        os.chmod(authorized_keys, 0o600)

        port = unused_tcp_port()
        config = work / "sshd_config"
        log_path = work / "sshd.log"
        config.write_text(
            "\n".join(
                [
                    f"Port {port}",
                    "ListenAddress 127.0.0.1",
                    "Protocol 2",
                    f"HostKey {host_key}",
                    f"PidFile {work / 'sshd.pid'}",
                    f"AuthorizedKeysFile {authorized_keys}",
                    "StrictModes no",
                    "PasswordAuthentication no",
                    "KbdInteractiveAuthentication no",
                    "PubkeyAuthentication yes",
                    "UsePAM no",
                    "PermitRootLogin no",
                    f"AllowUsers {username}",
                    "RekeyLimit 64K 0",
                    "LogLevel DEBUG3",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        run([str(sshd), "-t", "-f", str(config)])
        server = subprocess.Popen(
            [str(sshd), "-D", "-E", str(log_path), "-f", str(config)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if server.poll() is not None:
                    raise ForkError("test sshd exited before accepting connections")
                if log_path.is_file() and "Server listening" in log_path.read_text(
                    encoding="utf-8", errors="replace"
                ):
                    break
                time.sleep(0.02)
            else:
                raise ForkError("test sshd did not become ready")

            client_result = run(
                [
                    str(client),
                    "127.0.0.1",
                    str(port),
                    username,
                    str(client_key.with_suffix(".pub")),
                    str(client_key),
                ],
                capture=True,
            )
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)

        log = log_path.read_text(encoding="utf-8", errors="replace")
        assert_rekey_log(log)
        if "EAGAIN result(s)" not in client_result:
            raise ForkError("client test did not exercise nonblocking EAGAIN rekey")
        print(client_result.strip())
        print(
            "client-initiated and server-initiated KEX each installed inbound/outbound "
            "NEWKEYS; post-rekey channels succeeded"
        )


def test_source_gates(
    item: dict[str, Any], libssh2_archive: Path, openssl_archive: Path
) -> None:
    with tempfile.TemporaryDirectory(prefix="relux-libssh2-source-gates-") as temporary:
        work = Path(temporary)
        prepare_sources(item, libssh2_archive, openssl_archive, work / "clean")
        for name, archive in (
            ("libssh2", libssh2_archive),
            ("OpenSSL", openssl_archive),
        ):
            tampered = work / f"tampered-{name}.tar.gz"
            shutil.copy2(archive, tampered)
            with tampered.open("ab") as stream:
                stream.write(b"tampered")
            selected_libssh2 = tampered if name == "libssh2" else libssh2_archive
            selected_openssl = tampered if name == "OpenSSL" else openssl_archive
            try:
                prepare_sources(
                    item,
                    selected_libssh2,
                    selected_openssl,
                    work / f"unexpected-{name}",
                )
            except ForkError as error:
                if "checksum mismatch before patching" not in str(error):
                    raise ForkError(
                        f"{name} tamper gate failed for the wrong reason: {error}"
                    ) from error
            else:
                raise ForkError(f"tampered {name} archive passed source verification")
    print("libssh2/OpenSSL tampering fails before extraction or patch application")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("--libssh2-archive", type=Path, required=True)
    prepare.add_argument("--openssl-archive", type=Path, required=True)
    prepare.add_argument("--output", type=Path, required=True)

    build = subparsers.add_parser("build-xcframework")
    build.add_argument("--libssh2-archive", type=Path, required=True)
    build.add_argument("--openssl-archive", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--notices", type=Path)

    notices = subparsers.add_parser("notices")
    notices.add_argument("--libssh2-archive", type=Path, required=True)
    notices.add_argument("--openssl-archive", type=Path, required=True)
    notices.add_argument("--output", type=Path, required=True)

    subparsers.add_parser("verify")
    subparsers.add_parser("test-rekey")

    source_gates = subparsers.add_parser("test-source-gates")
    source_gates.add_argument("--libssh2-archive", type=Path, required=True)
    source_gates.add_argument("--openssl-archive", type=Path, required=True)

    lock = subparsers.add_parser("artifact-lock")
    lock.add_argument("--xcframework", type=Path)
    return result


def main() -> int:
    arguments = parser().parse_args()
    _, item = load_configuration()

    if arguments.command == "prepare":
        output = arguments.output.resolve()
        if output.exists():
            raise ForkError(f"prepare output must not already exist: {output}")
        output.mkdir(parents=True)
        _, patched, openssl = prepare_sources(
            item, arguments.libssh2_archive, arguments.openssl_archive, output
        )
        print(f"prepared patched libssh2 at {patched}")
        print(f"verified OpenSSL source at {openssl}")
    elif arguments.command == "build-xcframework":
        notices = arguments.notices or (
            REPOSITORY_ROOT / item["license"]["notices_output"]
        )
        build_xcframework(
            item,
            arguments.libssh2_archive,
            arguments.openssl_archive,
            arguments.output,
            notices,
        )
    elif arguments.command == "notices":
        with tempfile.TemporaryDirectory(prefix="relux-libssh2-notices-") as temporary:
            pristine, _, openssl = prepare_sources(
                item,
                arguments.libssh2_archive,
                arguments.openssl_archive,
                Path(temporary),
            )
            write_notices(item, pristine, openssl, arguments.output)
        print(f"wrote verified notices to {arguments.output}")
    elif arguments.command == "verify":
        verify_artifact(item)
        print("ReluxLibSSH2 patch, artifact, public API, and notices are verified")
    elif arguments.command == "test-rekey":
        test_rekey(item)
    elif arguments.command == "test-source-gates":
        test_source_gates(item, arguments.libssh2_archive, arguments.openssl_archive)
    elif arguments.command == "artifact-lock":
        path = arguments.xcframework or (
            REPOSITORY_ROOT / item["integration"]["artifact_path"]
        )
        print(json.dumps(artifact_hashes(path), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ForkError as error:
        print(f"libssh2-fork-tool: {error}", file=sys.stderr)
        raise SystemExit(1)
