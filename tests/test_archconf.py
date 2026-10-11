import json
import os
import stat
import subprocess
import sys

import pytest

from conftest import REPO

sys.path.insert(0, str(REPO / "install"))
import archconf  # noqa: E402

ARCHCONF = REPO / "install" / "archconf.py"


def test_deep_merge_nested_and_scalars():
    base = {"a": {"x": 1, "y": 2}, "s": "base", "kernels": ["linux"]}
    over = {"a": {"y": 3}, "s": "over", "kernels": ["linux-lts"]}
    assert archconf.deep_merge(base, over) == {"a": {"x": 1, "y": 3}, "s": "over", "kernels": ["linux-lts"]}


def test_deep_merge_additive_keys_concatenate():
    base = {"packages": ["git"], "custom_commands": ["a"]}
    over = {"packages": ["vim"], "custom_commands": ["b"]}
    assert archconf.deep_merge(base, over) == {"packages": ["git", "vim"], "custom_commands": ["a", "b"]}


def test_deep_merge_does_not_mutate_inputs():
    base = {"a": {"x": 1}}
    archconf.deep_merge(base, {"a": {"x": 2}})
    assert base == {"a": {"x": 1}}


def test_load_users(tmp_path):
    f = tmp_path / "users"
    f.write_text("# c\n\nfschenkel wheel docker\nguest\n")
    assert archconf.load_users(f) == [("fschenkel", ["wheel", "docker"]), ("guest", [])]


def write_hosts(tmp_path, host_json=None):
    hosts = tmp_path / "hosts"
    (hosts / "common").mkdir(parents=True)
    (hosts / "common" / "archinstall.json").write_text(json.dumps(
        {"timezone": "Europe/Zurich", "packages": ["git"], "custom_commands": ["locale-gen"]}))
    (hosts / "common" / "users").write_text("fschenkel wheel\nguest\n")
    if host_json is not None:
        (hosts / "box").mkdir()
        (hosts / "box" / "archinstall.json").write_text(json.dumps(host_json))
    return hosts


def test_build_config_merges_host_and_sets_hostname(tmp_path):
    hosts = write_hosts(tmp_path, {"packages": ["vim"], "timezone": "UTC"})
    cfg = archconf.build_config(hosts, "box", "https://github.com/me/genesis.git", "main")
    assert cfg["hostname"] == "box"
    assert cfg["timezone"] == "UTC"
    assert cfg["packages"] == ["git", "vim"]
    assert cfg["custom_commands"][0] == "locale-gen"
    clone = cfg["custom_commands"][-1]
    assert "git clone --recurse-submodules --branch main https://github.com/me/genesis.git /home/fschenkel/repos/genesis" in clone
    assert "chown -R fschenkel:fschenkel /home/fschenkel/repos" in clone


def test_build_config_new_host_uses_common_only(tmp_path):
    hosts = write_hosts(tmp_path)
    cfg = archconf.build_config(hosts, "newbox", "https://x/g.git", "main")
    assert cfg["hostname"] == "newbox"
    assert cfg["packages"] == ["git"]


def test_real_common_config_is_valid_json_and_pins_choices():
    cfg = archconf.build_config(REPO / "hosts", "moog", "https://x/g.git", "main")
    assert cfg["locale_config"]["kb_layout"] == "de_CH-latin1"
    assert cfg["network_config"] == {"type": "nm"}
    assert "disk_config" not in cfg and "bootloader_config" not in cfg


def test_hash_password_is_yescrypt_and_verifies():
    h = archconf.hash_password("s3cret")
    assert h.startswith("$y$")
    assert archconf._crypt("s3cret", h) == h
    assert archconf._crypt("wrong", h) != h


def test_ask_password_repeats_until_match():
    answers = iter(["a", "b", "", "", "pw", "pw"])
    assert archconf.ask_password("root", lambda prompt: next(answers)) == "pw"


def test_build_creds_structure():
    answers = iter(["r", "r", "f", "f", "g", "g"])
    creds = archconf.build_creds([("fschenkel", ["wheel"]), ("guest", [])], lambda p: next(answers))
    assert archconf._crypt("r", creds["root_enc_password"]) == creds["root_enc_password"]
    assert [(u["username"], u["sudo"], u["groups"]) for u in creds["users"]] == [
        ("fschenkel", True, ["wheel"]), ("guest", False, [])]
    assert archconf._crypt("g", creds["users"][1]["enc_password"]) == creds["users"][1]["enc_password"]


def test_write_private_json_mode_0600(tmp_path):
    out = tmp_path / "creds.json"
    archconf.write_private_json(out, {"a": 1})
    assert stat.S_IMODE(out.stat().st_mode) == 0o600
    assert json.loads(out.read_text()) == {"a": 1}


def test_cli_creds_reads_non_tty_stdin(tmp_path):
    users = tmp_path / "users"
    users.write_text("fschenkel wheel\n")
    out = tmp_path / "creds.json"
    result = subprocess.run([sys.executable, str(ARCHCONF), "creds", str(users), str(out)],
                            input="r\nr\nf\nf\nREST\n", capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert [u["username"] for u in json.loads(out.read_text())["users"]] == ["fschenkel"]


def test_cli_creds_does_not_consume_extra_stdin(tmp_path):
    """bootstrap.sh reads an Enter keypress from the same stdin after archconf."""
    users = tmp_path / "users"
    users.write_text("fschenkel wheel\n")
    script = f'"{sys.executable}" "{ARCHCONF}" creds "{users}" "{tmp_path}/c.json"; read -r rest; echo "rest=$rest"'
    result = subprocess.run(["bash", "-c", script], input="r\nr\nf\nf\nREST\n", capture_output=True, text=True)
    assert "rest=REST" in result.stdout


def test_cli_config_prints_json():
    result = subprocess.run([sys.executable, str(ARCHCONF), "config", str(REPO / "hosts"), "moog",
                             "https://x/g.git", "main"], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["hostname"] == "moog"
