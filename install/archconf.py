#!/usr/bin/env python
"""Build archinstall config and credentials for a genesis host.

  archconf.py config <hosts_dir> <host> <repo_url> <repo_ref>   print merged config JSON
  archconf.py creds <users_file> <out_path>                     prompt passwords, write creds JSON (0600)
"""
import ctypes
import ctypes.util
import getpass
import json
import os
import shlex
import sys
from pathlib import Path

ADDITIVE_KEYS = {"packages", "custom_commands"}


def deep_merge(base, override):
    merged = dict(base)
    for key, value in override.items():
        if key in ADDITIVE_KEYS and isinstance(merged.get(key), list):
            merged[key] = merged[key] + list(value)
        elif isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_users(path):
    users = []
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#"):
            users.append((fields[0], fields[1:]))
    return users


def build_config(hosts_dir, host, repo_url, repo_ref):
    hosts_dir = Path(hosts_dir)
    config = json.loads((hosts_dir / "common" / "archinstall.json").read_text())
    host_file = hosts_dir / host / "archinstall.json"
    if host_file.exists():
        config = deep_merge(config, json.loads(host_file.read_text()))
    config["hostname"] = host
    admin = next(name for name, groups in load_users(hosts_dir / "common" / "users") if "wheel" in groups)
    repos = f"/home/{admin}/repos"
    clone = (f"git clone --recurse-submodules --branch {shlex.quote(repo_ref)} "
             f"{shlex.quote(repo_url)} {repos}/genesis && chown -R {admin}:{admin} {repos}")
    config["custom_commands"] = config.get("custom_commands", []) + [clone]
    return config


def _libcrypt():
    lib = ctypes.CDLL(ctypes.util.find_library("crypt") or "libcrypt.so.2")
    lib.crypt_gensalt.restype = ctypes.c_char_p
    lib.crypt_gensalt.argtypes = [ctypes.c_char_p, ctypes.c_ulong, ctypes.c_char_p, ctypes.c_int]
    lib.crypt.restype = ctypes.c_char_p
    lib.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    return lib


def _crypt(password, setting):
    out = _libcrypt().crypt(password.encode(), setting.encode())
    if not out or out.startswith(b"*"):
        raise RuntimeError("crypt() failed")
    return out.decode()


def hash_password(password):
    salt = _libcrypt().crypt_gensalt(b"$y$", 0, None, 0)
    if not salt:
        raise RuntimeError("crypt_gensalt() failed")
    return _crypt(password, salt.decode())


def ask_password(label, read):
    while True:
        first = read(f"Password for {label}: ")
        second = read(f"Repeat password for {label}: ")
        if first and first == second:
            return first
        print("Passwords empty or not matching, try again.", file=sys.stderr)


def build_creds(users, read):
    return {
        "root_enc_password": hash_password(ask_password("root", read)),
        "users": [
            {"username": name, "enc_password": hash_password(ask_password(name, read)),
             "sudo": "wheel" in groups, "groups": []}
            for name, groups in users
        ],
    }


def write_private_json(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)


def _read_line_unbuffered(prompt):
    """Read one line from fd 0 without consuming more (the caller's shell reads after us)."""
    print(prompt, end="", file=sys.stderr, flush=True)
    chars = []
    while True:
        c = os.read(0, 1)
        if not c:
            raise EOFError("stdin closed while reading password")
        if c == b"\n":
            return b"".join(chars).decode()
        chars.append(c)


def main(argv):
    if len(argv) == 5 and argv[0] == "config":
        json.dump(build_config(Path(argv[1]), argv[2], argv[3], argv[4]), sys.stdout, indent=2)
        print()
    elif len(argv) == 3 and argv[0] == "creds":
        read = getpass.getpass if sys.stdin.isatty() else _read_line_unbuffered
        write_private_json(Path(argv[2]), build_creds(load_users(Path(argv[1])), read))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
