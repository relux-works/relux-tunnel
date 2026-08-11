import copy
import hashlib
import io
import json
import shlex
import socket
import sys
import threading
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout

from scripts import ssh_matrix_fixture as fixture


class ManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = fixture.load_manifest()

    def test_manifest_covers_complete_server_and_scenario_matrices(self):
        fixture.validate_manifest(self.manifest)
        self.assertEqual(
            {server["id"] for server in self.manifest["servers"]}, fixture.REQUIRED_SERVERS
        )
        self.assertEqual(
            {scenario["id"] for scenario in self.manifest["scenarios"]},
            fixture.REQUIRED_SCENARIOS,
        )

    def test_every_server_is_reachable_non_root_and_secret_reference_only(self):
        for server in self.manifest["servers"]:
            with self.subTest(server=server["id"]):
                self.assertEqual(server["reachability"], "verified")
                self.assertEqual(server["identity"]["privilege"], "non-root")
                self.assertNotIn("credential", json.dumps(server).lower())

    def test_manifest_rejects_missing_branch(self):
        changed = copy.deepcopy(self.manifest)
        changed["scenarios"].pop()
        with self.assertRaisesRegex(fixture.FixtureError, "matrix mismatch"):
            fixture.validate_manifest(changed)

    def test_manifest_rejects_embedded_secret(self):
        changed = copy.deepcopy(self.manifest)
        changed["teardown"]["evidence"] = "-----BEGIN OPENSSH PRIVATE KEY-----"
        with self.assertRaisesRegex(fixture.FixtureError, "forbidden secret"):
            fixture.validate_manifest(changed)

    def test_manifest_rejects_non_fingerprint_identity_values(self):
        invalid_fingerprints = (
            "SHA256:private-host.example/user/alice",
            "SHA256:alice",
            "SHA256:/Users/alice/.ssh/id_ed25519",
            "SHA256:192.0.2.10",
            "SHA256:credential-reference-private",
        )
        for fingerprint in invalid_fingerprints:
            with self.subTest(fingerprint=fingerprint):
                changed = copy.deepcopy(self.manifest)
                changed["servers"][0]["hostKeys"][0]["fingerprintSHA256"] = fingerprint
                with self.assertRaisesRegex(fixture.FixtureError, "host-key fingerprint"):
                    fixture.validate_manifest(changed)

    def test_manifest_rejects_root_or_unverified_identity(self):
        changed = copy.deepcopy(self.manifest)
        changed["servers"][0]["identity"]["privilege"] = "root"
        with self.assertRaisesRegex(fixture.FixtureError, "non-root"):
            fixture.validate_manifest(changed)


class TrafficTests(unittest.TestCase):
    def test_streaming_source_and_sink_agree_without_payload_fixture(self):
        total = fixture.DEFAULT_BLOCK_BYTES * 2 + 137
        output = io.BytesIO()
        written, digest = fixture.stream_source(output, total, "matrix-seed")
        self.assertEqual(written, total)
        self.assertEqual(digest, fixture.expected_stream_hash(total, "matrix-seed"))
        self.assertEqual(fixture.stream_sink(io.BytesIO(output.getvalue()), total, digest), (total, digest))

    def test_five_gib_hash_is_pinned_in_manifest(self):
        manifest = fixture.load_manifest()
        traffic = manifest["traffic"]
        self.assertGreaterEqual(traffic["bytes"], fixture.FIVE_GIB)
        self.assertEqual(
            fixture.expected_stream_hash(traffic["bytes"], traffic["seed"]),
            traffic["expectedSHA256"],
        )

    def test_sink_rejects_wrong_count_hash_and_overflow(self):
        good = b"bounded"
        digest = f"SHA256:{hashlib.sha256(good).hexdigest()}"
        with self.assertRaisesRegex(fixture.FixtureError, "sink mismatch"):
            fixture.stream_sink(io.BytesIO(good[:-1]), len(good), digest)
        with self.assertRaisesRegex(fixture.FixtureError, "sink mismatch"):
            fixture.stream_sink(io.BytesIO(good), len(good), "SHA256:" + "0" * 64)
        with self.assertRaisesRegex(fixture.FixtureError, "more bytes"):
            fixture.stream_sink(io.BytesIO(good + b"!"), len(good), digest, read_bytes=1)


