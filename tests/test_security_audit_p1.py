import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_veyon_private_keys_not_tracked_and_injected_via_secret():
    res = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "*keys/private*"],
        capture_output=True,
        text=True,
        check=True,
    )
    tracked = [line.strip() for line in res.stdout.splitlines() if line.strip()]
    assert tracked == [], f"Clés privées Veyon encore suivies en Git : {tracked}"

    gitignore_text = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "lyux-ansible/configs/veyon/keys/private/" in gitignore_text
    assert "lyux-ansible/roles/*/files/keys/private/" in gitignore_text

    prof_tasks = (
        REPO_ROOT / "lyux-ansible" / "roles" / "lyux-profile-prof" / "tasks" / "main.yml"
    ).read_text(encoding="utf-8")
    assert "src: keys/private/teacher/key" not in prof_tasks
    assert "veyon_teacher_private_key" in prof_tasks
    assert "no_log: true" in prof_tasks
    assert "mode: '0440'" in prof_tasks

    eleve_priv = REPO_ROOT / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "files" / "keys" / "private"
    assert not eleve_priv.exists()


def test_ansible_cfg_enforces_host_key_checking_and_become_ask_pass():
    import configparser

    cfg_path = REPO_ROOT / "lyux-ansible" / "ansible.cfg"
    parser = configparser.ConfigParser()
    parser.read(cfg_path, encoding="utf-8")

    assert parser.getboolean("defaults", "host_key_checking") is True
    assert parser.getboolean("privilege_escalation", "become_ask_pass") is True
