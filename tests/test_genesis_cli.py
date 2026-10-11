import os
import subprocess

from conftest import REPO, write_exe

GENESIS = REPO / "genesis"


def make_env(tmp_path, **extra):
    fake = tmp_path / "fake-aconfmgr"
    fake.mkdir()
    write_exe(fake / "aconfmgr", 'echo "cwd=$PWD args=$*" >> "$GENESIS_TEST_LOG"\n')
    # Stand-ins so apply never runs the real sudo/dconf.
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    write_exe(bin_dir / "sudo", 'echo "sudo $*" >> "$GENESIS_TEST_LOG"\n')
    write_exe(bin_dir / "dconf", 'exit 0\n')
    env = dict(os.environ, GENESIS_ACONFMGR_DIR=str(fake), GENESIS_TEST_LOG=str(tmp_path / "log"),
               PATH=f"{bin_dir}:{os.environ['PATH']}", **extra)
    return env, fake


def run(args, env):
    return subprocess.run([str(GENESIS), *args], env=env, capture_output=True, text=True)


def test_no_command_prints_usage(tmp_path):
    env, _ = make_env(tmp_path)
    result = run([], env)
    assert result.returncode == 2
    assert "Usage: genesis" in result.stderr


def test_unknown_command_fails(tmp_path):
    env, _ = make_env(tmp_path)
    assert run(["frobnicate"], env).returncode == 2


def test_save_runs_aconfmgr_from_its_checkout(tmp_path):
    env, fake = make_env(tmp_path)
    result = run(["save"], env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {REPO}/aconfmgr save\n"


def test_check_runs_aconfmgr_check(tmp_path):
    env, fake = make_env(tmp_path)
    assert run(["check"], env).returncode == 0
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {REPO}/aconfmgr check\n"


def make_config(tmp_path, body):
    cfg = tmp_path / "cfg"
    cfg.mkdir()
    (cfg / "10-base.sh").write_text(body)
    return cfg


def test_apply_runs_aconfmgr_then_users_step(tmp_path):
    users = tmp_path / "users"
    users.write_text("genesis-no-such-user wheel\n")
    cfg = make_config(tmp_path, "AddPackage base\n")
    env, fake = make_env(tmp_path, GENESIS_USERS_FILE=str(users), GENESIS_CONFIG_DIR=str(cfg))
    result = run(["apply"], env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {cfg} apply\nsudo dconf update\n"
    assert "genesis-no-such-user" in result.stderr  # users step ran and skipped unknown user


def test_apply_accepts_package_in_host_file(tmp_path):
    cfg = make_config(tmp_path, "# nothing\n")
    (cfg / "hosts").mkdir()
    (cfg / "hosts" / "box.sh").write_text("  AddPackage grub\n")
    users = tmp_path / "users"
    users.write_text("")
    env, _ = make_env(tmp_path, GENESIS_USERS_FILE=str(users), GENESIS_CONFIG_DIR=str(cfg))
    assert run(["apply"], env).returncode == 0


def test_apply_skips_dconf_update_without_dconf(tmp_path):
    cfg = make_config(tmp_path, "AddPackage base\n")
    users = tmp_path / "users"
    users.write_text("")
    env, fake = make_env(tmp_path, GENESIS_USERS_FILE=str(users), GENESIS_CONFIG_DIR=str(cfg))
    env["GENESIS_DCONF"] = "genesis-no-such-dconf"  # host without dconf (no GNOME)
    assert run(["apply"], env).returncode == 0
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {cfg} apply\n"


def test_apply_refuses_empty_config(tmp_path):
    cfg = make_config(tmp_path, "# AddPackage in a comment does not count\nIgnorePath '/x'\n")
    env, _ = make_env(tmp_path, GENESIS_CONFIG_DIR=str(cfg))
    result = run(["apply"], env)
    assert result.returncode == 1
    assert "refusing to apply" in result.stderr
    assert "genesis save" in result.stderr
    assert not (tmp_path / "log").exists()  # aconfmgr was never called


def test_install_refuses_outside_live_iso(tmp_path):
    env, _ = make_env(tmp_path, GENESIS_ISO_MARKER=str(tmp_path / "nope"))
    result = run(["install"], env)
    assert result.returncode == 1
    assert "live ISO" in result.stderr