class EndpointTests(unittest.TestCase):
    def run_endpoint(self, mode, writes=b"payload", half_close=True):
        client, server = socket.socketpair()
        result = []

        def serve():
            try:
                result.append(fixture.serve_endpoint(server, mode))
            finally:
                server.close()

        thread = threading.Thread(target=serve)
        thread.start()
        try:
            if writes:
                try:
                    client.sendall(writes)
                except (BrokenPipeError, ConnectionResetError):
                    pass
            if half_close:
                try:
                    client.shutdown(socket.SHUT_WR)
                except OSError:
                    pass
            received = bytearray()
            while True:
                try:
                    chunk = client.recv(1024)
                except ConnectionResetError:
                    break
                if not chunk:
                    break
                received.extend(chunk)
        finally:
            client.close()
            thread.join(timeout=2)
        self.assertFalse(thread.is_alive())
        return bytes(received), result[0]

    def test_echo_and_sink(self):
        echoed, result = self.run_endpoint("echo")
        self.assertEqual(echoed, b"payload")
        self.assertEqual(result.received_bytes, 7)
        sunk, sink_result = self.run_endpoint("sink")
        self.assertEqual(sunk, b"")
        self.assertEqual(sink_result.received_bytes, 7)

    def test_early_close_and_reset(self):
        early, early_result = self.run_endpoint("early-close")
        self.assertEqual(early, b"")
        self.assertEqual(early_result.received_bytes, 0)
        reset, reset_result = self.run_endpoint("reset")
        self.assertEqual(reset, b"")
        self.assertEqual(reset_result.received_bytes, 0)

    def test_half_close_echoes_once_then_drains(self):
        echoed, result = self.run_endpoint("half-close")
        self.assertEqual(echoed, b"payload")
        self.assertEqual(result.received_bytes, 7)

    def test_disconnect_closes_after_first_read(self):
        received, result = self.run_endpoint("disconnect")
        self.assertEqual(received, b"")
        self.assertEqual(result.received_bytes, 7)

    def test_loss_control_is_deterministic(self):
        self.assertEqual(list(fixture.deterministic_drop_indexes(25, 10)), [10, 20])

    def test_latency_control_uses_exact_duration(self):
        observed = []
        fixture.apply_latency(75, observed.append)
        self.assertEqual(observed, [0.075])

    def test_real_loopback_listener_and_latency_proxy_exercise_the_tcp_path(self):
        endpoint = fixture.EndpointListener("echo")
        proxy = fixture.TCPImpairmentProxy(
            endpoint.host,
            endpoint.port,
            latency_milliseconds=75,
        )
        try:
            started = time.monotonic()
            with socket.create_connection((proxy.host, proxy.port), timeout=2) as client:
                client.sendall(b"through-proxy")
                client.shutdown(socket.SHUT_WR)
                self.assertEqual(client.recv(64), b"through-proxy")
            self.assertGreaterEqual(time.monotonic() - started, 0.14)
        finally:
            proxy.stop()
            endpoint.stop()

    def test_real_loss_proxy_drops_every_tenth_connection(self):
        endpoint = fixture.EndpointListener("echo")
        proxy = fixture.TCPImpairmentProxy(
            endpoint.host,
            endpoint.port,
            deterministic_drop_every=10,
        )
        try:
            for ordinal in range(1, 11):
                if ordinal < 10:
                    with socket.create_connection((proxy.host, proxy.port), timeout=2) as client:
                        client.sendall(b"x")
                        client.shutdown(socket.SHUT_WR)
                        self.assertEqual(client.recv(1), b"x")
                else:
                    with self.assertRaises((BrokenPipeError, ConnectionResetError, OSError)):
                        with socket.create_connection(
                            (proxy.host, proxy.port), timeout=2
                        ) as client:
                            client.sendall(b"x")
                            client.recv(1)
            deadline = time.monotonic() + 1
            while not proxy.dropped_connections and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertEqual(proxy.dropped_connections, [10])
        finally:
            proxy.stop()
            endpoint.stop()


