"""Example Python test collected by tools/run_tests.py."""
import unittest
from pathlib import Path


class ExampleTest(unittest.TestCase):
    def test_project_file_exists(self):
        self.assertTrue((Path(__file__).resolve().parents[2] / "project.godot").is_file())


if __name__ == "__main__":
    unittest.main()
