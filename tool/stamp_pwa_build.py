#!/usr/bin/env python3
"""Inyecta buildId en artefactos PWA tras flutter build web."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_WEB = ROOT / "build/web"
# Tokens distintos a los nombres JS (window.__PWA_BUILD_ID__) para no romper el HTML.
PLACEHOLDER = "%%PWA_BUILD_ID%%"
VERSION_PLACEHOLDER = "%%PWA_APP_VERSION%%"
BUILT_AT_PLACEHOLDER = "%%PWA_BUILT_AT%%"


def read_pubspec_version() -> str:
    pubspec = ROOT / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s#]+)", text, re.MULTILINE)
    if not match:
        return "0.0.0"
    return match.group(1).strip()


def replace_placeholders(text: str, build_id: str, app_version: str, built_at: str) -> str:
    return (
        text.replace(PLACEHOLDER, build_id)
        .replace(VERSION_PLACEHOLDER, app_version)
        .replace(BUILT_AT_PLACEHOLDER, built_at)
    )


def stamp_file(path: Path, build_id: str, app_version: str, built_at: str) -> None:
    if not path.exists():
        return
    original = path.read_text(encoding="utf-8")
    updated = replace_placeholders(original, build_id, app_version, built_at)
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        print(f"  stamped {path.relative_to(ROOT)}")


def main() -> None:
    if not BUILD_WEB.is_dir():
        raise SystemExit(f"No existe {BUILD_WEB}. Ejecuta flutter build web primero.")

    app_version = read_pubspec_version()
    built_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    build_id = f"{app_version}-{built_at.replace(':', '').replace('-', '')}"

    print(f"==> PWA buildId: {build_id}")

    version_payload = {
        "buildId": build_id,
        "appVersion": app_version,
        "builtAt": built_at,
    }
    version_path = BUILD_WEB / "version.json"
    version_path.write_text(
        json.dumps(version_payload, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"  wrote {version_path.relative_to(ROOT)}")

    for relative in (
        "index.html",
        "firebase-messaging-sw.js",
        "manifest.json",
    ):
        stamp_file(BUILD_WEB / relative, build_id, app_version, built_at)

    # Fail-fast: no subir a producción con placeholders sin reemplazar.
    index_html = BUILD_WEB / "index.html"
    if index_html.exists():
        index_text = index_html.read_text(encoding="utf-8")
        leftovers = [
            token
            for token in (PLACEHOLDER, VERSION_PLACEHOLDER, BUILT_AT_PLACEHOLDER)
            if token in index_text
        ]
        if leftovers:
            raise SystemExit(
                "ERROR: placeholders sin sellar en build/web/index.html: "
                + ", ".join(leftovers)
                + "\nNo despliegues este artefacto."
            )

    # Evita que un flutter_service_worker.js viejo se sirva en el host.
    flutter_sw = BUILD_WEB / "flutter_service_worker.js"
    if flutter_sw.exists():
        flutter_sw.unlink()
        print("  removed flutter_service_worker.js (PWA usa solo FCM SW)")

    deploy_htaccess = ROOT / "web/deploy/.htaccess"
    if deploy_htaccess.exists():
        target = BUILD_WEB / ".htaccess"
        target.write_text(deploy_htaccess.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"  copied {target.relative_to(ROOT)}")

    nginx_snippet = ROOT / "web/deploy/nginx-cache.conf"
    if nginx_snippet.exists():
        target = BUILD_WEB / "nginx-cache.conf"
        target.write_text(nginx_snippet.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"  copied {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
