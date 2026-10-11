import subprocess

import pytest

from conftest import REPO

HOOK = REPO / "hooks" / "pre-commit"
# Built by concatenation so this file itself never trips the guard.
PRIVATE_KEY = "-----BEGIN " + "OPENSSH PRIVATE KEY-----\nabc\n"
OVPN_TAG = "<" + "key>\nabc\n</key>\n"
SHADOW_LINE = "root:" + "$" + "y$j9T$abcdefghijklmnopqrstuv:19000::\n"
PSK_LINE = "psk" + "=hunter2\n"


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "t@example.com")
    git(tmp_path, "config", "user.name", "t")
    return tmp_path


def stage(repo, rel, content):
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    git(repo, "add", rel)


def run_hook(repo, *args):
    return subprocess.run([str(HOOK), *args], cwd=repo, capture_output=True, text=True)


def test_clean_file_passes(repo):
    stage(repo, "aconfmgr/files/etc/nanorc", "set linenumbers\n")
    result = run_hook(repo)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize("rel", [
    "aconfmgr/files/etc/shadow",
    "aconfmgr/files/etc/gshadow-",
    "aconfmgr/files/etc/ssh/ssh_host_ed25519_key.pub",
    "aconfmgr/files/etc/docker/key.json",
    "aconfmgr/files/etc/docker/certs.d/registry/ca.crt",
    "aconfmgr/files/etc/openvpn/client/client.conf",
    "aconfmgr/files/etc/NetworkManager/system-connections/home.nmconnection",
    "aconfmgr/files/etc/ca-certificates/trust-source/work.p11-kit",
    "aconfmgr/files/etc/cups/ppd/printer.ppd",
])
def test_forbidden_path_rejected(repo, rel):
    stage(repo, rel, "harmless\n")
    result = run_hook(repo)
    assert result.returncode == 1
    assert rel in result.stderr


@pytest.mark.parametrize("content", [PRIVATE_KEY, OVPN_TAG, SHADOW_LINE, PSK_LINE])
def test_secret_content_rejected(repo, content):
    stage(repo, "aconfmgr/files/etc/something.conf", content)
    result = run_hook(repo)
    assert result.returncode == 1
    assert "aconfmgr/files/etc/something.conf" in result.stderr


def test_all_mode_checks_committed_files(repo):
    stage(repo, "notes.txt", PRIVATE_KEY)
    git(repo, "commit", "-q", "-m", "x")
    assert run_hook(repo).returncode == 0  # nothing staged
    assert run_hook(repo, "--all").returncode == 1


def test_this_repo_is_clean():
    result = run_hook(REPO, "--all")
    assert result.returncode == 0, result.stderr


def test_secret_before_large_tail_rejected(repo):
    # A match near the top of a file larger than the pipe buffer must not be
    # masked by grep -q exiting early and the writer dying of SIGPIPE.
    stage(repo, "aconfmgr/files/etc/big.conf", PRIVATE_KEY + "x" * (1024 * 1024) + "\n")
    result = run_hook(repo)
    assert result.returncode == 1
    assert "aconfmgr/files/etc/big.conf" in result.stderr
