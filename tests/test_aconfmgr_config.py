import shutil
import subprocess

import pytest

from conftest import REPO

CONFIG = REPO / "aconfmgr"
STUBS = 'AddPackage(){ echo "AddPackage $*"; }; IgnorePath(){ :; }; '


def source_host_layer(config_dir, hostname):
    script = STUBS + f'config_dir="{config_dir}"; HOSTNAME="{hostname}"; source "$config_dir/50-host.sh"'
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True).stdout


def test_host_layer_sources_matching_host_file(tmp_path):
    (tmp_path / "hosts").mkdir()
    shutil.copy(CONFIG / "50-host.sh", tmp_path)
    (tmp_path / "hosts" / "box.sh").write_text("AddPackage only-on-box\n")
    assert source_host_layer(tmp_path, "box") == "AddPackage only-on-box\n"
    assert source_host_layer(tmp_path, "other") == ""


@pytest.mark.parametrize("script", sorted(CONFIG.glob("*.sh")) + sorted(CONFIG.glob("hosts/*.sh")),
                         ids=lambda p: p.name)
def test_config_scripts_parse(script):
    subprocess.run(["bash", "-n", str(script)], check=True)


def test_every_guarded_path_is_ignored():
    """Paths the secret guard forbids must also be ignored by aconfmgr (so save never captures them)."""
    ignore = (CONFIG / "00-ignore.sh").read_text()
    for path in ["/etc/shadow", "/etc/gshadow", "/etc/ssh/ssh_host_", "/etc/docker/key.json",
                 "/etc/docker/certs.d", "/etc/openvpn/client", "/etc/NetworkManager/system-connections",
                 "/etc/ca-certificates/trust-source", "/etc/cups/ppd", "/etc/credstore",
                 "/etc/cryptsetup-keys.d"]:
        assert f"'{path}" in ignore, path
