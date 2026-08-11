import os
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts import ssh_matrix_fixture as fixture
from scripts import ssh_matrix_provider as provider_module


class PartialPrepareCleanupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(
            prefix=f"{fixture.TASK_ID}-partial-prepare-test-"
        )
        self.state_root = Path(self.temporary.name)
        self.provider = provider_module.BuiltinProvider(self.state_root)
        self.original_start_endpoint = self.provider._start_endpoint_supervisor

    def tearDown(self):
        for server_id in fixture.REQUIRED_SERVERS:
            if self.provider._server_dir(server_id).exists():
                with mock.patch.object(
                    self.provider,
                    "_lima_instance_exists",
                    return_value=False,
                ):
                    self.provider._teardown(server_id)
        for pid in list(self.provider._processes):
            self.provider._terminate_owned_process(pid, fixture.TASK_ID)
        self.temporary.cleanup()

    def assert_processes_stopped(self, pids):
        for pid in pids:
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

    def local_endpoint_then_fail(self, server_id, _command_prefix):
        self.original_start_endpoint(server_id, None)
        raise provider_module.ProviderError("injected post-endpoint failure")

    def test_macos_partial_prepare_is_durable_and_teardown_stops_endpoint(self):
        def fake_generate(path, _key_type, _comment):
            path.write_text("private-test-placeholder", encoding="utf-8")
            path.with_suffix(".pub").write_text(
                "ssh-ed25519 public-test-placeholder\n",
                encoding="utf-8",
            )

        with mock.patch.object(self.provider, "_generate_key", side_effect=fake_generate), mock.patch.object(
            self.provider,
            "_start_macos_sshd",
            side_effect=provider_module.ProviderError("injected sshd failure"),
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "injected sshd"):
                self.provider._prepare("macos-current")

        state = self.provider._load_state("macos-current")
        pids = [process["pid"] for process in state["processes"]]
        self.assertEqual(len(pids), 1)
        self.assertEqual(state["phase"], "preparing")
        self.assertEqual(
            self.provider._teardown("macos-current"),
            {"residualResources": 0, "status": "ok"},
        )
        self.assert_processes_stopped(pids)

    def test_linux_partial_prepare_reconciles_endpoint_and_task_vm(self):
        absent = subprocess.CompletedProcess(
            ["limactl", "list"],
            1,
            stdout=b"",
            stderr=b"not found",
        )
        success = subprocess.CompletedProcess([], 0, stdout=b"", stderr=b"")
        original_start = self.provider._start_endpoint_supervisor

        def local_endpoint(server_id, _command_prefix):
            return original_start(server_id, None)

        with mock.patch.object(provider_module.subprocess, "run", return_value=absent), mock.patch.object(
            provider_module,
            "_run",
            return_value=success,
        ), mock.patch.object(
            self.provider,
            "_start_endpoint_supervisor",
            side_effect=local_endpoint,
        ), mock.patch.object(
            self.provider,
            "_install_linux_identity",
            side_effect=provider_module.ProviderError("injected identity failure"),
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "injected identity"):
                self.provider._prepare("linux-current")

        state = self.provider._load_state("linux-current")
        pids = [process["pid"] for process in state["processes"]]
        self.assertEqual(len(pids), 1)
        self.assertTrue(state["limaInstanceOwned"])
        with mock.patch.object(
            self.provider,
            "_lima_instance_exists",
            side_effect=[True, False],
        ), mock.patch.object(provider_module, "_run", return_value=success):
            response = self.provider._teardown("linux-current")
        self.assertEqual(response, {"residualResources": 0, "status": "ok"})
        self.assert_processes_stopped(pids)

    def test_real_host_partial_prepare_teardown_stops_remote_endpoint_session(self):
        with mock.patch.object(
            self.provider,
            "_ssh_config_values",
            return_value={"hostname": "fixture.invalid", "port": "22", "user": "fixture"},
        ), mock.patch.object(
            self.provider,
            "_start_endpoint_supervisor",
            side_effect=self.local_endpoint_then_fail,
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "post-endpoint"):
                self.provider._prepare("relux-real")

        state = self.provider._load_state("relux-real")
        pids = [process["pid"] for process in state["processes"]]
        self.assertEqual(len(pids), 1)
        self.assertEqual(
            self.provider._teardown("relux-real"),
            {"residualResources": 0, "status": "ok"},
        )
        self.assert_processes_stopped(pids)

    def test_lifecycle_attempts_teardown_for_every_prepared_row(self):
        manifest = fixture.load_manifest()
        servers = {server["id"]: server for server in manifest["servers"]}
        teardown_ids = []

        def fake_dispatch(_provider, request):
            server_id = request["serverId"]
            action = request["action"]
            if action == "prepare":
                if server_id == "relux-real":
                    raise provider_module.ProviderError("injected prepare failure")
                return {"status": "ok", "runtime": {}}
            if action == "rotate":
                return {
                    "disposition": "rotated",
                    "runtime": {},
                    "status": "ok",
                }
            if action == "probe":
                server = servers[server_id]
                return {
                    "observation": {
                        "architecture": server["os"]["architecture"],
                        "hostKeyFingerprints": [
                            key["fingerprintSHA256"] for key in server["hostKeys"]
                        ],
                        "opensshVersion": server["opensshVersion"],
                        "osName": server["os"]["name"],
                        "osVersion": server["os"]["version"],
                        "privilege": "non-root",
                        "reachable": True,
                        "userKeyTypes": server["userKeyTypes"],
                    },
                    "status": "ok",
                }
            if action == "teardown":
                teardown_ids.append(server_id)
                if server_id == "relux-real":
                    raise provider_module.ProviderError("injected teardown failure")
                return {"residualResources": 0, "status": "ok"}
            raise AssertionError(action)

        with mock.patch.object(provider_module, "dispatch", side_effect=fake_dispatch):
            with self.assertRaises(provider_module.ProviderError):
                provider_module.run_lifecycle(self.provider)
        self.assertEqual(teardown_ids, list(reversed(sorted(fixture.REQUIRED_SERVERS))))


class LinuxTeardownTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix=f"{fixture.TASK_ID}-teardown-test-")
        self.state_root = Path(self.temporary.name)
        self.provider = provider_module.BuiltinProvider(self.state_root)
        self.provider._save_state(
            "linux-current",
            {"processes": [], "serverId": "linux-current"},
        )

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def completed(arguments, returncode=0, stdout=b""):
        return subprocess.CompletedProcess(arguments, returncode, stdout=stdout, stderr=b"")

    def lima_listing(self, present):
        stdout = b'{"name":"relux-m0-260715-39xz9g"}\n' if present else b""
        return self.completed(["limactl", "list", "--json"], stdout=stdout)

    def assert_state_preserved(self):
        self.assertTrue(self.provider._state_path("linux-current").exists())

    def test_linux_teardown_preserves_state_when_delete_fails(self):
        delete = self.completed(
            ["limactl", "delete", "-f", provider_module.LIMA_INSTANCE],
            returncode=99,
        )
        with mock.patch.object(
            provider_module.subprocess,
            "run",
            side_effect=[self.lima_listing(True), delete],
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "exited 99"):
                self.provider._teardown("linux-current")
        self.assert_state_preserved()

    def test_linux_teardown_preserves_state_when_delete_times_out(self):
        timeout = subprocess.TimeoutExpired(
            ["limactl", "delete", "-f", provider_module.LIMA_INSTANCE],
            timeout=60,
        )
        with mock.patch.object(
            provider_module.subprocess,
            "run",
            side_effect=[self.lima_listing(True), timeout],
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "failed safely"):
                self.provider._teardown("linux-current")
        self.assert_state_preserved()

    def test_linux_teardown_preserves_state_when_instance_remains(self):
        delete = self.completed(
            ["limactl", "delete", "-f", provider_module.LIMA_INSTANCE]
        )
        with mock.patch.object(
            provider_module.subprocess,
            "run",
            side_effect=[self.lima_listing(True), delete, self.lima_listing(True)],
        ):
            with self.assertRaisesRegex(provider_module.ProviderError, "remains after delete"):
                self.provider._teardown("linux-current")
        self.assert_state_preserved()

    def test_linux_teardown_removes_state_after_confirmed_absence(self):
        delete = self.completed(
            ["limactl", "delete", "-f", provider_module.LIMA_INSTANCE]
        )
        with mock.patch.object(
            provider_module.subprocess,
            "run",
            side_effect=[self.lima_listing(True), delete, self.lima_listing(False)],
        ):
            response = self.provider._teardown("linux-current")
        self.assertEqual(response, {"residualResources": 0, "status": "ok"})
        self.assertFalse(self.provider._server_dir("linux-current").exists())


