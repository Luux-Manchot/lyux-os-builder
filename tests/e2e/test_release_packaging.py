import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "lyux-iso-builder"))

from publish_release import package_release


def test_package_release_creates_versioned_folder_iso_and_manifest(tmp_path):
    fake_iso = tmp_path / "source.iso"
    fake_iso.write_bytes(b"LYUX-ISO-PAYLOAD-0.5.0")

    releases_root = tmp_path / "desktop_releases"
    res = package_release(
        "0.5.0-beta.1",
        channel="beta",
        iso_path=fake_iso,
        notes="Beta test release",
        releases_root=releases_root,
    )

    rel_dir = releases_root / "0.5.0-beta.1"
    assert rel_dir.is_dir()
    assert (rel_dir / "lyux-desktop-0.5.0-beta.1.iso").is_file()
    assert (rel_dir / "SHA256SUMS").is_file()
    assert (releases_root / "latest-beta.json").is_file()

    manifest = json.loads((rel_dir / "release-manifest.json").read_text(encoding="utf-8"))
    assert manifest["version"] == "0.5.0-beta.1"
    assert manifest["channel"] == "beta"
    assert manifest["prerelease"] is True
    assert manifest["iso"]["filename"] == "lyux-desktop-0.5.0-beta.1.iso"
    assert len(manifest["iso"]["sha256"]) == 64
