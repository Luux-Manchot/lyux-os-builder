"""
ISO client générique : visuel LyuX obligatoire et zéro secret figé.
Ces tests vérifient la chaîne build -> preseed -> profil graphique.
"""

from pathlib import Path


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class TestClientISOVisualPayload:
    def test_build_script_embeds_desktop_profile(self, paths):
        builder = paths["iso_builder"]
        script = _read(builder / "build-client-iso.sh")
        assert "lyux-payload/desktop-profile" in script
        assert "lyux-desktop-profile" in script
        assert "themes" in script

    def test_build_script_uses_disk_backed_workdir(self, paths):
        script = _read(paths["iso_builder"] / "build-client-iso.sh")
        assert 'WORK_DIR="/var/tmp/lyux-client-iso-build"' in script
        assert 'ORIG_ISO="${LYUX_DEBIAN_ISO:-/var/tmp/debian-netinst-13.8.0.iso}"' in script

    def test_build_script_removes_old_iso_and_validates_preseed(self, paths):
        script = _read(paths["iso_builder"] / "build-client-iso.sh")
        assert 'rm -f "$OUTPUT_DIR/$ISO_NAME"' in script
        assert "netcfg/choose_interface select auto" in script
        assert "netcfg/disable_autoconfig boolean false" in script
        assert "netcfg/disable_dhcp boolean false" in script
        assert "apt-setup/use_mirror boolean true" in script
        assert "pkgsel/upgrade select none" in script

    def test_build_script_embeds_themes_offline(self, paths):
        script = _read(paths["iso_builder"] / "build-client-iso.sh")
        for theme in ("Orchis-kde", "WhiteSur-kde", "Tela-circle-icon-theme"):
            assert theme in script

    def test_preseed_defers_profile_after_install(self, preseed_iso_path):
        content = _read(preseed_iso_path)
        assert "/cdrom/lyux-payload/desktop-profile/." not in content
        assert "cp -r /cdrom/lyux-payload/enrollment" in content
        assert "cp -r /cdrom/lyux-payload/welcome" in content
        assert "first-boot.flag" in content

    def test_install_profile_prefers_embedded_themes(self, paths):
        profile = paths["root"] / "os-builder" / "lyux-desktop-profile"
        script = _read(profile / "install-desktop-profile.sh")
        assert 'SCRIPT_DIR}/themes/${name}' in script
        assert "fetch_theme" in script
        # Les thèmes ne doivent plus être téléchargés inconditionnellement.
        assert "git clone --depth 1 https://github.com/vinceliuice/Orchis-kde.git /tmp/" not in script

    def test_sddm_forces_lyux_theme_and_x11(self, paths):
        profile = paths["root"] / "os-builder" / "lyux-desktop-profile"
        sddm = _read(profile / "sddm" / "99-lyux-theme.conf")
        assert "Current=lyux-sddm" in sddm
        assert "DisplayServer=x11" in sddm
        assert "DefaultSession=plasmax11.desktop" in sddm

    def test_preseed_uses_automatic_network_and_mirror(self, preseed_iso_path):
        content = _read(preseed_iso_path)
        assert "netcfg/enable boolean true" in content
        assert "netcfg/choose_interface select auto" in content
        assert "netcfg/disable_autoconfig boolean false" in content
        assert "netcfg/disable_dhcp boolean false" in content
        assert "mirror/country string manual" in content
        assert "apt-setup/use_mirror boolean true" in content
        assert "tasksel/first multiselect standard" in content
        assert "kde-desktop" not in content
        assert "apt-setup/another boolean false" in content
        assert "apt-setup/cdrom/another boolean false" in content
        assert "apt-setup/cdrom/set-double boolean false" in content
        assert "apt-setup/cdrom/set-first boolean true" in content
        assert "apt-setup/cdrom/set-failed boolean false" in content
        assert "apt-setup/services-select multiselect" in content
        assert "pkgsel/upgrade select none" in content
        assert "popularity-contest popularity-contest/participate boolean false" in content
        assert "sddm xorg plasma-desktop" in content
        assert "python3-pyqt6 python3-requests python3-psutil python3-rich python3-pip" in content
        assert "dpkg-query -W" in content
        assert "preseed/late_command string \\\n    set -e;" in content

    def test_verify_script_uses_real_iso_extraction(self, paths):
        verify = _read(paths["iso_builder"] / "verify-client-iso.sh")
        assert "-find / -print" not in verify
        assert "-lsdl" in verify
        assert "-extract /preseed.cfg" in verify
        assert "netcfg/choose_interface select auto" in verify
        assert "apt-setup/use_mirror boolean true" in verify
        assert "tasksel/first multiselect standard" in verify
        assert "sddm xorg plasma-desktop" in verify


class TestClientISONoHardcodedSecrets:
    def test_preseed_has_no_fixed_credentials_or_proxy(self, preseed_iso_path):
        content = _read(preseed_iso_path)
        for forbidden in ("LyuxDeploy2026", "LyuX@2026", "192.168.10.", "192.168.100."):
            assert forbidden not in content
        assert "@@LYUX_ADMIN_PASSWORD@@" in content
        assert "@@LYUX_APT_PROXY@@" in content
        assert "mirror/http/proxy string" in content
        assert "first-boot.flag" in content
        # Plus de chage : SDDM ne gère pas l'expiration, c'est l'OOBE qui change le MDP.
        assert "chage -d 0" not in content

    def test_verify_script_checks_visual_and_secrets(self, paths):
        verify = paths["iso_builder"] / "verify-client-iso.sh"
        assert verify.exists()
        content = _read(verify)
        assert "lyux-sddm/Main.qml" in content
        assert "DisplayServer=x11" in content
        assert "LyuxDeploy2026" in content
