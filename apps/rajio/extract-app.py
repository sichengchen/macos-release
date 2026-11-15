#!/usr/bin/env python3
"""Extract the Rajio handoff with relative links inside Electron frameworks."""

import os
from pathlib import Path
from shutil import copyfileobj
import stat
import sys
import unicodedata
from zipfile import ZipFile


def extract_app(archive: Path, app: Path) -> None:
    if app.exists() or app.is_symlink():
        raise ValueError("The app extraction directory already exists")

    seen = set()
    links = []
    with ZipFile(archive) as bundle:
        for member in bundle.infolist():
            name = member.orig_filename.removesuffix("/")
            parts = name.split("/")
            if parts[0] != app.name or any(part in ("", ".", "..") for part in parts):
                raise ValueError("Unexpected path in the app archive")
            if "\\" in name or "\0" in name:
                raise ValueError("Invalid app archive path")

            key = unicodedata.normalize("NFD", name).casefold()
            if key in seen:
                raise ValueError("Duplicate app archive path")
            seen.add(key)

            path = app.joinpath(*parts[1:])
            mode = member.external_attr >> 16
            file_type = stat.S_IFMT(mode)
            if member.is_dir() and file_type in (0, stat.S_IFDIR):
                path.mkdir(parents=True, exist_ok=True)
            elif stat.S_ISLNK(mode):
                if (parts[1:3] != ["Contents", "Frameworks"] or len(parts) < 5
                        or not parts[3].endswith(".framework") or member.file_size > 1024):
                    raise ValueError("Unexpected symlink in the app archive")
                target = bundle.read(member).decode("utf-8")
                if any(part in ("", ".", "..") for part in target.split("/")) or "\0" in target:
                    raise ValueError("Expected a relative framework symlink")
                links.append((path, target, app.joinpath(*parts[1:4])))
            elif len(parts) > 1 and file_type in (0, stat.S_IFREG):
                path.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(member) as source, path.open("xb") as output:
                    copyfileobj(source, output)
                path.chmod(0o755 if mode & 0o111 else 0o644)
            else:
                raise ValueError("Unexpected entry type in the app archive")

    # Create links after all regular files so extraction can never write through a link.
    for path, target, _ in links:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(target)
    for path, _, framework in links:
        if not path.resolve(strict=True).is_relative_to(framework.resolve(strict=True)):
            raise ValueError("Framework symlink leaves its framework")
    for directory, _, _ in os.walk(app):
        Path(directory).chmod(0o755)


if __name__ == "__main__":
    extract_app(Path(sys.argv[1]), Path(sys.argv[2]))
