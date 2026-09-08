from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).resolve().parents[1] / "check_board_structure.py"


class BoardStructureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / ".task-board"
        self.element("STORY-example/TASK-valid")

    def element(self, relative, complete=True):
        path = self.root / relative
        path.mkdir(parents=True, exist_ok=True)
        (path / "README.md").touch()
        if complete:
            (path / "progress.md").touch()
        # The container is itself an element too.
        for parent in path.parents:
            if parent == self.root:
                break
            if parent.name.startswith("STORY-"):
                (parent / "README.md").touch()
                (parent / "progress.md").touch()
        return path

    def run_checker(self):
        return subprocess.run([sys.executable, str(CHECKER), str(self.root)],
                              capture_output=True, text=True)

    def test_activity_and_resource_payloads_are_not_elements(self):
        for store in (".activity", ".resources"):
            path = self.root / store / "TASK-payload"
            path.mkdir(parents=True)
            (path / "events.ndjson").write_text('{}\n')
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("checked 2 board elements", result.stdout)

    def test_incomplete_element_fails(self):
        self.element("BUG-incomplete", complete=False)
        result = self.run_checker()
        self.assertEqual(result.returncode, 1)
        self.assertIn("BUG-incomplete: missing progress.md", result.stdout)

    def test_unknown_hidden_directory_is_not_exempt(self):
        self.element(".hidden/BUG-incomplete", complete=False)
        result = self.run_checker()
        self.assertEqual(result.returncode, 1)
        self.assertIn(".hidden/BUG-incomplete: missing progress.md", result.stdout)

    def test_nested_activity_name_is_not_exempt(self):
        self.element("STORY-example/.activity/BUG-incomplete", complete=False)
        result = self.run_checker()
        self.assertEqual(result.returncode, 1)
        self.assertIn(".activity/BUG-incomplete: missing progress.md", result.stdout)

    def test_empty_or_missing_board_fails(self):
        for suffix in ("empty", "missing"):
            root = Path(self.temp.name) / suffix
            if suffix == "empty":
                root.mkdir()
            result = subprocess.run([sys.executable, str(CHECKER), str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