class StdioFixtureTests(unittest.TestCase):
    def test_long_lived_echo_and_sink_stream_without_retention(self):
        payload = b"first-frame\x00second-frame"
        echoed = io.BytesIO()
        echo_result = fixture.echo_stream(io.BytesIO(payload), echoed, read_bytes=3)
        sink_result = fixture.consume_stream(io.BytesIO(payload), read_bytes=5)
        expected = f"SHA256:{hashlib.sha256(payload).hexdigest()}"
        self.assertEqual(echoed.getvalue(), payload)
        self.assertEqual(echo_result, fixture.EndpointResult(len(payload), expected))
        self.assertEqual(sink_result, fixture.EndpointResult(len(payload), expected))

    def test_stream_fixtures_reject_invalid_read_size(self):
        with self.assertRaisesRegex(fixture.FixtureError, "read size"):
            fixture.echo_stream(io.BytesIO(), io.BytesIO(), 0)
        with self.assertRaisesRegex(fixture.FixtureError, "read size"):
            fixture.consume_stream(io.BytesIO(), 0)


class RecordingMatrixInvoker:
    def __init__(self, manifest, fixture_set):
        self.servers = {server["id"]: server for server in manifest["servers"]}
        self.fixture_set = fixture_set
        self.upstream = fixture_set.listeners["echo"]
        self.calls = []
        self.fail_scenario = None
        self.malformed_prepare = None
        self.rotation_disposition = {}
        self.observation_code = {}

    def __call__(self, reference, request):
        self.calls.append((reference, request))
        if request["protocol"] == "relux-ssh-matrix-provider-v1":
            return self._provider(request)
        return self._driver(request)

    def _runtime(self, server_id):
        return {
            "host": self.upstream.host,
            "port": self.upstream.port,
            "identityReference": f"external-test-store://{server_id}/private",
            "destinationEndpoints": self.fixture_set.public_addresses(),
            "sensitiveUser": "must-not-be-recorded",
        }

    def _provider(self, request):
        server_id = request["serverId"]
        action = request["action"]
        if action == "prepare":
            if server_id == self.malformed_prepare:
                return {"status": "ok", "runtime": {}}
            return {"status": "ok", "runtime": self._runtime(server_id)}
        if action == "rotate":
            disposition = self.rotation_disposition.get(
                server_id,
                "external-owner-managed" if server_id == "relux-real" else "rotated",
            )
            return {
                "status": "ok",
                "disposition": disposition,
                "runtime": self._runtime(server_id),
            }
        if action == "control":
            scenario = request["scenarioId"]
            return {
                "status": "ok",
                "scenarioId": scenario,
                "fixtureEvidenceCode": fixture.SCENARIO_FIXTURE_EVIDENCE[scenario],
                "runtime": self._runtime(server_id),
            }
        if action == "probe":
            server = self.servers[server_id]
            return {
                "status": "ok",
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
            }
        if action == "teardown":
            return {"status": "ok", "residualResources": 0}
        raise AssertionError(action)

    def _driver(self, request):
        scenario = request["scenarioId"]
        if scenario == self.fail_scenario:
            return {"status": "fail", "scenarioId": scenario}
        self._exercise_scenario(request)
        return {
            "status": "pass",
            "scenarioId": scenario,
            "observationCode": self.observation_code.get(
                scenario, fixture.PUBLIC_OBSERVATION_CODES[scenario]
            ),
        }

    def _exercise_scenario(self, request):
        scenario = request["scenarioId"]
        if scenario == "latency":
            started = time.monotonic()
            self._assert_echo(request["sshEndpoint"], b"latency")
            if time.monotonic() - started < 0.14:
                raise AssertionError("latency proxy did not affect the exercised SSH path")
        elif scenario == "loss":
            failures = 0
            for _ in range(10):
                try:
                    self._assert_echo(request["sshEndpoint"], b"loss")
                except (AssertionError, BrokenPipeError, ConnectionResetError, OSError):
                    failures += 1
            if failures != 1:
                raise AssertionError(f"expected one deterministic loss, got {failures}")
        elif scenario in {"success", "early-close", "half-close", "reset", "disconnect"}:
            endpoint_name = "echo" if scenario == "success" else scenario
            address = request["destinationEndpoints"][endpoint_name]
            try:
                with socket.create_connection((address["host"], address["port"]), timeout=2) as client:
                    client.sendall(b"fixture")
                    client.shutdown(socket.SHUT_WR)
                    observed = client.recv(64)
                if scenario in {"success", "half-close"} and observed != b"fixture":
                    raise AssertionError(f"{scenario} did not echo deterministically")
            except (BrokenPipeError, ConnectionResetError):
                if scenario not in {"reset", "disconnect"}:
                    raise
            if scenario == "success":
                sink = request["destinationEndpoints"]["sink"]
                with socket.create_connection((sink["host"], sink["port"]), timeout=2) as client:
                    client.sendall(b"fixture")
                    client.shutdown(socket.SHUT_WR)
                    if client.recv(1) != b"":
                        raise AssertionError("sink unexpectedly retained or returned payload")

    @staticmethod
    def _assert_echo(address, payload):
        with socket.create_connection((address["host"], address["port"]), timeout=2) as client:
            client.sendall(payload)
            client.shutdown(socket.SHUT_WR)
            if client.recv(len(payload)) != payload:
                raise AssertionError("proxy path was not byte exact")


