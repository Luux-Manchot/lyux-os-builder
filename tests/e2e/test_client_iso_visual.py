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

    def test_build_script_embeds_themes_offline(self, paths):
        script = _read(paths["iso_builder"] / "build-client-iso.sh")
        for theme in ("Orchis-kde", "WhiteSur-kde", "Tela-circle-icon-theme"):
            assert theme in script

    def test_preseed_applies_profile_during_late_command(self, preseed_iso_path):
        content = _read(preseed_iso_path)
        assert "/cdrom/lyux-payload/desktop-profile/." in content
        assert "install-desktop-profile.sh" in content

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


class TestClientISONoHardcodedSecrets:
    def test_preseed_has_no_fixed_credentials_or_proxy(self, preseed_iso_path):
        content = _read(preseed_iso_path)
        for forbidden in ("LyuxDeploy2026", "LyuX@2026", "192.168.10.", "192.168.100."):
            assert forbidden not in content
        assert "@@LYUX_ADMIN_PASSWORD@@" in content
        assert "@@LYUX_APT_PROXY@@" in content
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
