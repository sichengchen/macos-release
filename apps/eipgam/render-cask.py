#!/usr/bin/env python3
"""Render the eipgam cask from the signed universal release asset."""

from pathlib import Path
import re
import sys


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: render-cask.py VERSION SHA256 OUTPUT")
    version, sha256, destination = sys.argv[1:]
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise SystemExit("Expected a stable release version")
    if not re.fullmatch(r"[a-f0-9]{64}", sha256):
        raise SystemExit("Expected a SHA-256 checksum")

    output = Path(destination)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f'''cask "eipgam" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/sichengchen/macos-release/releases/download/eipgam-v#{{version}}/eipgam-#{{version}}-universal.zip"
  name "eipgam"
  desc "Local gateway and model manager for AI coding agents"
  homepage "https://github.com/sichengchen/eipgam"

  depends_on macos: :monterey

  app "eipgam.app"
  binary "#{{appdir}}/eipgam.app/Contents/MacOS/eipgam"

  uninstall quit: "com.sichengchen.eipgam"
end
''', encoding="utf-8")


if __name__ == "__main__":
    main()
