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
import io
import json
import shutil
import subprocess
import tarfile
import time
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


def _ar_member(name: str, payload: bytes, mtime: int) -> bytes:
    header = (
        f"{name:<16}"
        f"{mtime:<12}"
        f"{'0':<6}"
        f"{'0':<6}"
        f"{'100644':<8}"
        f"{len(payload):<10}"
        "`\n"
    ).encode("ascii")
    out = header + payload
    if len(out) % 2 == 1:
        out += b"\n"
    return out


def build_desktop_core_deb(version: str, output_dir: Path) -> Path:
    """
    Construit le paquet Debian `lyux-desktop-core_<version>_all.deb` en Python pur
    (sans dépendre de dpkg-deb sous Windows) pour les mises à jour in-system.
    """
    ver = version.strip()
    deb_name = f"lyux-desktop-core_{ver}_all.deb"
    deb_path = output_dir / deb_name
    mtime = int(time.time())

    control_txt = (
        "Package: lyux-desktop-core\n"
        f"Version: {ver}\n"
        "Section: admin\n"
        "Priority: optional\n"
        "Architecture: all\n"
        "Depends: libnss-extrausers\n"
        "Maintainer: LyuX <contact@flowcrea.fr>\n"
        "Description: LyuX Desktop core (OOBE, profile applier, maintenance & PAM session sync)\n"
    ).encode("utf-8")

    postinst_txt = (
        "#!/bin/sh\n"
        "set -e\n"
        "chmod +x /opt/lyux/apps/enrollment/scripts/*.sh 2>/dev/null || true\n"
        "mkdir -p /mnt/lyux-nas/homes /etc/sddm.conf.d /var/lib/extrausers\n"
        "printf '[Theme]\\nDisableUserList=true\\n\\n[Users]\\nRememberLastUser=false\\nHideUsers=lyux-admin,root\\n' > /etc/sddm.conf.d/99-lyux-login.conf\n"
        "if [ -f /etc/nsswitch.conf ]; then\n"
        "  for db in passwd group shadow; do\n"
        "    if grep -qE \"^${db}:\" /etc/nsswitch.conf && ! grep -qE \"^${db}:.*\\bextrausers\\b\" /etc/nsswitch.conf; then\n"
        "      sed -i -E \"s/^(${db}:.*)/\\1 extrausers/\" /etc/nsswitch.conf\n"
        "    fi\n"
        "  done\n"
        "fi\n"
        "if [ -f /opt/lyux/apps/enrollment/scripts/lyux-pam-auth.sh ] && [ -f /etc/pam.d/common-auth ]; then\n"
        "  if ! grep -qF 'lyux-pam-auth.sh' /etc/pam.d/common-auth; then\n"
        "    sed -i '1i auth sufficient pam_exec.so expose_authtok quiet /opt/lyux/apps/enrollment/scripts/lyux-pam-auth.sh' /etc/pam.d/common-auth\n"
        "  fi\n"
        "fi\n"
        "if [ -f /opt/lyux/apps/enrollment/scripts/lyux-pam-session.sh ] && [ -f /etc/pam.d/common-session ]; then\n"
        "  if ! grep -qF 'lyux-pam-session.sh' /etc/pam.d/common-session; then\n"
        "    echo 'session requisite pam_exec.so /opt/lyux/apps/enrollment/scripts/lyux-pam-session.sh' >> /etc/pam.d/common-session\n"
        "  fi\n"
        "fi\n"
        "if [ -f /opt/lyux/apps/enrollment/src/nss_user_sync.py ]; then\n"
        "  python3 /opt/lyux/apps/enrollment/src/nss_user_sync.py || true\n"
        "fi\n"
        "exit 0\n"
    ).encode("utf-8")

    ctrl_buf = io.BytesIO()
    with tarfile.open(fileobj=ctrl_buf, mode="w:gz") as tf:
        for fname, content, mode in (
            ("./control", control_txt, 0o644),
            ("./postinst", postinst_txt, 0o755),
        ):
            ti = tarfile.TarInfo(fname)
            ti.size = len(content)
            ti.mode = mode
            ti.mtime = mtime
            tf.addfile(ti, io.BytesIO(content))

    data_buf = io.BytesIO()
    enrollment_root = REPO_ROOT / "lyux-desktop" / "applications" / "enrollment"
    with tarfile.open(fileobj=data_buf, mode="w:gz") as tf:
        ver_bytes = (ver + "\n").encode("utf-8")
        vi = tarfile.TarInfo("./opt/lyux/VERSION")
        vi.size = len(ver_bytes)
        vi.mode = 0o644
        vi.mtime = mtime
        tf.addfile(vi, io.BytesIO(ver_bytes))

        for sub in ("src", "scripts"):
            sub_dir = enrollment_root / sub
            if not sub_dir.exists():
                continue
            for file_path in sorted(sub_dir.rglob("*")):
                if not file_path.is_file() or "__pycache__" in file_path.parts:
                    continue
                rel = file_path.relative_to(enrollment_root).as_posix()
                raw = file_path.read_bytes()
                ti = tarfile.TarInfo(f"./opt/lyux/apps/enrollment/{rel}")
                ti.size = len(raw)
                ti.mode = 0o755 if file_path.suffix == ".sh" else 0o644
                ti.mtime = mtime
                tf.addfile(ti, io.BytesIO(raw))

    ar_bytes = (
        b"!<arch>\n"
        + _ar_member("debian-binary", b"2.0\n", mtime)
        + _ar_member("control.tar.gz", ctrl_buf.getvalue(), mtime)
        + _ar_member("data.tar.gz", data_buf.getvalue(), mtime)
    )
    deb_path.write_bytes(ar_bytes)
    return deb_path


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
    checksum_lines = []

    deb_path = build_desktop_core_deb(ver, rel_dir)
    deb_digest = _sha256_file(deb_path)
    deb_info = {
        "filename": deb_path.name,
        "sha256": deb_digest,
        "size_bytes": deb_path.stat().st_size,
    }
    checksum_lines.append(f"{deb_digest}  {deb_path.name}")

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
        checksum_lines.append(f"{digest}  {target_iso_name}")

    (rel_dir / "SHA256SUMS").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")

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
            "debian_target": "13.8",
            "kde_target": "6.3",
        },
        "deb_package": deb_info,
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
    if manifest.get("deb_package"):
        deb_file = release_dir / manifest["deb_package"]["filename"]
        if deb_file.exists():
            cmd.append(str(deb_file))
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
