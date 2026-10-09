#!/usr/bin/env python3
"""Run with an isolated user:// directory: python3 tests/run_save_tests.py [godot]."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
engine = shutil.which(sys.argv[1] if len(sys.argv) > 1 else "godot")
if not engine:
    sys.exit("Godot 4.3+ is required; pass the binary path as the first argument.")
with tempfile.TemporaryDirectory(prefix="tidewrack-tests-") as temp:
    project = Path(temp) / "project"
    shutil.copytree(root, project, ignore=shutil.ignore_patterns(".git", ".godot"))
    config = project / "project.godot"
    config.write_text(config.read_text().replace('[application]',
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + temp + '/userdata"'))
    env = dict(os.environ, TIDEWRACK_TEST_SAVE="1")
    subprocess.run([engine, "--headless", "--path", str(project), "--editor", "--quit"], env=env, check=True)
    command = [engine, "--headless", "--path", str(project), "tests/test_save_journal.tscn"]
    for extra in [[], ["--", "--write-fixture"], ["--", "--read-fixture"]]:
        result = subprocess.run(command + extra, env=env)
        if result.returncode:
            sys.exit(result.returncode)
