#!/usr/bin/env python3
"""Give the exported engine files content-hashed names.

Godot names every export index.js / index.wasm / index.pck, so a browser that
cached one build has no way to tell a later one apart. The loader resolves all
of its assets as `${executable}.<suffix>`, so renaming the files and rewriting
`executable` in the page is enough to make each build a fresh set of URLs.
"""

import hashlib
import json
import pathlib
import re
import sys

SUFFIXES = [".js", ".wasm", ".pck", ".audio.worklet.js", ".audio.position.worklet.js"]


def main(out: pathlib.Path) -> int:
    page = out / "index.html"
    if not page.exists():
        print("fingerprint: no index.html in %s" % out, file=sys.stderr)
        return 1

    digest = hashlib.sha256()
    for suffix in (".wasm", ".pck"):
        digest.update((out / ("index" + suffix)).read_bytes())
    stamp = "index." + digest.hexdigest()[:12]

    for suffix in SUFFIXES:
        source = out / ("index" + suffix)
        if source.exists():
            source.rename(out / (stamp + suffix))

    html = page.read_text(encoding="utf-8")
    html = html.replace('src="index.js"', 'src="%s.js"' % stamp)

    config = re.search(r"const GODOT_CONFIG = (\{.*?\});", html, re.S)
    data = json.loads(config.group(1))
    data["executable"] = stamp
    data["fileSizes"] = {
        stamp + suffix: size
        for name, size in data.get("fileSizes", {}).items()
        for suffix in [name[len("index"):]]
    }
    html = html.replace(config.group(1), json.dumps(data, separators=(",", ":")))
    page.write_text(html, encoding="utf-8")

    print("fingerprint: engine files stamped as %s" % stamp)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(pathlib.Path(sys.argv[1])))
