#!/usr/bin/env python3
"""
Empaqueteur et publicateur de releases versionnées LyuX (beta / stable).

Pour chaque version choisie (ex. 0.5.0-beta.1) :
- Crée automatiquement le dossier `lyux-desktop/releases/<version>/` ;
- Place l'ISO desktop `lyux-desktop-<version>.iso` (si fournie) ;
- Génère `release-manifest.json` (versions desktop/server/os-builder, SHA-256, taille, canal)
  et `SHA256SUMS` ;
- Met à jour `lyux-desktop/releases/latest-beta.json` (ou `latest-stable.json`) ;
- Optionnel (`--publish-gh`) : publie en pré-release GitHub via `gh release create`.
"""

import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent.parent


def _read_version(rel_path: str, fallback: str = "0.5.0-beta.1") -> str:
    p = REPO_ROOT / rel_path
    if p.exists():
        val = p.read_text(encoding="utf-8").strip()
        if val:
            return val
    return fallback


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def package_release(
    version: str,
    *,
    channel: str = "beta",
    iso_path: Optional[Path] = None,
    notes: str = "",
    releases_root: Optional[Path] = None,
) -> Dict[str, Any]:
    ver = version.strip()
    if not ver:
        raise ValueError("Numéro de version requis.")
    if channel not in ("beta", "stable"):
        raise ValueError("Canal invalide (beta ou stable uniquement).")

    root = releases_root or (REPO_ROOT / "lyux-desktop" / "releases")
    rel_dir = root / ver
    rel_dir.mkdir(parents=True, exist_ok=True)

    target_iso_name = f"lyux-desktop-{ver}.iso"
    target_iso = rel_dir / target_iso_name
    iso_info: Optional[Dict[str, Any]] = None

    if iso_path and Path(iso_path).exists():
        src = Path(iso_path).resolve()
        if src != target_iso.resolve():
            shutil.copy2(src, target_iso)
        digest = _sha256_file(target_iso)
        size_bytes = target_iso.stat().st_size
        iso_info = {
            "filename": target_iso_name,
            "sha256": digest,
            "size_bytes": size_bytes,
        }
        (rel_dir / "SHA256SUMS").write_text(f"{digest}  {target_iso_name}\n", encoding="utf-8")

    manifest: Dict[str, Any] = {
        "schema": "lyux-release-manifest",
        "schema_version": 1,
        "version": ver,
        "channel": channel,
        "prerelease": channel != "stable",
        "published_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "components": {
            "lyux_desktop": ver,
            "lyux_server": _read_version("lyux-server/VERSION", ver),
            "os_builder": _read_version("os-builder/VERSION", ver),
        },
        "iso": iso_info,
        "notes": notes or f"Release {channel} LyuX {ver}",
    }

    manifest_path = rel_dir / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    latest_file = root / ("latest-beta.json" if channel == "beta" else "latest-stable.json")
    latest_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    return {
        "release_dir": str(rel_dir),
        "manifest_path": str(manifest_path),
        "manifest": manifest,
    }


def publish_github_release(
    repo: str,
    manifest: Dict[str, Any],
    release_dir: Path,
) -> subprocess.CompletedProcess:
    ver = manifest["version"]
    tag = ver if ver.startswith("v") else f"v{ver}"
    cmd = [
        "gh",
        "release",
        "create",
        tag,
        "-R",
        repo,
        "--title",
        f"LyuX {tag} ({manifest['channel']})",
        "--notes",
        manifest["notes"],
    ]
    if manifest.get("prerelease", True):
        cmd.append("--prerelease")

    manifest_file = release_dir / "release-manifest.json"
    if manifest_file.exists():
        cmd.append(str(manifest_file))
    sums_file = release_dir / "SHA256SUMS"
    if sums_file.exists():
        cmd.append(str(sums_file))
    if manifest.get("iso"):
        iso_file = release_dir / manifest["iso"]["filename"]
        if iso_file.exists():
            cmd.append(str(iso_file))

    return subprocess.run(cmd, check=False, capture_output=True, text=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Empaquete et publie une release LyuX (beta/stable).")
    parser.add_argument("--version", default=_read_version("lyux-desktop/VERSION"))
    parser.add_argument("--channel", choices=("beta", "stable"), default="beta")
    parser.add_argument("--iso", type=Path, default=None)
    parser.add_argument("--notes", default="")
    parser.add_argument("--publish-gh", action="store_true")
    parser.add_argument("--gh-repo", default="Luux-Manchot/lyux-desktop")
    args = parser.parse_args()

    res = package_release(
        args.version,
        channel=args.channel,
        iso_path=args.iso,
        notes=args.notes,
    )
    print(f"Release empaquetee dans {res['release_dir']}")
    if args.publish_gh:
        proc = publish_github_release(args.gh_repo, res["manifest"], Path(res["release_dir"]))
        if proc.returncode != 0:
            print(f"Erreur gh release : {proc.stderr}")
            return proc.returncode
        print(proc.stdout.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
