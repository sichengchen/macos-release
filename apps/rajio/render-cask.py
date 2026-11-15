#!/usr/bin/env python3
"""Render Rajio's universal macOS cask."""

from pathlib import Path
import re
import sys


def main() -> None:
    version, sha256, destination = sys.argv[1:]
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise SystemExit("Expected a stable release version")
    if not re.fullmatch(r"[a-f0-9]{64}", sha256):
        raise SystemExit("Expected a SHA-256 checksum")

    output = Path(destination)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f'''cask "rajio" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/sichengchen/macos-release/releases/download/rajio-v#{{version}}/Rajio-#{{version}}-universal.dmg"
  name "Rajio"
  desc "Desktop podcast player"
  homepage "https://github.com/sichengchen/rajio"

  app "Rajio.app"
end
''', encoding="utf-8")


if __name__ == "__main__":
    main()
