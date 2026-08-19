from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from scripts import relay_supply_chain as supply_chain


class RelaySupplyChainTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = supply_chain.load_json(supply_chain.SOURCE_PATH)

    @staticmethod
    def component(config: dict, identifier: str) -> dict:
        return next(item for item in config["components"] if item["id"] == identifier)

    @staticmethod
    def make_runtime_root(root: Path) -> None:
        for relative in supply_chain.APPROVED_RUNTIME_POLICY["scanRoots"]:
            (root / relative).mkdir(parents=True)

    def test_checked_in_metadata_passes_clean_audit(self) -> None:
        supply_chain.audit()

    def test_every_byte_affecting_dependency_requires_approved_metadata(self) -> None:
        for field in (
            "revision",
            "contentSHA256",
            "license",
            "licenseTextPath",
            "licenseTextSHA256",
            "noticeObligation",
        ):
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                del config["components"][0][field]
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "dependency lacks approved metadata"
                ):
                    supply_chain.validate_config(config)

    def test_every_component_is_bound_to_authoritative_provenance(self) -> None:
        cases = (
            ("relux-relay-source", "revision", "0" * 40),
            ("relux-relay-source", "contentSHA256", "0" * 64),
            ("relay-build-recipe", "revision", "0" * 40),
            ("relay-build-recipe", "contentSHA256", "0" * 64),
            ("go-compiler-linker", "version", "go1.26.4"),
            ("go-compiler-linker", "revision", "go1.26.4"),
            ("go-compiler-linker", "contentSHA256", "0" * 64),
            ("go-standard-library", "version", "go1.26.4"),
            ("go-standard-library", "revision", "go1.26.4"),
            ("go-standard-library", "contentSHA256", "0" * 64),
        )
        for identifier, field, value in cases:
            with self.subTest(identifier=identifier, field=field):
                config = copy.deepcopy(self.config)
                self.component(config, identifier)[field] = value
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "authoritative provenance"
                ):
                    supply_chain.validate_config(config)

    def test_dependency_sources_use_strict_pinned_allowlists(self) -> None:
        cases = (
            "https://github.com/relux-works/relux-tunnel/tree/main",
            "https://github.com/relux-works/relux-tunnel/tree/v0.1.0",
            "https://github.com/relux-works/relux-tunnel/tree/latest",
            "https://github.com/relux-works/relux-tunnel/tree/4326036a26a515d5d349e669574323d4d1c7259c?download=1",
            "https://github.com/relux-works/relux-tunnel/tree/4326036a26a515d5d349e669574323d4d1c7259c#files",
            "https://github.com/relux-works/relux-tunnel/tree/${REVISION}",
            "http://github.com/relux-works/relux-tunnel/tree/4326036a26a515d5d349e669574323d4d1c7259c",
            "https://example.test/relux-tunnel/tree/4326036a26a515d5d349e669574323d4d1c7259c",
            "https://github.com/relux-works/relux-tunnel/tree/4326036a26a515d5d349e669574323d4d1c7259c/",
        )
        for source in cases:
            with self.subTest(source=source):
                config = copy.deepcopy(self.config)
                config["build"]["recipeSource"] = source
                self.component(config, "relay-build-recipe")["source"] = source
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "immutable pinned allowlist"
                ):
                    supply_chain.validate_config(config)

    def test_component_source_cannot_diverge_from_pinned_authority(self) -> None:
        cases = (
            (
                "relux-relay-source",
                "https://github.com/relux-works/relux-tunnel/tree/main/relay",
            ),
            ("go-compiler-linker", "https://go.dev/dl/go1.26.5.darwin-amd64.tar.gz"),
            ("go-standard-library", "https://go.dev/dl/go1.26.5.src.tar.gz"),
        )
        for identifier, source in cases:
            with self.subTest(identifier=identifier):
                config = copy.deepcopy(self.config)
                self.component(config, identifier)["source"] = source
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "immutable pinned allowlist"
                ):
                    supply_chain.validate_config(config)

    def test_relay_source_url_cannot_be_mutated_with_component_in_lockstep(
        self,
    ) -> None:
        cases = (
            "https://github.com/relux-works/relux-tunnel/tree/main/relay",
            "https://github.com/relux-works/relux-tunnel/tree/v0.1.0/relay",
            "https://github.com/relux-works/relux-tunnel/tree/latest/relay",
            "https://github.com/relux-works/relux-tunnel/tree/58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096/relay?download=1",
            "https://github.com/relux-works/relux-tunnel/tree/58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096/relay#source",
            "https://example.test/relux-tunnel/tree/58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096/relay",
        )
        for source in cases:
            with self.subTest(source=source):
                config = copy.deepcopy(self.config)
                config["source"]["repository"] = source
                self.component(config, "relux-relay-source")["source"] = source
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "immutable pinned allowlist"
                ):
                    supply_chain.validate_config(config)

    def test_approved_license_mapping_is_exact(self) -> None:
        cases = (
            ("relux-relay-source", {"license": "GPL-3.0-only"}),
            (
                "relux-relay-source",
                {
                    "license": "BSD-3-Clause",
                    "licenseTextPath": "relay/licenses/Go-BSD-3-Clause.txt",
                    "licenseTextSHA256": "911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad",
                },
            ),
            (
                "go-standard-library",
                {
                    "license": "MIT",
                    "licenseTextPath": "LICENSE",
                    "licenseTextSHA256": "b50c3ae8807afbaf21a331e3c91cf026c611b325c48a3b0bafc57856b48cc2b3",
                },
            ),
            (
                "relux-relay-source",
                {
                    "noticeObligation": "none-build-only-tool",
                    "distribution": "build-only",
                },
            ),
            ("relay-build-recipe", {"noticeObligation": "include-full-license"}),
        )
        for identifier, mutation in cases:
            with self.subTest(identifier=identifier, mutation=mutation):
                config = copy.deepcopy(self.config)
                self.component(config, identifier).update(mutation)
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "approved license mapping"
                ):
                    supply_chain.validate_config(config)

    def test_distributed_dependency_without_notice_coverage_is_rejected(self) -> None:
        config = copy.deepcopy(self.config)
        component = next(
            item for item in config["components"] if item["id"] == "go-standard-library"
        )
        component["noticeObligation"] = "none-build-only-tool"
        with self.assertRaisesRegex(
            supply_chain.SupplyChainError, "lacks notice coverage"
        ):
            supply_chain.validate_config(config)

    def test_inventory_and_provenance_are_bound_to_same_exact_manifest(self) -> None:
        inventory = json.loads(supply_chain.render_inventory(self.config))
        provenance = json.loads(supply_chain.render_provenance(self.config))
        linkage = supply_chain.linkage_id(self.config)
        self.assertEqual(inventory["manifestLinkageSHA256"], linkage)
        byproducts = provenance["predicate"]["runDetails"]["byproducts"]
        self.assertEqual(byproducts[1]["digest"]["sha256"], linkage)
        self.assertEqual(
            provenance["predicate"]["artifactManifest"]["archiveSHA256"],
            self.config["artifactManifest"]["archiveSHA256"],
        )

    def test_product_notice_input_covers_relay_and_linked_standard_library(
        self,
    ) -> None:
        notices = supply_chain.render_notices(self.config).decode("utf-8")
        self.assertIn("Relux Tunnel relay source", notices)
        self.assertIn("Go standard library", notices)
        self.assertIn("MIT License", notices)
        self.assertIn("Copyright 2009 The Go Authors", notices)

    def test_runtime_code_download_surface_fails_closed(self) -> None:
        cases = (
            (
                "Downloader.swift",
                "let task = URLSession.shared.dataTask(with: request)\n",
                "Foundation network loader",
            ),
            (
                "Downloader.swift",
                "let data = try Data(contentsOf: remoteURL)\n",
                "Foundation Data URL loader",
            ),
            (
                "Downloader.swift",
                "let connection = NSURLConnection(request: request, delegate: nil)\n",
                "Foundation network loader",
            ),
            (
                "Downloader.swift",
                "let text = try String /* split */ ( /* split */ contentsOf /* split */ : remoteURL)\n",
                "Foundation String URL loader",
            ),
            (
                "Downloader.swift",
                "let process = Process()\n",
                "Swift process execution",
            ),
            (
                "Downloader.swift",
                'let shell = "/bin/sh -c curl example.test/code"\n',
                "shell or download command",
            ),
            (
                "Downloader.m",
                "+ (NSData *)load:(NSURL *)url { return [NSData dataWithContentsOfURL /* split */ :url]; }\n",
                "Objective-C NSData URL loader",
            ),
            (
                "downloader.c",
                "void load(void) { curl_easy_init(); }\n",
                "C/C++ libcurl use",
            ),
            (
                "downloader.cpp",
                "void load() { curl_easy_perform /* split */ (handle); }\n",
                "C/C++ libcurl use",
            ),
            (
                "downloader.c",
                "int run(char *command) { return system(command); }\n",
                "C-family process execution",
            ),
            (
                "downloader.h",
                'FILE *run(const char *command) { return popen /* split */ (command, "r"); }\n',
                "C-family process execution",
            ),
            (
                "downloader.cc",
                "int run() { return posix_spawn(&pid, path, 0, 0, argv, envp); }\n",
                "C-family process execution",
            ),
            (
                "downloader.mm",
                "int run() { return execv /* split */ (path, argv); }\n",
                "C-family process execution",
            ),
            (
                "downloader.go",
                'package downloader\nimport web "net/http"\nfunc load() { web.Get(target) }\n',
                "Go network or code-loading import",
            ),
            (
                "downloader.go",
                'package downloader\nimport (\n  runner /* split */ "os/exec"\n)\nfunc run() { runner.Command(path) }\n',
                "Go network or code-loading import",
            ),
            (
                "downloader.go",
                'package downloader\nimport plug "plugin"\nfunc load() { plug.Open(path) }\n',
                "Go network or code-loading import",
            ),
            (
                "downloader.cxx",
                "void load() { curl_easy_init(); }\n",
                "C/C++ libcurl use",
            ),
            (
                "downloader.hpp",
                "inline void load() { curl_easy_init(); }\n",
                "C/C++ libcurl use",
            ),
            (
                "downloader.hh",
                "inline void load() { curl_easy_init(); }\n",
                "C/C++ libcurl use",
            ),
            (
                "downloader.hxx",
                "inline void load() { curl_easy_init(); }\n",
                "C/C++ libcurl use",
            ),
        )
        for name, source, expected_reason in cases:
            with self.subTest(
                name=name, source=source, expected_reason=expected_reason
            ):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.make_runtime_root(root)
                    (root / "Sources" / name).write_text(source, encoding="utf-8")
                    with self.assertRaisesRegex(
                        supply_chain.SupplyChainError,
                        f"runtime code-download surface.*{re.escape(expected_reason)}",
                    ):
                        supply_chain.scan_runtime(self.config, root)

    def test_runtime_lexical_normalization_rejects_compiler_valid_indirection(
        self,
    ) -> None:
        cases = (
            (
                "C macro alias",
                "downloader.c",
                "#include <stdlib.h>\n#define RUN system\nint f(char*c){ return RUN(c); }\n",
                "C-family process execution",
                ("cc", "-E", "-P", "-x", "c", "-"),
                "system(c)",
            ),
            (
                "C escaped-line identifier",
                "downloader.c",
                "int system(const char*);\nint f(char*c){ return sys\\\ntem(c); }\n",
                "C-family process execution",
                ("cc", "-fsyntax-only", "-x", "c", "-"),
                None,
            ),
            (
                "C function pointer",
                "downloader.c",
                "int system(const char*);\nint f(char*c){ int (*run)(const char*) = &system; return run(c); }\n",
                "C-family process execution",
                ("cc", "-fsyntax-only", "-x", "c", "-"),
                None,
            ),
            (
                "C token-pasted libcurl",
                "downloader.c",
                "int curl_easy_perform(void*);\n#define JOIN_(a,b) a##b\n#define JOIN(a,b) JOIN_(a,b)\nint f(void*h){ return JOIN(curl_,easy_perform)(h); }\n",
                "C/C++ libcurl use",
                ("cc", "-E", "-P", "-x", "c", "-"),
                "curl_easy_perform(h)",
            ),
            (
                "C non-nesting block comment",
                "downloader.c",
                "/* ignored /* first terminator */\nint system(const char*);\nint f(char*c){ return system(c); }\n",
                "C-family process execution",
                ("cc", "-fsyntax-only", "-x", "c", "-"),
                None,
            ),
            (
                "C alternative token paste",
                "downloader.c",
                "int system(const char*);\n#define JOIN(a,b) a %:%: b\nint f(char*c){ return JOIN(sys,tem)(c); }\n",
                "C-family process execution",
                ("cc", "-E", "-P", "-x", "c", "-"),
                "system(c)",
            ),
            (
                "Swift Process typealias",
                "Downloader.swift",
                "import Foundation\ntypealias Runner = Process\nfunc f() { let p = Runner(); _ = p }\n",
                "Swift process execution",
                ("swiftc", "-typecheck", "-"),
                None,
            ),
            (
                "Swift inferred Data initializer",
                "Downloader.swift",
                "import Foundation\nfunc f(_ remoteURL: URL) throws {\n let data: Data = try .init(contentsOf: remoteURL)\n _ = data\n}\n",
                "Foundation Data/String URL loader",
                ("swiftc", "-typecheck", "-"),
                None,
            ),
            (
                "Swift raw string interpolation Process",
                "Downloader.swift",
                'import Foundation\nfunc f() { let value = #"\\#(Foundation.Process())"#; _ = value }\n',
                "Swift process execution",
                ("swiftc", "-typecheck", "-"),
                None,
            ),
            (
                "Swift escaped Process identifier",
                "Downloader.swift",
                "import Foundation\nfunc f() { let value = Foundation.`Process`(); _ = value }\n",
                "Swift process execution",
                ("swiftc", "-typecheck", "-"),
                None,
            ),
            (
                "Swift Data initializer reference",
                "Downloader.swift",
                "import Foundation\nfunc f(_ remoteURL: URL) throws {\n let loader = Data.init(contentsOf:options:)\n let data = try loader(remoteURL, [])\n _ = data\n}\n",
                "Foundation Data URL loader",
                ("swiftc", "-typecheck", "-"),
                None,
            ),
            (
                "Objective-C split dynamic selector",
                "Downloader.m",
                '#import <Foundation/Foundation.h>\nid f(NSURL *url) {\n SEL s = NSSelectorFromString([@"dataWithContentsOf" stringByAppendingString:@"URL:"]);\n#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Warc-performSelector-leaks"\n id value = [NSData performSelector:s withObject:url];\n#pragma clang diagnostic pop\n return value;\n}\n',
                "Objective-C dynamic URL loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
            (
                "Objective-C hash token-pasted URL selector",
                "Downloader.m",
                "#import <Foundation/Foundation.h>\n#define JOIN(a,b) a ## b\nNSData *load(NSURL *url) { return [NSData JOIN(dataWith,ContentsOfURL):url]; }\n",
                "Objective-C NSData URL loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
            (
                "Objective-C alternative token-pasted URL selector",
                "Downloader.m",
                "#import <Foundation/Foundation.h>\n#define JOIN(a,b) a %:%: b\nNSData *load(NSURL *url) { return [NSData JOIN(dataWith,ContentsOfURL):url]; }\n",
                "Objective-C NSData URL loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
            (
                "Objective-C hash token-pasted reflection symbol",
                "Downloader.m",
                "#import <Foundation/Foundation.h>\n#define JOIN(a,b) a ## b\nid invoke(id object, SEL selector) { return [object JOIN(perform,Selector):selector]; }\n",
                "Objective-C dynamic URL loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
            (
                "Objective-C alternative token-pasted reflection symbol",
                "Downloader.m",
                "#import <Foundation/Foundation.h>\n#define JOIN(a,b) a %:%: b\nid invoke(id object, SEL selector) { return [object JOIN(perform,Selector):selector]; }\n",
                "Objective-C dynamic URL loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
            (
                "Objective-C token-pasted Foundation network symbol",
                "Downloader.m",
                "#import <Foundation/Foundation.h>\n#define JOIN(a,b) a ## b\nClass loader(void) { return [JOIN(NSURL,Session) class]; }\n",
                "Foundation network loader",
                (
                    "clang",
                    "-fsyntax-only",
                    "-x",
                    "objective-c",
                    "-framework",
                    "Foundation",
                    "-",
                ),
                None,
            ),
        )
        for name, file_name, source, expected_reason, command, expected_output in cases:
            with self.subTest(name=name):
                compiler = shutil.which(command[0])
                can_compile = compiler is not None and (
                    file_name != "Downloader.m" or sys.platform == "darwin"
                )
                if can_compile:
                    result = subprocess.run(
                        (compiler, *command[1:]),
                        input=source,
                        text=True,
                        capture_output=True,
                        check=False,
                    )
                    self.assertEqual(
                        result.returncode,
                        0,
                        f"{name} fixture is not compiler-valid:\n{result.stderr}",
                    )
                    if expected_output is not None:
                        self.assertIn(expected_output, result.stdout)

                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.make_runtime_root(root)
                    (root / "Sources" / file_name).write_text(source, encoding="utf-8")
                    with self.assertRaisesRegex(
                        supply_chain.SupplyChainError,
                        f"runtime code-download surface.*{re.escape(expected_reason)}",
                    ):
                        supply_chain.scan_runtime(self.config, root)

    def test_go_non_nesting_comment_bypass_compiles_and_rejects(self) -> None:
        source = (
            "package downloader\n"
            "/* ignored /* first terminator */\n"
            'import web "net/http"\n'
            "var _ = web.Get\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            module = Path(temporary) / "module"
            module.mkdir()
            (module / "go.mod").write_text(
                "module example.test/downloader\n\ngo 1.20\n", encoding="utf-8"
            )
            (module / "downloader.go").write_text(source, encoding="utf-8")
            compiler = shutil.which("go")
            if compiler is not None:
                result = subprocess.run(
                    (compiler, "test", "./..."),
                    cwd=module,
                    text=True,
                    capture_output=True,
                    check=False,
                    env={
                        **dict(os.environ),
                        "GOTOOLCHAIN": "local",
                        "GOPROXY": "off",
                        "GOSUMDB": "off",
                    },
                )
                self.assertEqual(
                    result.returncode,
                    0,
                    f"Go non-nesting fixture is not compiler-valid:\n{result.stderr}",
                )

            root = Path(temporary) / "runtime"
            self.make_runtime_root(root)
            (root / "relay" / "downloader.go").write_text(source, encoding="utf-8")
            with self.assertRaisesRegex(
                supply_chain.SupplyChainError,
                "runtime code-download surface.*Go network or code-loading import",
            ):
                supply_chain.scan_runtime(self.config, root)

    def test_relay_toolchain_ci_checkout_provides_provenance_history(self) -> None:
        workflow = (supply_chain.ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        match = re.search(
            r"(?ms)^  relay-toolchain:\n(?P<body>.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)",
            workflow,
        )
        self.assertIsNotNone(match)
        body = match.group("body")
        checkout = re.search(
            r"(?ms)^      - uses: actions/checkout@[^\n]+\n"
            r"(?P<settings>.*?)(?=^      - (?:uses:|name:)|\Z)",
            body,
        )
        self.assertIsNotNone(checkout)
        self.assertRegex(checkout.group("settings"), r"(?m)^          fetch-depth: 0$")
        self.assertIn("make relay-supply-chain-audit", body)

    def test_go_import_lexer_handles_grouped_raw_aliases_and_comments(self) -> None:
        cases = (
            'package relay\nimport . /* split */ "net/http"\nvar _ = Get\n',
            'package relay\nimport _ /* split */ "plugin"\n',
            'package relay\nimport web "net\\x2fhttp"\nvar _ = web.Get\n',
            "package relay\nimport (\n // ignored comment\n web `os/exec`\n)\nvar _ = web.Command\n",
        )
        for source in cases:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.make_runtime_root(root)
                    (root / "relay" / "downloader.go").write_text(
                        source, encoding="utf-8"
                    )
                    with self.assertRaisesRegex(
                        supply_chain.SupplyChainError,
                        "runtime code-download surface.*Go network or code-loading import",
                    ):
                        supply_chain.scan_runtime(self.config, root)

    def test_runtime_audit_rejects_every_unclassified_file(self) -> None:
        cases = (
            ("Sources/NewRuntime.rs", "fn main() {}\n"),
            ("Sources/Unreviewed.md", "new runtime surface\n"),
            ("relay/cmd/relux-relay/new_source", "unknown language\n"),
        )
        for relative_path, source in cases:
            with self.subTest(relative_path=relative_path):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.make_runtime_root(root)
                    (root / "Sources" / "Safe.swift").write_text(
                        "let safe = true\n", encoding="utf-8"
                    )
                    path = root / relative_path
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(source, encoding="utf-8")
                    with self.assertRaisesRegex(
                        supply_chain.SupplyChainError, "unclassified file"
                    ):
                        supply_chain.scan_runtime(self.config, root)

    def test_runtime_audit_scope_is_exact_and_cannot_be_disabled(self) -> None:
        cases = (
            ("scanRoots", []),
            ("scanRoots", ["Sources"]),
            ("scanRoots", ["Sources", "App", "relay"]),
            ("scanExtensions", []),
            ("scanExtensions", [".swift"]),
            (
                "scanExtensions",
                list(reversed(supply_chain.APPROVED_RUNTIME_POLICY["scanExtensions"])),
            ),
            ("excludedFileSuffixes", []),
            ("excludedPaths", []),
            (
                "excludedPaths",
                [
                    *supply_chain.APPROVED_RUNTIME_POLICY["excludedPaths"],
                    "Sources/Unreviewed.swift",
                ],
            ),
            ("applicationCodeDownloadAllowed", True),
        )
        for field, value in cases:
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                config["runtimePolicy"][field] = value
                with self.assertRaisesRegex(
                    supply_chain.SupplyChainError, "runtime audit scope"
                ):
                    supply_chain.validate_config(config)

    def test_runtime_audit_requires_every_declared_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Sources").mkdir()
            (root / "Sources" / "Safe.swift").write_text("let safe = true\n")
            with self.assertRaisesRegex(
                supply_chain.SupplyChainError, "runtime audit root is unavailable"
            ):
                supply_chain.scan_runtime(self.config, root)

    def test_runtime_audit_rejects_symlinked_scope_entries(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_runtime_root(root)
            outside = root / "outside.swift"
            outside.write_text("let safe = true\n", encoding="utf-8")
            (root / "Sources" / "Linked.swift").symlink_to(outside)
            with self.assertRaisesRegex(
                supply_chain.SupplyChainError, "runtime audit scope contains a symlink"
            ):
                supply_chain.scan_runtime(self.config, root)

    def test_runtime_audit_allows_explicit_local_file_reads_and_excludes_go_tests(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_runtime_root(root)
            (root / "Sources" / "Local.swift").write_text(
                "// URLSession, Process, and Data(contentsOf: remoteURL) are documentation only.\n"
                "/* outer /* Process() */ still documentation */\n"
                "let data = try Data(contentsOf: URL(fileURLWithPath: path))\n"
                "let text = try String /* split */ (contentsOf: URL /* split */ (fileURLWithPath: path))\n"
                "let initialized = try Data.init(contentsOf: URL(fileURLWithPath: path))\n"
                "let inferred: Data = try .init(contentsOf: URL(fileURLWithPath: path))\n"
                'let rawText = #"Process() and Data.init(contentsOf:) are literal text"#\n'
                'let rawInterpolation = #"safe value: \\#(1 + 1)"#\n'
                "let `repeat` = 1\n",
                encoding="utf-8",
            )
            (root / "Sources" / "Ignored.c").write_text(
                "/* system(command), curl_easy_perform(handle), %:%: */\nint safe(void) { return 0; }\n",
                encoding="utf-8",
            )
            (root / "Sources" / "Ignored.m").write_text(
                "#define JOIN(a,b) a ## b\n"
                "int safeValue = 0;\n"
                "int safe(void) { return JOIN(safe,Value); }\n"
                'const char *note = "dataWith ## ContentsOfURL and perform ## Selector";\n'
                "/* NSSelector ## FromString and initWith ## ContentsOfURL */\n",
                encoding="utf-8",
            )
            (root / "relay" / "safe.go").write_text(
                "package relay\n/* net/http and os/exec are documentation */\nvar safe = `net/http`\n",
                encoding="utf-8",
            )
            (root / "relay" / "tool_test.go").write_text(
                'package relay\nimport "os/exec"\n', encoding="utf-8"
            )
            excluded = root / "App" / "ReluxProxyMac" / "Info.plist"
            excluded.parent.mkdir(parents=True)
            excluded.write_text(
                "<plist><string>curl</string></plist>\n", encoding="utf-8"
            )
            supply_chain.scan_runtime(self.config, root)

    def test_asset_linkage_drift_fails_clean_audit(self) -> None:
        contract = supply_chain.load_json(supply_chain.ASSET_SOURCE_PATH)
        contract["supplyChain"]["manifestLinkageSHA256"] = "0" * 64
        with mock.patch.object(
            supply_chain, "load_json", wraps=supply_chain.load_json
        ) as loader:

            def substitute(path):
                if path == supply_chain.ASSET_SOURCE_PATH:
                    return contract
                return loader._mock_wraps(path)

            loader.side_effect = substitute
            with self.assertRaisesRegex(
                supply_chain.SupplyChainError, "supply-chain linkage mismatch"
            ):
                supply_chain.audit()


if __name__ == "__main__":
    unittest.main()
