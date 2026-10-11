import os
import subprocess

from conftest import REPO, write_exe

USERS_SH = REPO / "install" / "users.sh"


def setup(tmp_path, users, groups, members):
    fake = tmp_path / "fake"
    fake.mkdir()
    (fake / "passwd").write_text("".join(f"{u}\n" for u in users))
    (fake / "group").write_text("".join(f"{g}\n" for g in groups))
    (fake / "members").write_text("".join(f"{u}:{' '.join(gs)}\n" for u, gs in members.items()))
    (fake / "log").write_text("")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    write_exe(bin_dir / "sudo", 'exec "$@"\n')
    write_exe(bin_dir / "getent", 'grep -qx -- "$2" "$FAKE/$1"\n')
    write_exe(bin_dir / "id", '[[ $1 == -nG ]]; grep "^$2:" "$FAKE/members" | cut -d: -f2\n')
    write_exe(bin_dir / "groupadd", 'echo "groupadd $*" >> "$FAKE/log"; echo "${*: -1}" >> "$FAKE/group"\n')
    write_exe(bin_dir / "usermod", 'echo "usermod $*" >> "$FAKE/log"\n')
    env = dict(os.environ, FAKE=str(fake), PATH=f"{bin_dir}:{os.environ['PATH']}")
    return fake, env


def run(tmp_path, env, users_file_text):
    users_file = tmp_path / "users"
    users_file.write_text(users_file_text)
    return subprocess.run([str(USERS_SH), str(users_file)], env=env, capture_output=True, text=True)


def test_adds_missing_membership(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], ["docker"], {"fschenkel": ["fschenkel"]})
    result = run(tmp_path, env, "fschenkel docker\n")
    assert result.returncode == 0, result.stderr
    assert (fake / "log").read_text() == "usermod -aG docker fschenkel\n"


def test_existing_membership_is_left_alone(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], ["docker"], {"fschenkel": ["fschenkel", "docker"]})
    assert run(tmp_path, env, "fschenkel docker\n").returncode == 0
    assert (fake / "log").read_text() == ""


def test_missing_group_is_created_as_system_group(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], [], {"fschenkel": ["fschenkel"]})
    assert run(tmp_path, env, "fschenkel uinputg\n").returncode == 0
    assert (fake / "log").read_text() == "groupadd --system uinputg\nusermod -aG uinputg fschenkel\n"


def test_unknown_user_is_skipped_with_warning(tmp_path):
    fake, env = setup(tmp_path, [], ["docker"], {})
    result = run(tmp_path, env, "ghost docker\n")
    assert result.returncode == 0
    assert "ghost" in result.stderr
    assert (fake / "log").read_text() == ""


def test_comments_blank_lines_and_groupless_users(tmp_path):
    fake, env = setup(tmp_path, ["guest"], [], {"guest": ["guest"]})
    assert run(tmp_path, env, "# comment\n\nguest\n").returncode == 0
    assert (fake / "log").read_text() == ""


def test_final_line_without_trailing_newline_is_processed(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], ["docker"], {"fschenkel": ["fschenkel"]})
    assert run(tmp_path, env, "fschenkel docker").returncode == 0
    assert (fake / "log").read_text() == "usermod -aG docker fschenkel\n"