class OrchestrationTests(unittest.TestCase):
    def setUp(self):
        self.manifest = fixture.load_manifest()
        self.fixture_set = fixture.EndpointFixtureSet()

    def tearDown(self):
        self.fixture_set.stop()

    def test_orchestration_covers_every_server_scenario_and_candidate(self):
        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        report = fixture.run_orchestration(self.manifest, invoker)

        self.assertEqual(report["candidates"], list(fixture.REQUIRED_CANDIDATES))
        expected_cases = len(fixture.REQUIRED_CANDIDATES) * (
            len(fixture.REQUIRED_SERVERS) + len(fixture.REQUIRED_SCENARIOS) - 1
        )
        self.assertEqual(len(report["matrixObservations"]), expected_cases)
        for candidate in fixture.REQUIRED_CANDIDATES:
            observed = {
                row["scenarioId"]
                for row in report["matrixObservations"]
                if row["candidateId"] == candidate
            }
            self.assertEqual(observed, fixture.REQUIRED_SCENARIOS)
            success_servers = {
                row["serverId"]
                for row in report["matrixObservations"]
                if row["candidateId"] == candidate and row["scenarioId"] == "success"
            }
            self.assertEqual(success_servers, fixture.REQUIRED_SERVERS)

        encoded = fixture.canonical_json(report).decode()
        self.assertNotIn("must-not-be-recorded", encoded)
        self.assertNotIn("external-test-store", encoded)
        self.assertTrue(
            all(
                lifecycle["teardown"] == "observed-zero-residual"
                for lifecycle in report["lifecycleObservations"]
            )
        )
        controlled = {
            request["scenarioId"]
            for _, request in invoker.calls
            if request.get("action") == "control"
        }
        self.assertEqual(controlled, fixture.REQUIRED_SCENARIOS - {"success"})

    def test_rotation_disposition_is_exact_for_fixture_ownership(self):
        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        invoker.rotation_disposition["linux-current"] = "external-owner-managed"
        with self.assertRaisesRegex(fixture.FixtureError, "rotation disposition"):
            fixture.run_orchestration(self.manifest, invoker)

        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        invoker.rotation_disposition["relux-real"] = "rotated"
        with self.assertRaisesRegex(fixture.FixtureError, "rotation disposition"):
            fixture.run_orchestration(self.manifest, invoker)

    def test_observation_codes_are_finite_and_privacy_safe(self):
        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        invoker.observation_code["success"] = "success:private-host.example/user/alice"
        with self.assertRaisesRegex(fixture.FixtureError, "invalid observation code"):
            fixture.run_orchestration(self.manifest, invoker)

    def test_orchestration_failure_still_tears_down_every_prepared_server(self):
        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        invoker.fail_scenario = "auth-rejection"
        with self.assertRaisesRegex(fixture.FixtureError, "did not return an observed pass"):
            fixture.run_orchestration(self.manifest, invoker)
        teardown_ids = {
            request["serverId"]
            for _, request in invoker.calls
            if request.get("action") == "teardown"
        }
        self.assertEqual(teardown_ids, fixture.REQUIRED_SERVERS)

    def test_malformed_prepare_is_still_registered_for_teardown(self):
        invoker = RecordingMatrixInvoker(self.manifest, self.fixture_set)
        invoker.malformed_prepare = "linux-current"
        with self.assertRaisesRegex(fixture.FixtureError, "runtime host is missing"):
            fixture.run_orchestration(self.manifest, invoker)
        teardown_ids = [
            request["serverId"]
            for _, request in invoker.calls
            if request.get("action") == "teardown"
        ]
        self.assertEqual(teardown_ids, ["linux-current"])

    def test_provider_observation_fails_closed_on_private_or_incomplete_fields(self):
        server = self.manifest["servers"][0]
        observation = RecordingMatrixInvoker(self.manifest, self.fixture_set)._provider(
            {"serverId": server["id"], "action": "probe"}
        )
        observation["observation"]["username"] = "private"
        with self.assertRaisesRegex(fixture.FixtureError, "invalid public observation"):
            fixture._validate_public_observation(server, observation)

    def test_provider_observation_rejects_non_fingerprint_identity_values(self):
        server = self.manifest["servers"][0]
        invalid_fingerprints = (
            "SHA256:private-host.example/user/alice",
            "SHA256:alice",
            "SHA256:/Users/alice/.ssh/id_ed25519",
            "SHA256:192.0.2.10",
            "SHA256:credential-reference-private",
        )
        for fingerprint in invalid_fingerprints:
            with self.subTest(fingerprint=fingerprint):
                observation = RecordingMatrixInvoker(
                    self.manifest, self.fixture_set
                )._provider({"serverId": server["id"], "action": "probe"})
                observation["observation"]["hostKeyFingerprints"] = [fingerprint]
                with self.assertRaisesRegex(fixture.FixtureError, "host-key fingerprint"):
                    fixture._validate_public_observation(server, observation)

    def test_command_references_are_external_and_fail_closed(self):
        self.assertEqual(
            fixture.command_environment_name("command-env://RELUX_TEST_DRIVER"),
            "RELUX_TEST_DRIVER",
        )
        with self.assertRaisesRegex(fixture.FixtureError, "invalid environment"):
            fixture.command_environment_name("command-env://bad-name")
        with self.assertRaisesRegex(fixture.FixtureError, "unavailable"):
            fixture.EnvironmentCommandInvoker({})(
                "command-env://RELUX_TEST_DRIVER", {"safe": True}
            )

    def test_environment_command_invoker_uses_json_protocol(self):
        program = (
            "import json,sys; request=json.load(sys.stdin); "
            "print(json.dumps({'received': request['safe']}))"
        )
        command = f"{shlex.quote(sys.executable)} -c {shlex.quote(program)}"
        invoker = fixture.EnvironmentCommandInvoker({"RELUX_TEST_DRIVER": command})
        self.assertEqual(
            invoker("command-env://RELUX_TEST_DRIVER", {"safe": "public"}),
            {"received": "public"},
        )

    def test_environment_command_invoker_redacts_failure_output(self):
        program = "import sys; print('private-host', file=sys.stderr); raise SystemExit(7)"
        command = f"{shlex.quote(sys.executable)} -c {shlex.quote(program)}"
        invoker = fixture.EnvironmentCommandInvoker({"RELUX_TEST_DRIVER": command})
        with self.assertRaisesRegex(fixture.FixtureError, "exited 7; output redacted") as raised:
            invoker("command-env://RELUX_TEST_DRIVER", {"safe": True})
        self.assertNotIn("private-host", str(raised.exception))


class CLITests(unittest.TestCase):
    def test_verify_and_hash_commands(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(fixture.main(["verify-manifest"]), 0)
            self.assertEqual(
                fixture.main(
                    [
                        "traffic-hash",
                        "--bytes",
                        "7",
                        "--seed",
                        "cli-seed",
                        "--block-bytes",
                        "32",
                    ]
                ),
                0,
            )
        self.assertIn("fixture manifest OK", output.getvalue())
        self.assertIn("SHA256:", output.getvalue())

    def test_orchestration_preflight_lists_references_without_values(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(fixture.main(["orchestration-preflight"]), 0)
        preflight = json.loads(output.getvalue())
        self.assertEqual(preflight["taskId"], fixture.TASK_ID)
        self.assertFalse(preflight["secretValuesRecorded"])
        self.assertEqual(
            set(preflight["candidateDrivers"]), set(fixture.REQUIRED_CANDIDATES)
        )

    def test_cli_reports_fixture_errors(self):
        errors = io.StringIO()
        with redirect_stderr(errors):
            self.assertEqual(fixture.main(["traffic-hash", "--bytes", "-1"]), 1)
        self.assertIn("cannot be negative", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
