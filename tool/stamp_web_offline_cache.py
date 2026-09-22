#!/usr/bin/env python3
"""Stamp the built NexaPOS service worker with its immutable application shell."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


PRECACHE_TOKEN = "/*NEXAPOS_PRECACHE*/[]"
VERSION_TOKEN = "/*NEXAPOS_CACHE_VERSION*/"
EXCLUDED_NAMES = {
    "flutter_service_worker.js",  # Flutter's generated unregister stub.
    "nexapos_service_worker.js",  # The browser fetches the worker itself.
}
# .symbols are debugging aids; skwasm*/wimp*/webparagraph are CanvasKit variants this build's
# loader never selects (it uses the Chromium variant on Chrome/Edge, the plain one elsewhere),
# so caching them would only cost every visitor ~20 MB of pointless first-visit download.
EXCLUDED_SUFFIXES = {".map", ".symbols"}


def is_unused_renderer(path: Path) -> bool:
    return (
        path.name.startswith(("skwasm", "wimp"))
        or "webparagraph" in path.parts
    )


def verify_deployed(root: Path) -> int:
    """Fail unless every file the worker will precache really exists in the deployed folder.

    The worker installs with cache.addAll(), which is all-or-nothing: one URL that answers 404
    (a dotfile the deploy step deletes, a file left out of the copy) means the offline cache
    NEVER installs, and nothing on the page shows it. Run this against publish-site/app, the
    folder that is actually served, before pushing.
    """
    worker = root / "nexapos_service_worker.js"
    if not worker.is_file():
        raise SystemExit(f"{worker} not found")
    match = re.search(r"const PRECACHE_URLS = (\[.*?\]);", worker.read_text(encoding="utf-8"))
    if not match:
        raise SystemExit("no PRECACHE_URLS list in the worker (was it stamped?)")
    urls = json.loads(match.group(1))
    if not urls:
        raise SystemExit("the worker's PRECACHE_URLS list is empty (was it stamped?)")
    missing = [url for url in urls if not (root / url[2:]).is_file()]
    if missing:
        raise SystemExit(
            "the offline cache would fail to install; these precached files are not deployed: "
            + ", ".join(missing)
        )
    print(f"deployed offline cache ok: all {len(urls)} precached files exist in {root}")
    return 0


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "--verify-deployed":
        return verify_deployed(Path(sys.argv[2]).resolve())
    if len(sys.argv) != 2:
        print(
            "usage: stamp_web_offline_cache.py <build/web>\n"
            "       stamp_web_offline_cache.py --verify-deployed <publish-site/app>",
            file=sys.stderr,
        )
        return 2

    root = Path(sys.argv[1]).resolve()
    worker = root / "nexapos_service_worker.js"
    required = [
        root / "index.html",
        root / "flutter_bootstrap.js",
        root / "main.dart.js",
        root / "sqlite3mc.wasm",
        root / "drift_worker.js",
        root / "canvaskit" / "canvaskit.js",
        root / "canvaskit" / "canvaskit.wasm",
    ]
    missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(
            "offline build is missing required local files: " + ", ".join(missing)
        )

    files = sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        # Dotfiles (.last_build_id) are build bookkeeping the release step deletes, and
        # GitHub Pages does not serve them: precaching one made the whole install fail.
        and not path.name.startswith(".")
        and path.name not in EXCLUDED_NAMES
        and path.suffix not in EXCLUDED_SUFFIXES
        and not is_unused_renderer(path)
    )

    digest = hashlib.sha256()
    urls: list[str] = []
    total_bytes = 0
    for path in files:
        relative = path.relative_to(root).as_posix()
        payload = path.read_bytes()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(payload).digest())
        urls.append("./" + relative)
        total_bytes += len(payload)

    source = worker.read_text(encoding="utf-8")
    if PRECACHE_TOKEN not in source or VERSION_TOKEN not in source:
        raise SystemExit("service-worker template tokens are missing")

    version = digest.hexdigest()[:20]
    source = source.replace(VERSION_TOKEN, version)
    source = source.replace(PRECACHE_TOKEN, json.dumps(urls, separators=(",", ":")))
    worker.write_text(source, encoding="utf-8", newline="\n")
    print(
        f"offline cache {version}: {len(urls)} files, "
        f"{total_bytes / 1024 / 1024:.1f} MB"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
