#!/usr/bin/env python3
"""Render Eau's versioned Homebrew input-method cask."""

from pathlib import Path
import re
import sys


def render(version: str, sha256: str) -> str:
    if re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version) is None:
        raise ValueError("Expected a semantic release version")
    if re.fullmatch(r"[a-f0-9]{64}", sha256) is None:
        raise ValueError("Expected a SHA-256 checksum")
    return f'''cask "eau" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/sichengchen/eau/releases/download/v#{{version}}/Eau-#{{version}}-arm64.pkg"
  name "Eau"
  desc "Chinese and Japanese input method with mixed candidates"
  homepage "https://github.com/sichengchen/eau"

  depends_on arch: :arm64
  depends_on macos: :ventura

  pkg "Eau-#{{version}}-arm64.pkg"

  uninstall_preflight do
    executable = "/Library/Input Methods/Eau.app/Contents/MacOS/Eau"
    system_command executable, args: ["--disable-input-source"], must_succeed: false
  end

  uninstall quit: "com.scchan.inputmethod.eau",
            pkgutil: "com.scchan.eau.local-install"

  caveats do
    <<~EOS
      Add Eau under Chinese, Traditional in System Settings > Keyboard > Text Input > Edit > +.
      Complete any activation prompt in System Settings.
    EOS
  end
end
'''


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: render-homebrew-cask.py VERSION SHA256 OUTPUT", file=sys.stderr)
        return 2
    try:
        content = render(sys.argv[1], sys.argv[2])
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    output = Path(sys.argv[3])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
