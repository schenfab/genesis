from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def write_exe(path: Path, body: str) -> Path:
    path.write_text("#!/usr/bin/env bash\n" + body)
    path.chmod(0o755)
    return path