@unittest.skipUnless(
    platform.system() == "Darwin" and Path("/usr/sbin/sshd").exists(),
    "requires the supported macOS OpenSSH fixture platform",
)
class MacOSProviderIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix=f"{fixture.TASK_ID}-provider-test-")
        self.state_root = Path(self.temporary.name)
        self.provider = provider_module.BuiltinProvider(self.state_root)
        self.prepared = set()

    def tearDown(self):
        for server_id in list(self.prepared):
            response = self.request(server_id, "teardown")
            self.assertEqual(response, {"residualResources": 0, "status": "ok"})
        self.temporary.cleanup()

    def request(self, server_id, action, **values):
        response = provider_module.dispatch(
            self.provider,
            {
                "protocol": "relux-ssh-matrix-provider-v1",
                "serverId": server_id,
                "action": action,
                **values,
            },
        )
        if action == "prepare":
            self.prepared.add(server_id)
        elif action == "teardown":
            self.prepared.discard(server_id)
        return response

    @staticmethod
    def identity_path(runtime):
        return Path(runtime["identityReference"].removeprefix("ephemeral-file://"))

    def ssh_arguments(self, runtime, *, known_hosts="/dev/null", strict="no"):
        return [
            "/usr/bin/ssh",
            "-F",
            "/dev/null",
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            f"StrictHostKeyChecking={strict}",
            "-o",
            f"UserKnownHostsFile={known_hosts}",
            "-i",
            str(self.identity_path(runtime)),
            "-p",
            str(runtime["port"]),
        ]

    def run_ssh(self, runtime, command="true", **options):
        return subprocess.run(
            [
                *self.ssh_arguments(runtime, **options),
                f"{runtime['account']}@{runtime['host']}",
                command,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
        )

    def test_current_profile_produces_negative_branches_and_rotates_identity(self):
        server_id = "macos-current"
        initial = self.request(server_id, "prepare")["runtime"]
        self.assertEqual(self.run_ssh(initial).returncode, 0)

        initial_key = self.identity_path(initial)
        rotated = self.request(server_id, "rotate")
        self.assertEqual(rotated["disposition"], "rotated")
        runtime = rotated["runtime"]
        self.assertFalse(initial_key.exists())
        self.assertEqual(self.run_ssh(runtime).returncode, 0)

        first_use = self.request(
            server_id, "control", scenarioId="host-key-first-use"
        )
        self.assertEqual(
            first_use["fixtureEvidenceCode"],
            fixture.SCENARIO_FIXTURE_EVIDENCE["host-key-first-use"],
        )
        empty_known_hosts = first_use["runtime"]["scenarioControl"][
            "knownHostsReference"
        ].removeprefix("ephemeral-file://")
        self.assertNotEqual(
            self.run_ssh(runtime, known_hosts=empty_known_hosts, strict="yes").returncode,
            0,
        )

        scan = subprocess.run(
            [
                "/usr/bin/ssh-keyscan",
                "-T",
                "5",
                "-p",
                str(runtime["port"]),
                runtime["host"],
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=True,
        )
        pinned = self.state_root / "pinned-known-hosts"
        pinned.write_bytes(scan.stdout)
        changed = self.request(server_id, "control", scenarioId="host-key-change")
        self.assertEqual(
            changed["fixtureEvidenceCode"],
            fixture.SCENARIO_FIXTURE_EVIDENCE["host-key-change"],
        )
        self.assertNotEqual(
            self.run_ssh(runtime, known_hosts=str(pinned), strict="yes").returncode,
            0,
        )

        rejected = self.request(server_id, "control", scenarioId="auth-rejection")
        self.assertNotEqual(self.run_ssh(rejected["runtime"]).returncode, 0)

        channel = self.request(server_id, "control", scenarioId="channel-rejection")
        destination = channel["runtime"]["scenarioControl"]["rejectedDestination"]
        channel_result = subprocess.run(
            [
                *self.ssh_arguments(channel["runtime"]),
                "-W",
                f"{destination['host']}:{destination['port']}",
                f"{runtime['account']}@{runtime['host']}",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
        )
        self.assertNotEqual(channel_result.returncode, 0)
        self.assertIn(b"open failed", channel_result.stderr)

        probe = self.request(server_id, "probe")
        self.assertTrue(probe["observation"]["reachable"])
        self.assertEqual(probe["observation"]["privilege"], "non-root")

    def test_fallback_profile_rekeys_during_byte_exact_stream(self):
        server_id = "macos-approved-older-profile"
        self.request(server_id, "prepare")
        runtime = self.request(server_id, "rotate")["runtime"]
        control = self.request(server_id, "control", scenarioId="server-rekey")
        self.assertEqual(control["runtime"]["scenarioControl"]["rekeyLimitBytes"], 32768)

        payload = bytes(range(256)) * 512
        completed = subprocess.run(
            [
                *self.ssh_arguments(runtime),
                "-vv",
                f"{runtime['account']}@{runtime['host']}",
                "python3 -c 'import shutil,sys; shutil.copyfileobj(sys.stdin.buffer,sys.stdout.buffer)'",
            ],
            input=payload,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=15,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr.decode(errors="replace"))
        self.assertEqual(completed.stdout, payload)
        self.assertIn(b"rekeying in progress", completed.stderr)

    def test_teardown_removes_state_and_owned_processes(self):
        server_id = "macos-current"
        self.request(server_id, "prepare")
        state = self.provider._load_state(server_id)
        pids = [process["pid"] for process in state["processes"]]

        response = self.request(server_id, "teardown")

        self.assertEqual(response["residualResources"], 0)
        self.assertFalse((self.state_root / server_id).exists())
        for pid in pids:
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)


if __name__ == "__main__":
    unittest.main()
