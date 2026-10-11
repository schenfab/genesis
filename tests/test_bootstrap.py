import json
import os
import subprocess
from pathlib import Path

from conftest import REPO, write_exe

BOOTSTRAP = REPO / "install" / "bootstrap.sh"
# root, fschenkel, guest, andrea, each entered twice; then Enter to start archinstall
STDIN = "r\nr\nf\nf\ng\ng\na\na\n\n"


def make_env(tmp_path):
    capture = tmp_path / "capture"
    capture.mkdir()
    stub = write_exe(tmp_path / "archinstall", (
        'while [[ $# -gt 0 ]]; do case $1 in\n'
        '  --config) cp "$2" "$CAPTURE/config.json"; echo "$2" > "$CAPTURE/config.path"; shift 2;;\n'
        '  --creds) cp "$2" "$CAPTURE/creds.json"; echo "$2" > "$CAPTURE/creds.path"; shift 2;;\n'
        '  *) echo "unexpected arg $1" >&2; exit 9;;\n'
        'esac; done\n'))
    env = dict(os.environ, CAPTURE=str(capture), GENESIS_ARCHINSTALL=str(stub),
               GENESIS_REPO_URL="https://github.com/me/genesis.git", GENESIS_REPO_REF="main")
    return capture, env


def test_bootstrap_builds_config_and_creds_and_cleans_up(tmp_path):
    capture, env = make_env(tmp_path)
    result = subprocess.run([str(BOOTSTRAP), "moog"], input=STDIN, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    config = json.loads((capture / "config.json").read_text())
    creds = json.loads((capture / "creds.json").read_text())
    assert config["hostname"] == "moog"
    assert "https://github.com/me/genesis.git" in config["custom_commands"][-1]
    assert [u["username"] for u in creds["users"]] == ["fschenkel", "guest", "andrea"]
    assert not Path((capture / "creds.path").read_text().strip()).exists()  # temp creds deleted
    assert "btrfs" in result.stdout  # disk instructions shown


def test_bootstrap_rejects_invalid_host_name(tmp_path):
    _, env = make_env(tmp_path)
    result = subprocess.run([str(BOOTSTRAP), "Bad Name"], input=STDIN, env=env, capture_output=True, text=True)
    assert result.returncode == 1
    assert "invalid host name" in result.stderr
